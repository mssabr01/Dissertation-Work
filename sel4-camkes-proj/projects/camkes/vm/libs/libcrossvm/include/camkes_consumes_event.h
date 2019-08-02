/*
 * Copyright 2017, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
 */

#pragma once

typedef void (*camkes_event_callback_fn)(void *arg);

typedef struct camkes_consumes_event {
    unsigned int id;
    int (*reg_callback)(camkes_event_callback_fn, void *arg);
} camkes_consumes_event_t;

/* Registers a provided callback function with the event,
 * passing the callback a pointer to the camkes_event_t.
 */
static inline int
camkes_event_reg_callback_self(camkes_consumes_event_t *event, camkes_event_callback_fn cb)
{
    return event->reg_callback(cb, (void*)event);
}
