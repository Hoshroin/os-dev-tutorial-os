ASM = nasm
GCC = i386-elf-gcc
LD = i386-elf-ld

KERNEL_OFFSET = 0x1000

SRC_DIR = src
BUILD_DIR = build

C_SOURCES = $(wildcard $(SRC_DIR)/kernel/*.c $(SRC_DIR)/driver/*.c)
HEADERS = $(wildcard $(SRC_DIR)/kernel/*.h $(SRC_DIR)/driver/*.h)
OBJ = $(subst $(SRC_DIR)/,$(BUILD_DIR)/,$(patsubst %.c,%.o,$(C_SOURCES)))

.PHONY: all run debug floppy_image kernel bootloader clean always

all: floppy_image

run: all
	qemu-system-i386 -fda $(BUILD_DIR)/main_floppy.img

debug: all
	bochs -f bochs_config

# floppy_image
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$@ bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $@
	dd if=$(BUILD_DIR)/bootloader.bin of=$@ bs=512 conv=notrunc
	dd if=$(BUILD_DIR)/kernel.bin of=$@ bs=512 conv=notrunc seek=1

# bootloader
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $@

# kernel
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel_entry.o: always
	$(ASM) $(SRC_DIR)/kernel/kernel_entry.asm -f elf -o $@

$(BUILD_DIR)/kernel.bin: always $(BUILD_DIR)/kernel_entry.o ${OBJ}
	$(LD) -o $@ -Ttext $(KERNEL_OFFSET) $(BUILD_DIR)/kernel_entry.o ${OBJ} --oformat binary

%.o : ${HEADERS}
ifeq ("$(wildcard $(dir $@))" ,"")
	mkdir -p $(dir $@)
endif
	$(GCC) -ffreestanding -c $(patsubst %.o,%.c,$(subst $(BUILD_DIR)/,$(SRC_DIR)/,$@)) -o $@

always:
	mkdir -p $(BUILD_DIR)

clean:
	rm -fr $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.o $(BUILD_DIR)/*.dis $(BUILD_DIR)/main_floppy.img
	rm -fr $(BUILD_DIR)/kernel/*.o $(BUILD_DIR)/boot/*.bin $(BUILD_DIR)/drivers/*.o
