LDFLAGS += -lz -pthread -ldl
#CFLAGS += -std=c++11 -static
INCLUDES += -I$(SRC)/../out/bpf -I$(SRC)/tools/detect/net/tcpping/include -I$(SRC)/lib/internal/ebpf/libbpf/src

COOLBPF_OBJ := $(SRC)/tools/detect/net/tcpping/lib/libnet.a
newdirs := $(shell find src/ -type d)
newdirs += $(shell find bpf/ -type d)
csrcs := $(shell find ./src -name "*.c")
bpfsrcs := $(wildcard bpf/*.bpf.c)
target := tcpping

include $(SRC)/mk/bpf.mk
