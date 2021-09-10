#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "bp_utils.h"
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

volatile void *ethernet_buffer   = 0x80300000;
volatile unsigned long *cmd1     = 0x500000;
volatile unsigned long *cmd2     = 0x500008;

int received_size;
char recv_buf[1024] __attribute__ ((aligned (8)));
char send_buf[1024] __attribute__ ((aligned (8)));

void ethernet_set_recv_addr(unsigned long addr)
{
    unsigned long status = *cmd1;
    if((status & 1UL) == 0UL)
        *cmd1 = (1UL << 61) | addr;
}

// buf cannot overlap with ethernet_buffer
int ethernet_recv(void *buf, unsigned *size)
{
    unsigned size_offset, offset;
    unsigned long status = *cmd1;
    if((status & 3UL) == 2UL) {
        size_offset = *(unsigned *)ethernet_buffer;
        *size = size_offset & ((1U << 16) - 1);
        offset = size_offset >> 16;
        memcpy(buf, ethernet_buffer + 8 + offset, *size);
        *cmd1 = (1UL << 62); // ACK
        return 0;
    }
    return 1;
}

int ethernet_send(void *buf, unsigned size)
{
    unsigned offset;
    unsigned long status;
    unsigned long partial, partial_size;

    offset = (unsigned long)buf & 7UL;
    // specify the size and offset
    *cmd2 = (offset << 16) | (size & ((1U << 16) - 1));

    partial = 0;
    memcpy((void *)&partial + offset, buf, 8 - offset);
    // first beat
    *cmd2 = partial;

    // remove first beat
    size -= (8 - offset);
    buf  += (8 - offset);
    for(int i = 0;i < size / 8;i++)
        *cmd2 = *(unsigned long *)(buf + 8 * i);
    if(size % 8) {
        // remainder
        partial = 0;
        partial_size = size - size / 8 * 8;
        memcpy(&partial, buf + size / 8 * 8, partial_size);
        // last beat
        *cmd2 = partial;
    }
    status = *cmd1;
    if(((status >> 2) & 3UL) != 0) {
        return 2;
    }
    return 0;
}

int main()
{
    int ret;
    const int offset = 0;
    printf("test1 start\n");
    ethernet_set_recv_addr(ethernet_buffer);
    unsigned size = 100;
    for(int i = 0;i < size;i++) {
        send_buf[i + offset] = i;
    }
    // send packet
    if((ret = ethernet_send(&send_buf[offset], size)) != 0) {
        printf("failed: %d\n", ret);
        return 1;
    }
    printf("test1 ethernet_send done\n");
    // wait for packet
    while(ethernet_recv(recv_buf, &received_size))
        ;
    for(int i = 0;i < received_size;i++)
        printf("%d ", recv_buf[i]);
    printf("\n");

    printf("test1 done\n");
    for(;;) {
        
    }

    return 0;
}

