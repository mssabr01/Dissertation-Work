/*
 * Copyright 2018, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(DATA61_BSD)
 */

#include <autoconf.h>
#include <assert.h>
#include <stdio.h>
#include <sel4/sel4.h>
#include <sel4/arch/constants.h>
#include <camkes.h>
#include <platsupport/plat/timer.h>
#include <utils/util.h>
#include <sel4utils/sel4_zf_logif.h>
#include <simple/simple.h>

#include "../../plat.h"
#include "../../time_server.h"

#define PWM_ADDR (unsigned int)pwm_mem

void pwm_irq_t0_handle() {
    time_server_irq_handle(pwm_irq_t0_acknowledge);
}

void pwm_irq_t1_handle() {
    time_server_irq_handle(pwm_irq_t1_acknowledge);
}
void pwm_irq_t2_handle() {
    time_server_irq_handle(pwm_irq_t2_acknowledge);
}

void pwm_irq_t3_handle() {
    time_server_irq_handle(pwm_irq_t3_acknowledge);
}

void pwm_irq_t4_handle() {
    time_server_irq_handle(pwm_irq_t4_acknowledge);
}

void plat_post_init(ltimer_t *ltimer, ps_io_ops_t ops) {
    int error;

    error = ltimer_static_init(ltimer, ops, (void *)PWM_ADDR);
    ZF_LOGF_IF(error, "Failed to get timer");

    error = pwm_irq_t0_acknowledge();
    ZF_LOGF_IF(error, "Failed to ack pwm irq t0 irq");

    error = pwm_irq_t1_acknowledge();
    ZF_LOGF_IF(error, "Failed to ack pwm irq t1 irq");

    error = pwm_irq_t2_acknowledge();
    ZF_LOGF_IF(error, "Failed to ack pwm irq t2 irq");

    error = pwm_irq_t3_acknowledge();
    ZF_LOGF_IF(error, "Failed to ack pwm irq t3 irq");

    error = pwm_irq_t4_acknowledge();
    ZF_LOGF_IF(error, "Failed to ack pwm irq t4 irq");

}
