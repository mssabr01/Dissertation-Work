/*
 * Copyright 2017, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(DATA61_BSD)
 */

#pragma once

/**
 * Address at which the GPT should be in the initial
 * device space. Map a frame, uncached, to this address
 * to access the gpt. Pass the virtual address of
 * this frame onto timer_init to use the gpt.
 */
#define GPT1_DEVICE_PADDR 0x02098000
#define GPT1_INTERRUPT 87

#define GPT_PRESCALER (1)

