#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "bp_utils.h"
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

/*
// Set mtimecmp
static void set_mtimecmp(unsigned long value)
{
	asm volatile ("csrs mie, %0\n" : : "r"(value) : "memory");
}


// Enable external interrupt
static void external_interrupt_enable()
{
	unsigned long tmp;
	asm volatile ("li %0, (1 << 11)\n" : "=r"(tmp));
	asm volatile ("csrs mie, %0\n" : : "r"(tmp) : "memory");
}
// Enable timer interrupt
static void timer_interrupt_enable()
{
	unsigned long tmp;
	asm volatile ("li %0, (1 << 7)\n" : "=r"(tmp));
	asm volatile ("csrs mie, %0\n" : : "r"(tmp) : "memory");
}
// Enable global machine interrupt
static void global_interrupt_enable()
{
	unsigned long tmp;
	asm volatile ("li %0, (1 << 3)\n" : "=r"(tmp));
	asm volatile ("csrs mstatus, %0\n" : : "r"(tmp) : "memory");
}
// Disable global machine interrupt
static void global_interrupt_disable()
{
	unsigned long tmp;
	asm volatile ("li %0, (1 << 3)\n" : "=r"(tmp));
	asm volatile ("csrc mstatus, %0\n" : : "r"(tmp) : "memory");
}

unsigned long get_mtimecmp()
{
	unsigned long tmp, cnt;
	asm volatile ("li %0, 0x304000\n" : "=r"(tmp));
	asm volatile ("ld %0, 0(%1)\n" : "=r"(cnt) : "r"(tmp));
	return cnt;
}
*/


/*
unsigned long get_time()
{
	unsigned long tmp, cnt;
	asm volatile ("li %0, 0x30bff8\n" : "=r"(tmp));
	asm volatile ("ld %0, 0(%1)\n" : "=r"(cnt) : "r"(tmp));
	return cnt;
}


void print_time()
{
	printf("%lu\n", get_time());
}

void mmio_tx_test(unsigned char data)
{
	unsigned long tmp;
	asm volatile ("li %0, 0x1000000000\n" : "=r"(tmp));
	asm volatile ("sb %0, 0(%1)\n" : : "r"(data), "r"(tmp) : "memory");
}
unsigned mmio_rx_test()
{
	unsigned long tmp;
	unsigned char val;
	asm volatile ("li %0, 0x1000000001\n" : "=r"(tmp));
	asm volatile ("lb %0, 0(%1)\n" : "=r"(val) : "r"(tmp));
	return val;
}

*/
volatile void *buffer = 0x80300000;
volatile unsigned long *cmd1     = 0x500000;
volatile unsigned long *cmd2     = 0x500008;

int main()
{
//	unsigned long  *addr = 0x30bff8;
/*    external_interrupt_enable();
    global_interrupt_enable();
    dramfs_init();
    while(occurrence < 3) {
      if(external_interrupt_set) {
        global_interrupt_disable();
        printf("Interrupt occurred\n");
        external_interrupt_set = 0;
        occurrence++;
        global_interrupt_enable();
      }
    }*/
/*    dramfs_init();
    *cmd1 = (1UL << 61) | (0x80300000UL); // init
    while((*cmd1 & 3UL) != 2UL) // poll until packet arrives
        ;
    unsigned long size = *(unsigned long *)buffer;
    if(size == 128) {
        for(int i = 0;i < size / 4;i++) {
            volatile unsigned char *tmp = buffer + 8 + i * 4;
            printf("%.2x %.2x %.2x %.2x\n", *tmp, *(tmp + 1), *(tmp + 2), *(tmp + 3));
        }
        for(int i = 0;i < (size % 4);i++) {
            printf("%.2x\n", *(unsigned char *)(buffer + 8 + size / 4 * 4 + i));
        }
    }*/
    dramfs_init();
    printf("Hello from 2\n");
    return 0;
}

