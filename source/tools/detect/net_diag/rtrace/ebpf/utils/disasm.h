#ifndef __RTRACE_DISASM_H
#define __RTRACE_DISASM_H


#include <linux/bpf.h>
#include <linux/kernel.h>
#ifndef __KERNEL__
#include <stdio.h>
#include <string.h>
#endif

#define __stringify_1(x...)	#x
#define __stringify(x...)	__stringify_1(x)

#define __printf(a, b)	__attribute__((format(printf, a, b)))

extern const char *const bpf_alu_string[16];
extern const char *const bpf_class_string[8];

const char *func_id_name(int id);

typedef __printf(2, 3) void (*bpf_insn_print_t)(void *private_data,
						const char *, ...);
typedef const char *(*bpf_insn_revmap_call_t)(void *private_data,
					      const struct bpf_insn *insn);
typedef const char *(*bpf_insn_print_imm_t)(void *private_data,
					    const struct bpf_insn *insn,
					    __u64 full_imm);

struct bpf_insn_cbs {
	bpf_insn_print_t	cb_print;
	bpf_insn_revmap_call_t	cb_call;
	bpf_insn_print_imm_t	cb_imm;
	void			*private_data;
};

void print_bpf_insn(const struct bpf_insn_cbs *cbs,
		    const struct bpf_insn *insn,
		    bool allow_ptr_leaks);

#endif
