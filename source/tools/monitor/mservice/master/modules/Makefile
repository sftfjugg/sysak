CFLAGS = -MD -Wall -fPIC --shared -g -O2 -Wno-strict-aliasing -lrt
CC = gcc
INCLUDE_DIR = ../include
LINK = $(CC) -I$(INCLUDE_DIR) -I../src/obj/include -I$(SRC)/lib/uapi/include $(CFLAGS)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LINK += -Wl,-undefined -Wl,dynamic_lookup

	OBJS = mod_apache.so mod_cpu.so mod_haproxy.so mod_load.so mod_swap.so\
		   mod_lvs.so mod_mem.so mod_ncpu.so mod_nginx.so \
		   mod_pcsw.so mod_percpu.so mod_pernic.so \
		   mod_proc.so mod_squid.so mod_tcp.so mod_tcpx.so \
		   mod_traffic.so mod_udp.so mod_cgroup.so mod_jitter.so \
		   mod_vmevent.so mod_numabalance.so mod_scheddelay.so
else
	OBJS = mod_apache.so mod_cpu.so mod_haproxy.so mod_io.so mod_load.so mod_swap.so \
		   mod_lvs.so mod_mem.so mod_ncpu.so mod_nginx.so \
		   mod_partition.so mod_pcsw.so mod_percpu.so mod_pernic.so \
		   mod_proc.so mod_squid.so mod_tcp.so mod_tcpx.so \
		   mod_traffic.so mod_udp.so mod_cgroup.so mod_jitter.so \
		   mod_vmevent.so mod_numabalance.so mod_scheddelay.so
endif

all: $(OBJS)

$(OBJS): %.so: %.c
	$(LINK) $< -o $@
clean:
	rm -f *.so;
	rm -f *.d;
	rm -rf *.dSYM;

-include $(OBJS:.so=.d)
