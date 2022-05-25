#include <argp.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/resource.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include "runqslower.h"
#include "bpf/runqslower.skel.h"

unsigned int nr_cpus;
FILE *filep = NULL;
static volatile sig_atomic_t exiting = 0;
char log_dir[] = "/var/log/sysak/runqslow/";
char defaultfile[] = "/var/log/sysak/runqslow/runqslow.log";
char filename[256] = {0};

struct summary summary, *percpu_summary;
struct env {
	pid_t pid;
	pid_t tid;
	unsigned long span;
	__u64 threshold;
	bool previous;
	bool verbose;
	bool summary;
} env = {
	.span = 0,
	.threshold = 10*1000*1000,
};

const char *argp_program_version = "runqslower 0.1";
const char argp_program_doc[] =
"Trace high run queue latency.\n"
"\n"
"USAGE: runqslower [--help] [-s SPAN] [-t TID] [-P] [threshold] [-f ./runslow.log]\n"
"\n"
"EXAMPLES:\n"
"    runqslower          # trace latency higher than 10ms (default)\n"
"    runqslower -f a.log # trace latency and record result to a.log (default to /var/log/sysak/runqslow/runqslow.log)\n"
"    runqslower 12     # trace latency higher than 12 ms\n"
"    runqslower -p 123   # trace pid 123\n"
"    runqslower -t 123   # trace tid 123 (use for threads only)\n"
"    schedmoni -s 10     # monitor for 10 seconds\n"
"    runqslower -P       # also show previous task name and TID\n";

static const struct argp_option opts[] = {
	{ "pid", 'p', "PID", 0, "Process PID to trace"},
	{ "tid", 't', "TID", 0, "Thread TID to trace"},
	{ "span", 's', "SPAN", 0, "How long to run"},
	{ "verbose", 'v', NULL, 0, "Verbose debug output" },
	{ "summary", 'S', NULL, 0, "Output the summary info" },
	{ "previous", 'P', NULL, 0, "also show previous task name and TID" },
	{ "logfile", 'f', "LOGFILE", 0, "logfile for result"},
	{ NULL, 'h', NULL, OPTION_HIDDEN, "Show the full help" },
	{},
};

static void bump_memlock_rlimit(void)
{
	struct rlimit rlim_new = {
		.rlim_cur = RLIM_INFINITY,
		.rlim_max = RLIM_INFINITY,
	};

	if (setrlimit(RLIMIT_MEMLOCK, &rlim_new)) {
		fprintf(stderr, "Failed to increase RLIMIT_MEMLOCK limit!\n");
		exit(1);
	}
}

static int prepare_dictory(char *path)
{
	int ret;

	ret = mkdir(path, 0777);
	if (ret < 0 && errno != EEXIST)
		return errno;
	else
		return 0;
}

static error_t parse_arg(int key, char *arg, struct argp_state *state)
{
	static int pos_args;
	int pid;
	long long threshold;
	unsigned long span;

	switch (key) {
	case 'h':
		argp_state_help(state, stderr, ARGP_HELP_STD_HELP);
		break;
	case 'v':
		env.verbose = true;
		break;
	case 'S':
		nr_cpus = libbpf_num_possible_cpus();
		percpu_summary = malloc(nr_cpus*sizeof(struct summary));
		if (!percpu_summary)
			return -ENOMEM;
		env.summary = true;
		break;
	case 'P':
		env.previous = true;
		break;
	case 'p':
		errno = 0;
		pid = strtol(arg, NULL, 10);
		if (errno || pid <= 0) {
			fprintf(stderr, "Invalid PID: %s\n", arg);
			argp_usage(state);
		}
		env.pid = pid;
		break;
	case 't':
		errno = 0;
		pid = strtol(arg, NULL, 10);
		if (errno || pid <= 0) {
			fprintf(stderr, "Invalid TID: %s\n", arg);
			argp_usage(state);
		}
		env.tid = pid;
		break;
	case 's':
		errno = 0;
		span = strtoul(arg, NULL, 10);
		if (errno || span <= 0) {
			fprintf(stderr, "Invalid SPAN: %s\n", arg);
			argp_usage(state);
		}
		env.span = span;
		break;
	case 'f':
		if (strlen(arg) < 2)
			strncpy(filename, defaultfile, sizeof(filename));
		else
			strncpy(filename, arg, sizeof(filename));
		filep = fopen(filename, "w+");
		if (!filep) {
			int ret = errno;
			fprintf(stderr, "%s :fopen %s\n",
				strerror(errno), filename);
			return ret;
		}
		break;
	case ARGP_KEY_ARG:
		if (pos_args++) {
			fprintf(stderr,
				"Unrecognized positional argument: %s\n", arg);
			argp_usage(state);
		}
		errno = 0;
		threshold = strtoll(arg, NULL, 10);
		if (errno || threshold <= 0) {
			fprintf(stderr, "Invalid delay (in ms): %s\n", arg);
			argp_usage(state);
		}
		env.threshold = threshold*1000*1000;
		break;
	default:
		return ARGP_ERR_UNKNOWN;
	}
	if (!filep) {
		filep = fopen(defaultfile, "w+");
		if (!filep) {
			int ret = errno;
			fprintf(stderr, "%s :fopen %s\n",
				strerror(errno), defaultfile);
			return ret;
		}
	}
	return 0;
}

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args)
{
	if (level == LIBBPF_DEBUG && !env.verbose)
		return 0;
	return vfprintf(stderr, format, args);
}

static void sig_alarm(int signo)
{
	exiting = 1;
}

static void sig_int(int signo)
{
	exiting = 1;
}

static int get_container(char *dockerid, int pid)
{
	char *buf;
	FILE *fp;
	int ret = -1;
	char cgroup_path[32] = {0};

	snprintf(cgroup_path, sizeof(cgroup_path), "/proc/%d/cgroup", pid);

	fp = fopen(cgroup_path, "r");
	if (!fp)
		return errno;

	buf = malloc(4096*sizeof(char));
	if (!buf) {
		ret = errno;
		goto out2;
	}

	while(fgets(buf, 4096, fp)) {
		int stat = 0;
		char *token, *pbuf = buf;
		while((token = strsep(&pbuf, "/")) != NULL) {
			if (stat == 1) {
				stat++;
				break;
			}
			if (!strncmp("docker", token, strlen("docker")))
				stat++;
		}

		if (stat == 2) {
			strncpy(dockerid, token, CONID_LEN - 1);
			ret = 0;
			goto out1;
		}
	}
out1:
	free(buf);	
out2:
	fclose(fp);
	return ret;
}

static void update_summary(struct summary* summary, const struct event *e)
{
	int idx;
	char buf[CONID_LEN] = {0};

	summary->num++;
	idx = summary->num % CPU_ARRY_LEN;
	summary->total += e->delay;
	summary->cpus[idx] = e->cpuid;
	summary->jitter[idx] = e->delay;
	if (get_container(buf, e->pid))
		strncpy(summary->container[idx], "000000000000", sizeof(summary->container[idx]));
	else
		strncpy(summary->container[idx], buf, sizeof(summary->container[idx]));

	if (summary->max.value < e->delay) {
		summary->max.value = e->delay;
		summary->max.cpu = e->cpuid;
		summary->max.pid = e->pid;
		summary->max.stamp = e->stamp;
		strncpy(summary->max.comm, e->task, 16);
	}
}

static int record_summary(struct summary *summary, long offset, bool total)
{
	char *p;
	int i, idx, pos;
	char buf[128] = {0};
	char header[16] = {0};

	snprintf(header, 15, "cpu%ld", offset);
	p = buf;
	pos = sprintf(p,"%-7s %-5lu %-6llu",
		total?"rqslow":header,
		summary->num, summary->total);

	if (total) {
		idx = summary->num % CPU_ARRY_LEN;
		for (i = 1; i <= CPU_ARRY_LEN; i++) {
			p = p+pos;
			pos = sprintf(p, " %d", summary->cpus[(idx+i)%CPU_ARRY_LEN]);
		}
		for (i = 1; i <= CPU_ARRY_LEN; i++) {
			p = p+pos;
			pos = sprintf(p, " %5d", summary->jitter[(idx+i)%CPU_ARRY_LEN]);
		}
		for (i = 1; i <= CPU_ARRY_LEN; i++) {
			p = p+pos;
			pos = sprintf(p, " %s", summary->container[(idx+i)%CPU_ARRY_LEN]);
		}
		p = p+pos;
		pos = sprintf(p, "\n");
	} else {
		p = p+pos;
		pos = sprintf(p, "   %-4llu %-12llu %-3d %-9d %-15s\n",
			summary->max.value, summary->max.stamp/1000,
			summary->max.cpu, summary->max.pid, summary->max.comm);
	}
	if (total)
		fseek(filep, 0, SEEK_SET);
	else
		fseek(filep, (offset)*(p-buf+pos), SEEK_CUR);
	fprintf(filep, "%s", buf);
	return 0;
}

void handle_event(void *ctx, int cpu, void *data, __u32 data_sz)
{
	struct event tmpe, *e;
	const struct event *ep = data;
	struct tm *tm;
	char ts[64];
	time_t t;

	tmpe = *ep;
	e = &tmpe;
	time(&t);
	tm = localtime(&t);
	strftime(ts, sizeof(ts), "%F %H:%M:%S", tm);
	e->delay = e->delay/(1000*1000);
	if (env.summary) {
		struct summary *sumi;
		if (e->cpuid > nr_cpus - 1)
			return;
		sumi = &percpu_summary[e->cpuid];
		update_summary(&summary, e);
		update_summary(sumi, e);
		if(record_summary(&summary, 0, true))
			return;
		record_summary(sumi, e->cpuid, false);
	} else {
		if (env.previous)
			fprintf(filep, "%-21s %-6d %-16s %-8d %-10llu %-16s %-6d\n",
				ts, e->cpuid, e->task, e->pid,
				e->delay, e->prev_task, e->prev_pid);
		else
			fprintf(filep, "%-21s %-6d %-16s %-8d %-10llu\n",
				ts, e->cpuid, e->task, e->pid, e->delay);
	}
}

void handle_lost_events(void *ctx, int cpu, __u64 lost_cnt)
{
	printf("Lost %llu events on CPU #%d!\n", lost_cnt, cpu);
}

int main(int argc, char **argv)
{
	int i, err, map_fd;
	static const struct argp argp = {
		.options = opts,
		.parser = parse_arg,
		.doc = argp_program_doc,
	};
	struct perf_buffer *pb = NULL;
	struct runqslower_bpf *obj;
	struct perf_buffer_opts pb_opts = {};
	struct args args = {};

	err = prepare_dictory(log_dir);
	if (err)
		return err;

	err = argp_parse(&argp, argc, argv, 0, NULL, NULL);
	if (err)
		return err;

	libbpf_set_print(libbpf_print_fn);
	
	bump_memlock_rlimit();
	
	obj = runqslower_bpf__open();
	if (!obj) {
		fprintf(stderr, "failed to open BPF object\n");
		return 1;
	}

	err = runqslower_bpf__load(obj);
	if (err) {
		fprintf(stderr, "failed to load BPF object: %d\n", err);
		goto cleanup;
	}

	err = runqslower_bpf__attach(obj);
	if (err) {
		fprintf(stderr, "failed to attach BPF programs\n");
		goto cleanup;
	}

	i = 0;
	map_fd = bpf_map__fd(obj->maps.argmap);
	args.targ_tgid = env.pid;
	args.targ_pid = env.tid;
	args.filter_pid = getpid();
	args.threshold = env.threshold;

	if (!env.summary) {
		if (env.previous)
			fprintf(filep, "%-21s %-6s %-16s %-8s %-10s %-16s %-6s\n",
				"TIME(runslw)", "CPU", "COMM", "TID", "LAT(ms)", "PREV COMM", "PREV TID");
		else
			fprintf(filep, "%-21s %-6s %-16s %-8s %-10s\n",
				"TIME(runslw)", "CPU", "COMM", "TID", "LAT(ms)");
	} else {
		int i;
		char buf[128] = {' '};
		fprintf(filep, "rqslow\n");
		for (i = 0; i < nr_cpus; i++)
			fprintf(filep, "cpu%d  %s\n", i, buf);
		fseek(filep, 0, SEEK_SET);
		for (i=0; i < 4; i++)
			strncpy(summary.container[i], "000000000000", sizeof(summary.container[i]));
	}
	pb_opts.sample_cb = handle_event;
	pb = perf_buffer__new(bpf_map__fd(obj->maps.events), 64, &pb_opts);
	if (!pb) {
		err = -errno;
		fprintf(stderr, "failed to open perf buffer: %d\n", err);
		goto cleanup;
	}

	if (signal(SIGINT, sig_int) == SIG_ERR ||
		signal(SIGALRM, sig_alarm) == SIG_ERR) {
		fprintf(stderr, "can't set signal handler: %s\n", strerror(errno));
		err = 1;
		goto cleanup;
	}

	if (env.span)
		alarm(env.span);

	bpf_map_update_elem(map_fd, &i, &args, 0);
	if (err) {
		fprintf(stderr, "Failed to update flag map\n");
		goto cleanup;
	}
	while (!exiting) {
		err = perf_buffer__poll(pb, 100);
		if (err < 0 && err != -EINTR) {
			fprintf(stderr, "error polling perf buffer: %s\n", strerror(-err));
			goto cleanup;
		}
		/* reset err to return 0 if exiting */
		err = 0;
	}

cleanup:
	perf_buffer__free(pb);
	runqslower_bpf__destroy(obj);

	return err != 0;
}
