CROSS   = riscv64-elf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump
SIZE    = $(CROSS)size

MARCH   = rv32i
MABI    = ilp32
LDSCRIPT = linker.ld

PORT    ?= /dev/tty.usbserial-0001

CFLAGS  = -march=$(MARCH) -mabi=$(MABI) -Wall -Wextra -O2 \
          -ffreestanding -nostdlib -nostartfiles -g
LDFLAGS = -T $(LDSCRIPT) -march=$(MARCH) -mabi=$(MABI) \
          -ffreestanding -nostdlib -nostartfiles

SRCS    = startup.S main.c
OBJS    = $(SRCS:.c=.o)
OBJS    := $(OBJS:.S=.o)

TARGET  = firmware

.PHONY: all clean disasm size load

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex size

%.o: %.c
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
	$(SIZE) $<

load: $(TARGET).bin
	python3 ../send_firmware.py $(TARGET).bin -p $(PORT)

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex