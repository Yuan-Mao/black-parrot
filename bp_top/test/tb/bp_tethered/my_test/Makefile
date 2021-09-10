
.PHONY: all compile mem clean

LIB_DIR       := /home/acme/bsg/bp-sim/sdk/perch
INCLUDE_DIR   := /home/acme/bsg/bp-sim/sdk/include
RISCV_OBJCOPY := /home/acme/bsg/bp-sim/sdk/install/bin/riscv64-unknown-elf-dramfs-objcopy
CC            := /home/acme/bsg/bp-sim/sdk/install/bin/riscv64-unknown-elf-dramfs-gcc
SED := sed

CFLAGS = -mabi=lp64 -march=rv64imafd -mcmodel=medany -I$(INCLUDE_DIR) \
		-Wall -Wextra -static -O0

#LINK := -T riscv.ld -L$(LIB_DIR) -Wl,--start-group,-lc,-lgloss,-lgcc,-lperch,--end-group
LINK := -T riscv.ld -L$(LIB_DIR) -Wl,--whole-archive -lperch -Wl,--no-whole-archive

SRC1 = test1.c lfs.c
SRC2 = test2.c lfs.c

all: compile mem;

compile:
	$(CC) $(CFLAGS) $(SRC1) $(LINK) -o test1.riscv
	$(CC) $(CFLAGS) $(SRC2) $(LINK) -o test2.riscv

mem:
	$(RISCV_OBJCOPY) -O verilog test1.riscv test1.mem
	$(RISCV_OBJCOPY) -O verilog test2.riscv test2.mem
	$(SED) -i "s/@8/@0/g" test1.mem
	$(SED) -i "s/@8/@0/g" test2.mem

clean:
	rm -f *.bootram *.mainram *.bp_regs a.out *.riscv *.mem
