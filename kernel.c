#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define VGA_WIDTH   80
#define VGA_HEIGHT  25
#define VGA_MEMORY  0xB8000

uint16_t* term_buf = (uint16_t*)VGA_MEMORY;

static inline uint16_t vga_entry(unsigned char uc, uint8_t fg, uint8_t bg)
{
    const uint16_t color = fg | bg << 4;
	return (uint16_t) uc | color << 8;
}

void kernel_main(void)
{
    char* msg = "hello world!";
    for (size_t i = 0; i < 12; i++) {
        term_buf[i] = vga_entry(msg[i], 15, 0);
    }
}
