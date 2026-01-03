#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define VGA_WIDTH   80
#define VGA_HEIGHT  25
#define VGA_MEMORY  0xB8000



typedef struct {
    uint32_t base;        // 0xFFFFFFFF
    uint32_t limit;       // 0x00FFFFFF
    uint8_t  flags;       // 0x0000000F
    uint8_t  access_byte; // 0x000000FF
} gdt_entry;

#define SEG_RW(x)        ((x) << 0x01) // Readable/writable
#define SEG_EXEC(x)      ((x) << 0x03) // Executable 
#define SEG_DESCTYPE(x)  ((x) << 0x04) // Descriptor type (0 for system, 1 for code/data)
#define SEG_PRIV(x)      ((x) << 0x05) // Set privilege level (0 - 3)
#define SEG_PRES(x)      ((x) << 0x07) // Present
#define SEG_TSS(x)       ((x * 0x9))   // Type=TSS

#define SEG_F_SIZE(x)      ((x) << 0x02) // Size (0 for 16-bit, 1 for 32)
#define SEG_F_GRAN(x)      ((x) << 0x03) // Granularity (0 for 1B - 1MB, 1 for 4KB - 4GB) 

static uint64_t new_gdt_entry(gdt_entry *entry)
{
    uint64_t result = 0;

    result |= ((uint64_t)entry->limit & 0x0000FFFF);
    result |= ((uint64_t)entry->base  & 0x00FFFFFF) << 16;
    result |= ((uint64_t)entry->access_byte)        << 40;
    result |= ((uint64_t)entry->limit & 0x00FF0000) << 48;
    result |= ((uint64_t)entry->flags & 0x0000000F) << 52;
    result |= ((uint64_t)entry->base  & 0xFF000000) << 56;

    return result;
}

static uint64_t gdt[] = {
    0, // null descriptor
    0, 0, // ring0 code and data segment
    0, 0, // ring3 code and data segment
    0, // TSS
};

static uint64_t gdt_data;

typedef struct {
    uint32_t prev_tss; 
    uint32_t esp0;     // Kernel stack pointer 
    uint32_t ss0;      // Kernel stack segment 
    uint32_t unused[22]; 
    uint32_t iomap_base;
} __attribute__((packed)) tss_entry;

static tss_entry tss_data; 

size_t strlen(char *s) 
{
    size_t len = 0;
    for (char *p = s; *p != 0; p++) 
    {
       len++;
    }

    return len;
}

uint16_t* term_buf = (uint16_t*)VGA_MEMORY;

static inline uint16_t vga_entry(unsigned char uc, uint8_t fg, uint8_t bg)
{
    const uint16_t color = fg | bg << 4;
	return (uint16_t) uc | color << 8;
}

void print(char *s) 
{
    size_t len = strlen(s);
    for (size_t i = 0; i < len; i++) 
    {
        term_buf[i] = vga_entry(s[i], 15, 0);
    }
}

void user_main() {
    print("anjing");
}

void _user_main() { 
    // can think of this as the preamble of a process.
    user_main();

    while (1) {} // we can't ret from this function (nowhere to ret).
}

void kernel_main(void)
{
    // we're on protected mode already thanks to multiboot.
    // kernel and user memory maps to the same linear address because we plan to use
    // paging instead later.
    //
    // NOTE: is there a way to make this run on comptime? 
    // using marcos is one possiblility but i can't make it readable for now.
    gdt_entry kernel_code_segment = {
        .base = 0, 
        .limit = 0xFFFFF, 
        .access_byte = SEG_PRES(1) | SEG_DESCTYPE(1) | SEG_EXEC(1) | SEG_RW(1), 
        .flags = SEG_F_GRAN(1) | SEG_F_SIZE(1),
    };
    gdt[1] = new_gdt_entry(&kernel_code_segment);

    gdt_entry kernel_data_segment = {
        .base = 0, 
        .limit = 0xFFFFF, 
        .access_byte = SEG_PRES(1) | SEG_DESCTYPE(1) | SEG_RW(1), 
        .flags = SEG_F_GRAN(1) | SEG_F_SIZE(1),
    };
    gdt[2] = new_gdt_entry(&kernel_data_segment);

    gdt_entry user_code_segment = {
        .base = 0, 
        .limit = 0xFFFFF, 
        .access_byte = SEG_PRES(1) | SEG_PRIV(3) | SEG_DESCTYPE(1) | SEG_EXEC(1) | SEG_RW(1), 
        .flags = SEG_F_GRAN(1) | SEG_F_SIZE(1),
    };
    gdt[3] = new_gdt_entry(&user_code_segment);

    gdt_entry user_data_segment = {
        .base = 0, 
        .limit = 0xFFFFF, 
        .access_byte = SEG_PRES(1) | SEG_PRIV(3) | SEG_DESCTYPE(1) | SEG_RW(1),  
        .flags = SEG_F_GRAN(1) | SEG_F_SIZE(1),
    };
    gdt[4] = new_gdt_entry(&user_data_segment);
    
    // init tss so we can enter ring3 and still able to handle interrupts.
    extern uint32_t stack_top;
    tss_data.esp0 = (uint32_t)(&stack_top);
    tss_data.ss0 = 0x10; 
    tss_data.iomap_base = sizeof(tss_data); // disable, not so sure what's the significance of this yet.

    gdt_entry tss = {
        .base = (uintptr_t)(&tss_data),
        .limit = 104,
        .access_byte = SEG_PRES(1) | SEG_TSS(1),
        .flags = 0,
    };
    gdt[5] = new_gdt_entry(&tss);

    // load GDT table
    gdt_data = (8*6); // limit: 6 entries, 8 byte each.
    gdt_data |= (uint64_t)(&gdt) << 16;

    __asm__ volatile (
        ".intel_syntax noprefix\n"
        "cli\n"
        "lgdt [%0]\n"
        :
        : "m"(gdt_data)
    );

    // reload cs register
    __asm__ goto (
        "pushl $0x08\n\t"              // Push the new Code Segment selector (0x08)
        "pushl $%l[reload_CS]\n\t"     // Push the address of the label
        "lretl"
        :
        :
        :
        : reload_CS
    );
reload_CS:

    // reload segment registers
    __asm__ volatile (
        ".intel_syntax noprefix\n"
        "mov ax, 0x10\n"
        "mov ds, ax\n"
        "mov es, ax\n"
        "mov fs, ax\n"
        "mov gs, ax\n"
        "mov ss, ax\n"
        ::: "eax"
    );

    // load tss
    __asm__ volatile("ltr %%ax" : : "a" (0x28));

    // switch to user mode
    extern uint32_t user_stack_top;
    __asm__ volatile (
        "mov $0x23, %%ax\n\t"  // 0x23 is User Data segment (0x20 | 3)
        "mov %%ax, %%ds\n\t"
        "mov %%ax, %%es\n\t"
        "mov %%ax, %%fs\n\t"
        "mov %%ax, %%gs\n\t"
        "pushl $0x23\n\t"      // User SS
        "pushl %1\n\t"         // User ESP
        "pushf\n\t"            // EFLAGS
        "pushl $0x1B\n\t"      // User CS (0x18 | 3)
        "pushl %0\n\t"         // User EIP
        "iret"                 // The magic jump
        : : "r"(_user_main), "r"(&user_stack_top) : "ax"
    );
}

