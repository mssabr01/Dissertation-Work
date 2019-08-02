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

#include <assert.h>
#include <camkes/error.h>
#include <stdio.h>
#include <stdint.h>
#include <sel4/sel4.h>

/*? macros.show_includes(me.instance.type.includes) ?*/

/*- set regions = configuration[me.parent.to_instance.name].get(me.parent.to_interface.name) -*/
static uintptr_t exclude_regions[] = {
/*- if regions is not none -*/
    /*- for paddr, bytes in regions -*/
        /*? paddr ?*/, /*? bytes ?*/,
    /*- endfor -*/
/*- endif -*/
};

int /*? me.interface.name ?*/_num_regions() {
    return ARRAY_SIZE(exclude_regions) / 2;
}

void /*? me.interface.name ?*/_get_region(int region_num, uintptr_t *paddr, size_t *bytes) {
    assert(paddr);
    assert(bytes);
    assert(region_num < /*? me.interface.name ?*/_num_regions());
    *paddr = exclude_regions[region_num * 2];
    *bytes = exclude_regions[(region_num * 2) + 1];
}
