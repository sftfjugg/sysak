CC := gcc
CFLAG := -g -fpic
LDFLAG := -g -fpic -shared
OBJS := foxTSDB.o
SO := libfoxTSDB.so

all: $(SO)

foxTSDB.o: foxTSDB.c
	$(CC) -c $< -o $@ $(CFLAG)

$(SO): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAG)

clean:
	rm -f $(SO) $(OBJS)