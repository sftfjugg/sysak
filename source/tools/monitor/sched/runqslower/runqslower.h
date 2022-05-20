#ifndef __RUNQSLOWER_H
#define __RUNQSLOWER_H

#define TASK_COMM_LEN 16
#define CPU_ARRY_LEN	4
#define CONID_LEN	13

struct event {
	char task[TASK_COMM_LEN];
	char prev_task[TASK_COMM_LEN];
	
	__u64 delay;
	__u64 stamp;
	pid_t pid;
	pid_t prev_pid;
	int cpuid;
};

struct max_sum {
	__u64 value;
	__u64 stamp;
	int cpu, pid;
	char comm[TASK_COMM_LEN];
};

struct summary {
	unsigned long num;
	__u64	total;
	struct max_sum max;
	int cpus[CPU_ARRY_LEN];
	int jitter[CPU_ARRY_LEN];
	char container[CPU_ARRY_LEN][CONID_LEN];
};

struct args {
	__u64 threshold;
	pid_t targ_pid;
	pid_t targ_tgid;
	pid_t filter_pid;
	pid_t pad;
};

#endif /* __RUNQSLOWER_H */
