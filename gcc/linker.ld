/* GNU linker script for the Anycubic Kobra Max firmware built with GCC */

ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00008000, LENGTH = 0x00080000 - 0x00008000
    RAM   (xrw) : ORIGIN = 0x1FFF8000, LENGTH = 0x00018000
}

_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .isr_vector :
    {
        KEEP(*(.isr_vector))
    } > FLASH

    .text :
    {
        *(.text*)
        *(.rodata*)
        *(.glue_7)
        *(.glue_7t)
        *(.gnu.linkonce.t*)
        *(.gnu.linkonce.r*)

        KEEP(*(.init))
        KEEP(*(.fini))

        . = ALIGN(4);
        KEEP(*(.ctors))
        KEEP(*(.dtors))
        KEEP(*(.init_array*))
        KEEP(*(.fini_array*))
    } > FLASH

    .ARM.extab :
    {
        *(.ARM.extab* .gnu.linkonce.armextab.*)
    } > FLASH

    __exidx_start = .;
    .ARM.exidx :
    {
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > FLASH
    __exidx_end = .;

    .eh_frame :
    {
        KEEP(*(.eh_frame))
    } > FLASH

    __etext = .;

    .data : AT(__etext)
    {
        __data_start__ = .;
        _sdata = .;
        *(.data*)
        *(.ramfunc*)
        . = ALIGN(4);
        __data_end__ = .;
        _edata = .;
    } > RAM

    _sidata = LOADADDR(.data);

    .bss (NOLOAD) :
    {
        __bss_start__ = .;
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
        _ebss = .;
    } > RAM

    ._user_heap_stack (NOLOAD) :
    {
        . = ALIGN(8);
        PROVIDE(__heap_start = .);
        PROVIDE(__heap_end = ORIGIN(RAM) + LENGTH(RAM));
    } > RAM

    PROVIDE(end = _ebss);
    PROVIDE(_end = _ebss);

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
