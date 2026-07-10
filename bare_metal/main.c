#include <stdint.h>

#define GPIO_BASE 0x10000000
#define GPIO_DIR (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define GPIO_OUT (*(volatile uint32_t *)(GPIO_BASE + 0x04))

uint32_t blink_count = 0;

uint32_t error_count;

static void delay(volatile uint32_t n) {
    while (n--);
}

int main(void) {

    GPIO_DIR = 0xFF;

    while (1) {
        GPIO_OUT = 0x01;
        delay(100000);
        GPIO_OUT = 0x00;
        delay(100000);
        blink_count++;
    }
    return 0;
}