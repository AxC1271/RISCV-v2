CROSS   = riscv64-elf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump
SIZE    = $(CROSS)size

MARCH   = rv32i
MABI    = ilp32
LDSCRIPT = linker.ld

CFLAGS  = -march=$(MARCH) -mabi=$(MABI) -Wall -Wextra -O2 \
          -ffreestanding -nostdlib -nostartfiles -g
LDFLAGS = -T $(LDSCRIPT) -march=$(MARCH) -mabi=$(MABI) \
          -ffreestanding -nostdlib -nostartfiles

SRCS    = startup.S main.c
OBJS    = $(SRCS:.c=.o)
OBJS    := $(OBJS:.S=.o)

TARGET  = firmware

.PHONY: all clean disasm hex size

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex size

%.o: %.c main.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) $(LDSCRIPT)
	$(CC) $(LDFLAGS) $(OBJS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

disasm: $(TARGET).elf
	$(OBJDUMP) -d $< | less

size: $(TARGET).elf
	$(SIZE) $

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex