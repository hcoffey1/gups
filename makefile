#Currently tested case
targets=$(ZRAY_BIN_PATH)/gups_vanilla

all: $(targets)

cxxFlags=$(shell ${CONFIG} --cxxflags)
ldFlags=$(shell ${CONFIG} --ldflags --libs)

optLevel=-O3

ifeq ($(MAKECMDGOALS), gem5)
CFLAGS=-DGEM5_BUILD
else ifeq ($(MAKECMDGOALS), gem5_zray)
CFLAGS=-DGEM5_ZRAY_BUILD
endif

#flags=-ggdb #If we want debugging symbols
ifeq ($(MACHINE_ARCH),x86_64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I$(GEM5_PATH)/include -L$(GEM5_PATH)/util/m5/build/x86/out -lm5 -lmpich
else ifeq ($(MACHINE_ARCH), riscv64)
flags=-fxray-instrument -Xclang -disable-O0-optnone -I/usr/include/riscv64-linux-gnu -march=rv64g -msmall-data-limit=0 -latomic
endif
requiredPasses=-mem2reg

$(ZRAY_BIN_PATH):
	mkdir $@

#Test programs
%.ll: %.cc $(ZRAY_BIN_PATH)/tool.so
	$(CUSTOM_CC) -o tmp_$<.ll $< -std=c++14 $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm 
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load $(ZRAY_BIN_PATH)/tool.so -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

%.ll: %.c $(ZRAY_BIN_PATH)/tool.so
	$(CUSTOM_C) -o tmp_$<.ll $< $(CFLAGS) $(flags) $(optLevel) -S -emit-llvm -fverbose-asm 
ifeq ($(MAKECMDGOALS), gem5)
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) --debug-pass=Arguments  -S < tmp_$<.ll > $@
else
	$(CUSTOM_OPT) -enable-new-pm=0 $(optLevel) $(requiredPasses) -load $(ZRAY_BIN_PATH)/tool.so -tool_pass --debug-pass=Arguments  -S < tmp_$<.ll > $@
endif

$(ZRAY_BIN_PATH)/%: %.ll $(ZRAY_BIN_PATH)/tool_dyn.ll
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

.PHONY: gem5 gem5_zray

gem5: $(targets)

gem5_zray: $(targets)

clean:
	rm -rf *.ll $(targets)
