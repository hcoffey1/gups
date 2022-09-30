## Makefile for Linux
#
#SHELL = /bin/sh
#
## System-specific settings
#
#CC =		$(CUSTOM_C)
#CCFLAGS =	-O -g -DCHECK
#LINK =		$(CUSTOM_LINK)
#LINKFLAGS =	-O -g 
#LIB =		-lmpich
#
#all: gups_vanilla
#
## Link target
#
#gups_vanilla:	gups_vanilla.o
#	$(LINK) $(LINKFLAGS) gups_vanilla.o $(LIB) -o gups_vanilla
#
#gups_nonpow2:	gups_nonpow2.o
#	$(LINK) $(LINKFLAGS) gups_nonpow2.o $(LIB) -o gups_nonpow2
#
#gups_opt:	gups_opt.o
#	$(LINK) $(LINKFLAGS) gups_opt.o $(LIB) -o gups_opt
#
## Compilation rules
#
#%.o:%.c
#	$(CC) $(CCFLAGS) -c $<
#
#clean:
#	rm *.o gups_vanilla


#targets=../bin \
		../bin/test \
		../bin/asmTest \
		../bin/diamond \
		../bin/mem \
		../bin/nestedLoop

#Currently tested case
targets=../../bin/gups_vanilla

all: $(targets)

cxxFlags=$(shell ${CONFIG} --cxxflags)
ldFlags=$(shell ${CONFIG} --ldflags --libs)

optLevel=-O3

ifeq ($(MAKECMDGOALS), gem5)
CFLAGS=-DGEM5_BUILD
endif

#flags=-ggdb #If we want debugging symbols
ifeq ($(MACHINE_ARCH),x86_64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I../../../gem5/include -L../../../gem5/util/m5/build/x86/out -lm5 -lmpich
else ifeq ($(MACHINE_ARCH), riscv64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I/usr/include/riscv64-linux-gnu -march=rv64g -msmall-data-limit=0 -latomic
endif
requiredPasses=-mem2reg

../bin:
	mkdir $@

#Test programs
%.ll: %.cc ../../bin/tool.so
	$(CUSTOM_CC) -o tmp_$<.ll $< -std=c++14 $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm 
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load ../../bin/tool.so -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

%.ll: %.c ../../bin/tool.so
	$(CUSTOM_C) -o tmp_$<.ll $< $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm 
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load ../../bin/tool.so -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

../../bin/%: %.ll ../../bin/tool_dyn.ll
	#Link modules together
	$(CUSTOM_LINK) -o linked_$<.ll $^ 
	#Link into binary, zip metadata and concat
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_CC) -o $@ linked_$<.ll -std=c++14 $(flags)
else
	$(CUSTOM_CC) -o $@_tmp linked_$<.ll -std=c++14 $(flags)
	zip tool_file.zip tool_file
	cat $@_tmp tool_file.zip > $@
	chmod +x $@
	#Cleanup
	rm $@_tmp tool_file tool_file.zip
endif

.PHONY: gem5
gem5: $(targets)

clean:
	rm -rf *.ll $(targets)
