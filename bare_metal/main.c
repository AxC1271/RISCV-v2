#include <stdint.h>

#define GPIO_BASE 0x10000000
#define GPIO_DIR (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define GPIO_OUT (*(volatile uint32_t *)(GPIO_BASE + 0x04))

#define UART_BASE 0x10001000
#define UART_TXDATA (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_RXDATA (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x08))
#define UART_TX_BUSY  0x1
#define UART_RX_VALID 0x2

uint32_t blink_count = 0;

static void delay(volatile uint32_t n) {
    while (n--);
}

// poll before every write
static void uart_putc(char c) {
    while (UART_STATUS & UART_TX_BUSY);
    UART_TXDATA = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

int main(void) {

    GPIO_DIR = 0xFF;
    uart_puts("boot\r\n");

    while (1) {
        GPIO_OUT = 0x01;
        delay(100000);
        GPIO_OUT = 0x00;
        delay(100000);
        blink_count++;
    }
    return 0;
}