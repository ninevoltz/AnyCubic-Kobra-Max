# GNU Make build for Anycubic Kobra Max firmware (GCC toolchain)

UVPROJ             := workspace/anycubic.uvprojx
PYTHON             ?= python3

SOURCES            := $(shell $(PYTHON) scripts/keil_extract.py $(UVPROJ) sources)
INCLUDE_DIRS       := $(shell $(PYTHON) scripts/keil_extract.py $(UVPROJ) includes)

TARGET             := firmware
BUILD_DIR          := build

CC                 := arm-none-eabi-gcc
CXX                := arm-none-eabi-g++
LD                 := arm-none-eabi-g++
OBJCOPY            := arm-none-eabi-objcopy
SIZE               := arm-none-eabi-size

COMMON_FLAGS       := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard \
                      -ffunction-sections -fdata-sections -fno-common -g3
DEFINES            := -DHC32F46x -DUSE_DEVICE_DRIVER_LIB -D__TARGET_FPU_VFP -D__FPU_PRESENT=1 \
                      -DARM_MATH_CM4 -DARM_MATH_MATRIX_CHECK -DARM_MATH_ROUNDING \
                      -D__MPU_PRESENT=1 -DSTM32_HIGH_DENSITY -DARDUINO_ARCH_STM32F1 \
                      -DARDUINO_ARCH_STM32
CORE_INCLUDE       := source/main/hdsc32core
NONCORE_INCLUDES   := $(filter-out $(CORE_INCLUDE),$(INCLUDE_DIRS))
INCLUDES           := $(addprefix -I,$(NONCORE_INCLUDES))
CORE_INCLUDE_FLAG  := $(if $(filter $(CORE_INCLUDE),$(INCLUDE_DIRS)),-iquote $(CORE_INCLUDE),)

CFLAGS             := $(COMMON_FLAGS) $(DEFINES) $(INCLUDES) $(CORE_INCLUDE_FLAG) -O2 -std=gnu11 -Wall -Wextra \
                      -Wno-unused-parameter -Wno-unused-variable
CXXFLAGS           := $(COMMON_FLAGS) $(DEFINES) $(INCLUDES) $(CORE_INCLUDE_FLAG) -O2 -std=gnu++11 -Wall -Wextra \
                      -Wno-unused-parameter -Wno-unused-variable -fno-exceptions -fno-rtti
LDFLAGS            := $(COMMON_FLAGS) -T gcc/linker.ld -Wl,--gc-sections -Wl,-Map=$(BUILD_DIR)/$(TARGET).map \
                      --specs=nosys.specs --specs=nano.specs
LDLIBS             := -Wl,--start-group -lc -lm -lstdc++ -lsupc++ -lgcc -Wl,--end-group

CPP_AS_C_SRCS      := source/drivers/library/src/hc32f46x_interrupts.c \
                      source/drivers/library/src/hc32f46x_utility.c \
                      source/drivers/board/board_gpio.c
C_SRCS             := $(filter %.c,$(SOURCES))
C_SRCS             := $(filter-out $(CPP_AS_C_SRCS),$(C_SRCS))
CPP_SRCS           := $(filter %.cpp,$(SOURCES))
S_SRCS             := $(filter %.S,$(SOURCES))

OBJ_C              := $(C_SRCS:%.c=$(BUILD_DIR)/%.o)
OBJ_CPP            := $(CPP_SRCS:%.cpp=$(BUILD_DIR)/%.o)
OBJ_S              := $(S_SRCS:%.S=$(BUILD_DIR)/%.o)
CPP_EXTRA_OBJS     := $(CPP_AS_C_SRCS:%.c=$(BUILD_DIR)/%.o)
OBJECTS            := $(OBJ_C) $(OBJ_CPP) $(OBJ_S) $(CPP_EXTRA_OBJS)

ELF                := $(BUILD_DIR)/$(TARGET).elf
BIN                := $(BUILD_DIR)/$(TARGET).bin

.PHONY: all clean size

all: $(ELF) $(BIN)

size: $(ELF)
	@$(SIZE) $<

$(ELF): $(OBJECTS)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) $^ -o $@ $(LDLIBS)
	@$(SIZE) $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(if $(filter $<,$(CPP_AS_C_SRCS)), \
		$(CXX) $(CXXFLAGS) -c $< -o $@, \
		$(CC) $(CFLAGS) -c $< -o $@)

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_FLAGS) $(DEFINES) $(INCLUDES) $(CORE_INCLUDE_FLAG) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
