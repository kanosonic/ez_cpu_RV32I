ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x00003000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.start)
        *(.text*)
    } > ROM

    . = ALIGN(16);
    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > RAM

    . = ALIGN(16);
    .data : {
        *(.data*)
        *(.sdata*)
    } > RAM

    . = ALIGN(16);
    .bss (NOLOAD) : {
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    } > RAM

    /DISCARD/ : {
        *(.comment*)
        *(.eh_frame*)
        *(.eh_frame_hdr*)
        *(.gnu*)
        *(.note*)
        *(.riscv.attributes)
    }
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM) - 16;
