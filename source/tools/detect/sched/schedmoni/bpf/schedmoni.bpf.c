#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>
#include "../schedmoni.h"
#include "../nosched.h"

#define TASK_RUNNING	0
#define _(P) ({typeof(P) val; __builtin_memset(&val, 0, sizeof(val)); bpf_probe_read(&val, sizeof(val), &P); val;})

struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, 4);
	__type(key, u32);
	__type(value, struct args);
} argmap SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 10240);
	__type(key, u32);
	__type(value, struct enq_info);
} start SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
	__uint(key_size, sizeof(u32));
	__uint(value_size, sizeof(u32));
} events_rnslw SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
	__uint(key_size, sizeof(u32));
	__uint(value_size, sizeof(u32));
} events_nosch SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
	__uint(key_size, sizeof(u32));
	__uint(value_size, sizeof(u32));
} events_irqof SEC(".maps");

struct bpf_map_def SEC("maps") stackmap = {
	.type = BPF_MAP_TYPE_STACK_TRACE,
	.key_size = sizeof(u32),
	.value_size = PERF_MAX_STACK_DEPTH * sizeof(u64),
	.max_entries = 1000,
};

struct {
	__uint(type, BPF_MAP_TYPE_PERCPU_HASH);
	__uint(max_entries, MAX_MONI_NR);
	__type(key, u64);
	__type(value, struct latinfo);
} info_map SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
	__uint(max_entries, 1);
	__type(key, u32);
	__type(value, struct tm_info);
} tm_map SEC(".maps");

#define GETARG_FROM_ARRYMAP(map,argp,type,member)({	\
	int i = 0;					\
	type retval;					\
	__builtin_memset(&retval, 0, sizeof(type));	\
	argp = bpf_map_lookup_elem(&map, &i);		\
	if (argp) {					\
		retval = _(argp->member);		\
	}						\
	retval;						\
	})

#define BPF_F_FAST_STACK_CMP	(1ULL << 9)
#define KERN_STACKID_FLAGS	(0 | BPF_F_FAST_STACK_CMP)

#define BIT_WORD(nr)	((nr) / BITS_PER_LONG)
#define BITS_PER_LONG	64

#define get_current_rqlen(p) ({			\
	int len = 0;				\
	struct cfs_rq *cfs;			\
	struct sched_entity *se, *parent;	\
	se = &p->se;				\
	for (int i = 0; i < 10; i++) {		\
		parent = _(se->parent);		\
		if (parent)			\
			se = parent;		\
		else				\
			break;			\
	}					\
	cfs = BPF_CORE_READ(se, cfs_rq);	\
	len = _(cfs->nr_running);		\
	len;					\
})

static inline int strequal(const char *src, const char *dst)
{
	bool ret = true;
	int i;
	unsigned char c1, c2;

	#pragma clang loop unroll(full)
	for (int i = 0; i < 16; i++) {
		c1 = *src++;
		c2 = *dst++;
		if ((!c1 || !c2) || (c1 != c2)) {
			ret = false;
			break;
		}
	}
	return ret;
}

static inline u64 get_thresh(void)
{
	u64 thresh, i = 0;
	struct args *argp;

	argp = bpf_map_lookup_elem(&argmap, &i);
	if (argp)
		thresh = argp->thresh;
	else
		thresh = -1;

	return thresh;
}

static bool program_ready(void)
{
	int i = 0;
	struct args *argp;
	bool ready = false;

	argp = bpf_map_lookup_elem(&argmap, &i);
	if (argp)
		ready = argp->ready;
	return ready;
}

static inline int test_bit(int nr, const volatile unsigned long *addr)
{
        return 1UL & (addr[BIT_WORD(nr)] >> (nr & (BITS_PER_LONG-1)));
}

static inline int test_ti_thread_flag(struct thread_info *ti, int nr)
{
	int result;
	unsigned long *addr;
	unsigned long tmp = _(ti->flags);

	addr = &tmp;
	result = 1UL & (addr[BIT_WORD(nr)] >> (nr & (BITS_PER_LONG-1)));
	return result;
}

static inline int test_tsk_thread_flag(struct task_struct *tsk, int flag)
{
	struct thread_info tf, *tfp;

	tfp = &(tsk->thread_info);
	bpf_probe_read(&tf, sizeof(tf), &(tsk->thread_info));
	tfp = &tf;
	return test_ti_thread_flag(tfp, flag);
}

static inline int test_tsk_need_resched(struct task_struct *tsk, int flag)
{
	return test_tsk_thread_flag(tsk, flag);
}

/* record enqueue timestamp */
static int trace_enqueue(struct task_struct *p, unsigned int runqlen)
{
	bool comm_eqaul = false, use_comm = true;
	char comm[16];
	u64 ts;
	struct args *argp;
	u32 tgid, pid;
	struct enq_info enq_info;
	pid_t targ_tgid, targ_pid;

	tgid = _(p->tgid);
	pid = _(p->pid);

	__builtin_memset(comm, 0, sizeof(comm));
	if (!pid)
		return 0;

	{
		int k = 0;
		struct comm_item comm_i;

		argp = bpf_map_lookup_elem(&argmap, &k);
		__builtin_memset(&comm_i, 0, sizeof(comm_i));
		if (argp)
			comm_i = _(argp->comm_i);
		bpf_probe_read(comm, sizeof(comm), &(p->comm));
		if (comm_i.size) {
			const char *src, *dst;
			src = comm;
			dst = comm_i.comm;
			comm_eqaul = strequal(src,  dst);
			if (!comm_eqaul)
				return 0;
		} else {
			use_comm = false;
		}
	}

	if (!use_comm) {
		targ_tgid = GETARG_FROM_ARRYMAP(argmap, argp, pid_t, targ_tgid);
		targ_pid = GETARG_FROM_ARRYMAP(argmap, argp, pid_t, targ_pid);
		if (targ_tgid && targ_tgid != tgid)
			return 0;

		if (targ_pid && targ_pid != pid)
			return 0;
	}
	__builtin_memset(&enq_info, 0, sizeof(struct enq_info));
	ts = bpf_ktime_get_ns();
	enq_info.ts = ts;
	enq_info.rqlen = runqlen;
	bpf_map_update_elem(&start, &pid, &enq_info, 0);
	return 0;
}

SEC("raw_tracepoint/sched_wakeup")
int raw_tracepoint__sched_wakeup(struct bpf_raw_tracepoint_args *ctx)
{
	unsigned int runqlen = 0;
	struct task_struct *p = (void *)ctx->args[0];

	if (!program_ready())
		return 0;

	runqlen = get_current_rqlen(p);
	return trace_enqueue(p, runqlen);
}

SEC("raw_tracepoint/sched_wakeup_new")
int raw_tracepoint__sched_wakeup_new(struct bpf_raw_tracepoint_args *ctx)
{
	unsigned int runqlen = 0;
	struct task_struct *p = (void *)ctx->args[0];

	if (!program_ready())
		return 0;

	runqlen = get_current_rqlen(p);
	return trace_enqueue(p, runqlen);
}

SEC("tp/sched/sched_switch")
int handle_switch(struct trace_event_raw_sched_switch *ctx)
{
	struct task_struct *prev;
	struct enq_info *enq;
	u64 cpuid;
	u32 pid, prev_pid;
	long int prev_state;
	struct event event = {};
	u64 delay, thresh;
	struct args *argp;
	struct latinfo *latp;
	struct latinfo lati;

	if (!program_ready())
		return 0;

	prev_pid = ctx->prev_pid;
	pid = ctx->next_pid;
	prev_state = ctx->prev_state;

	cpuid = bpf_get_smp_processor_id();
	/* 1rst: nosched */
	latp = bpf_map_lookup_elem(&info_map, &cpuid);
	if (latp) {
		u64 now;
		struct event event = {0};

		now = bpf_ktime_get_ns();
		event.enter = latp->last_seen_need_resched_ns;
		if (event.enter && latp->thresh &&
			(now - event.enter > latp->thresh)) {

			event.stamp = now;
			event.exit = now;
			event.cpuid = cpuid;
			event.delay = now - latp->last_seen_need_resched_ns;
			latp->last_perf_event = now;
			event.pid = bpf_get_current_pid_tgid();
			bpf_get_current_comm(&event.task, sizeof(event.task));
			event.ret = bpf_get_stackid(ctx, &stackmap, KERN_STACKID_FLAGS);
			bpf_perf_event_output(ctx, &events_nosch, BPF_F_CURRENT_CPU,
					&event, sizeof(event));
		}
		latp->last_seen_need_resched_ns = 0;
	}

	/* 2nd: runqslower */
	/* ivcsw: treat like an enqueue event and store timestamp */
	prev = (void *)bpf_get_current_task();
	if (prev_state == TASK_RUNNING) {
		unsigned int runqlen = 0;

		runqlen = get_current_rqlen(prev);
		return trace_enqueue(prev, runqlen);
	}
	/* fetch timestamp and calculate delta */
	enq = bpf_map_lookup_elem(&start, &pid);
	if (!enq)
		return 0;   /* missed enqueue */

	delay = (bpf_ktime_get_ns() - _(enq->ts));
	thresh = GETARG_FROM_ARRYMAP(argmap, argp, u64, thresh);
	if (thresh && delay <= thresh)
		return 0;

	__builtin_memset(&event, 0, sizeof(struct event));
	event.cpuid = cpuid;
	event.pid = pid;
	event.prev_pid = prev_pid;
	event.delay = delay;
	event.rqlen = _(enq->rqlen);
	event.stamp = bpf_ktime_get_ns();
	bpf_probe_read(event.task, sizeof(event.task), &(ctx->next_comm));
	bpf_probe_read(event.prev_task, sizeof(event.prev_task), &(ctx->prev_comm));

	/* output */
	bpf_perf_event_output(ctx, &events_rnslw, BPF_F_CURRENT_CPU,
			      &event, sizeof(event));

	bpf_map_delete_elem(&start, &pid);

	return 0;
}

SEC("kprobe/account_process_tick")
int BPF_KPROBE(account_process_tick, struct task_struct *p, int user_tick)
{
	int args_key;
	u64 cpuid, thresh;
	u64 resched_latency, now;
	struct latinfo lati, *latp;
	struct args args, *argsp;

	if (!program_ready())
		return 0;
	__builtin_memset(&args_key, 0, sizeof(int));
	argsp = bpf_map_lookup_elem(&argmap, &args_key);

	if (!argsp)
		return 0;

	if(!test_tsk_need_resched(p, _(argsp->flag)))
		return 0;

	if (_(p->pid) == 0)
		return 0;

	__builtin_memset(&cpuid, 0, sizeof(u64));
	cpuid = bpf_get_smp_processor_id();
	latp = bpf_map_lookup_elem(&info_map, &cpuid);
	now = bpf_ktime_get_ns();
	if (latp) {
		if (!latp->last_seen_need_resched_ns) {
			__builtin_memset(latp, 0, sizeof(struct latinfo));
			latp->last_seen_need_resched_ns = now;
			latp->last_perf_event = now;
		} else {
			latp->ticks_without_resched++;
			resched_latency = (now - latp->last_perf_event);
			thresh = _(argsp->thresh);
			latp->thresh = thresh;
			if (resched_latency > thresh) {
				struct event event = {0};
				event.stamp = now;
				event.cpuid = cpuid;
				event.delay = now - latp->last_seen_need_resched_ns;
				latp->last_perf_event = now;
				event.pid = bpf_get_current_pid_tgid();
				bpf_get_current_comm(&event.task, sizeof(event.task));
				event.ret = bpf_get_stackid(ctx, &stackmap, KERN_STACKID_FLAGS);
				bpf_perf_event_output(ctx, &events_nosch, BPF_F_CURRENT_CPU,
							&event, sizeof(event));
			}
		}
	} else {
		__builtin_memset(&lati, 0, sizeof(struct latinfo));
		lati.last_seen_need_resched_ns = now;
		lati.last_perf_event = now;
		bpf_map_update_elem(&info_map, &cpuid, &lati, BPF_ANY);
	}

	return 0;
}

SEC("perf_event")
int hw_irqoff_event(struct bpf_perf_event_data *ctx)
{
	int i = 0;
	u64 now, delta, thresh, stamp;
	struct tm_info *tmifp;
	struct event event = {};
	u32 cpu = bpf_get_smp_processor_id();

	now = bpf_ktime_get_ns();
	tmifp = bpf_map_lookup_elem(&tm_map, &i);

	if (tmifp) {
		stamp = tmifp->last_stamp;
		thresh = get_thresh();
		if (stamp && (thresh != -1)) {
			delta = now - stamp;
			if (delta > thresh) {
				event.cpuid = cpu;
				event.stamp = now;
				event.delay = delta;
				event.pid = bpf_get_current_pid_tgid();
				bpf_get_current_comm(&event.task, sizeof(event.task));
				event.ret = bpf_get_stackid(ctx, &stackmap, KERN_STACKID_FLAGS);
				bpf_perf_event_output(ctx, &events_irqof, BPF_F_CURRENT_CPU,
				      &event, sizeof(event));
			}
		}
	}

	return 0;
}

SEC("perf_event")
int sw_irqoff_event1(struct bpf_perf_event_data *ctx)
{
	int ret, i = 0;
	struct tm_info *tmifp, tm;

	tmifp = bpf_map_lookup_elem(&tm_map, &i);
	if (tmifp) {
		tmifp->last_stamp = bpf_ktime_get_ns();
	} else {
		__builtin_memset(&tm, 0, sizeof(tm));
		tm.last_stamp = bpf_ktime_get_ns();
		bpf_map_update_elem(&tm_map, &i, &tm, 0);
	}
	return 0;
}

SEC("perf_event")
int sw_irqoff_event2(struct bpf_perf_event_data *ctx)
{
	int i = 0;
	u64 now, delta, thresh, stamp;
	struct tm_info *tmifp, tm;
	struct event event = {};
	u32 cpu = bpf_get_smp_processor_id();

	now = bpf_ktime_get_ns();
	tmifp = bpf_map_lookup_elem(&tm_map, &i);

	if (tmifp) {
		stamp = tmifp->last_stamp;
		tmifp->last_stamp = now;
		thresh = get_thresh();
		if (stamp && (thresh != -1)) {
			delta = now - stamp;
			if (delta > thresh) {
				event.cpuid = cpu;
				event.delay = delta;
				event.pid = bpf_get_current_pid_tgid();
				bpf_get_current_comm(&event.task, sizeof(event.task));
				event.ret = bpf_get_stackid(ctx, &stackmap, KERN_STACKID_FLAGS);
				bpf_perf_event_output(ctx, &events_irqof, BPF_F_CURRENT_CPU,
				      &event, sizeof(event));
			}
		}
	} else {
		__builtin_memset(&tm, 0, sizeof(tm));
		tm.last_stamp = now;
		bpf_map_update_elem(&tm_map, &i, &tm, 0);
	}

	return 0;
}
char LICENSE[] SEC("license") = "GPL";
