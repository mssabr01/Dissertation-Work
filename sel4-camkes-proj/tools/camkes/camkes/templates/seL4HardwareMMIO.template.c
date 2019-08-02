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
#include <camkes/dataport.h>
#include <stddef.h>
#include <stdint.h>
#include <platsupport/io.h>
#include <utils/util.h>
#include <sel4/sel4.h>
/*? macros.show_includes(me.instance.type.includes) ?*/

/*- set index = me.parent.from_ends.index(me) -*/

/*- set paddr = configuration[me.parent.to_instance.name].get('%s_paddr' % me.parent.to_interface.name) -*/
/*- if paddr is none -*/
  /*? raise(TemplateError('Setting %s.%s_paddr that should specify the physical address of an MMIO device is not set' % (me.parent.to_instance.name, me.parent.to_interface.name))) ?*/
/*- endif -*/
/*- if not isinstance(paddr, numbers.Integral) or paddr < 0 -*/
  /*? raise(TemplateError('Setting %s.%s_paddr that should specify the physical address of an MMIO device does not appear to be a valid address' % (me.parent.to_instance.name, me.parent.to_interface.name))) ?*/
/*- endif -*/

/*- set size = configuration[me.parent.to_instance.name].get('%s_size' % me.parent.to_interface.name) -*/
/*- if size is none -*/
  /*? raise(TemplateError('Setting %s.%s_size that should specify the size of an MMIO device is not set' % (me.parent.to_instance.name, me.parent.to_interface.name))) ?*/
/*- endif -*/
/*- if not isinstance(size, numbers.Integral) or size <= 0 -*/
  /*? raise(TemplateError('Setting %s.%s_size that should specify the size of an MMIO device does not appear to be a valid size' % (me.parent.to_instance.name, me.parent.to_interface.name))) ?*/
/*- endif -*/
/*- set page_size = macros.get_page_size(size, options.architecture) -*/
/*- if page_size == 0 -*/
  /*? raise(TemplateError('Setting %s.%s_size does not meet minimum size requirements. %d must be at least %d and %d aligned' % (me.parent.to_instance.name, me.parent.to_interface.name, size, 4096, 4096))) ?*/
/*- endif -*/
/*- set page_size_bits = int(math.log(page_size, 2)) -*/

/*- set cached = configuration[me.parent.to_instance.name].get('%s_hardware_cached' % me.parent.to_interface.name, False) -*/


/*- set dataport_symbol_name = "from_%d_%s_data" % (index, me.interface.name) -*/
struct {
    char content[ROUND_UP_UNSAFE(/*? macros.dataport_size(me.interface.type) ?*/,
        PAGE_SIZE_4K)];
} /*? dataport_symbol_name ?*/
        ALIGN(/*? page_size ?*/)
        SECTION("align_/*? page_size_bits ?*/bit")
        VISIBLE
        USED;

/*? register_shared_variable('%s_data' % me.parent.name, dataport_symbol_name, size, frame_size=page_size, perm='RW', paddr=paddr, cached=cached) ?*/

/*# We need to copy all of the frame caps into our cspace for frame cache operations #*/
/*- set frame_objs = get_shared_variable_backing_frames('%s_data' % me.parent.name, size) -*/
/*- set frame_caps = [] -*/
/*- for (i, frame) in enumerate(frame_objs) -*/
    /*- set frame_cap = alloc_cap('%s_%d' % ('%s_data' % me.parent.name, i), frame) -*/
    /*- do frame_caps.append(frame_cap) -*/
/*- endfor -*/

volatile /*? macros.dataport_type(me.interface.type) ?*/ * /*? me.interface.name ?*/ =
    (volatile /*? macros.dataport_type(me.interface.type) ?*/ *) & /*? dataport_symbol_name ?*/;

/*- set id = composition.connections.index(me.parent) -*/

int /*? me.interface.name ?*/_wrap_ptr(dataport_ptr_t *p, void *ptr) {
    /*- set offset = c_symbol('offset') -*/
    off_t /*? offset ?*/ = (off_t)((uintptr_t)ptr - (uintptr_t)/*? me.interface.name ?*/);
    if (/*? offset ?*/ < /*? macros.dataport_size(me.interface.type) ?*/) {
        p->id = /*? id ?*/;
        p->offset = /*? offset ?*/;
        return 0;
    } else {
        return -1;
    }
}

void * /*? me.interface.name ?*/_unwrap_ptr(dataport_ptr_t *p) {
    if (p->id == /*? id ?*/) {
        return (void*)((uintptr_t)/*? me.interface.name ?*/ + (uintptr_t)p->offset);
    } else {
        return NULL;
    }
}


/*# Check if we have reserved enough virtual memory for the MMIO. #*/
static_assert(/*? macros.dataport_size(me.interface.type) ?*/ == /*? size ?*/, "Data type mismatch!");


void * /*? me.interface.name ?*/_translate_paddr(
        uintptr_t paddr, size_t size) {
    if (paddr == /*? paddr ?*/ && size == /*? size ?*/) {
        return (void*)/*? me.interface.name ?*/;
    }
    return NULL;
}

/*- set frame_caps_symbol = c_symbol('frame_caps') -*/

/*# Allocate frame objects to back the hardware dataport #*/
static const seL4_CPtr /*? frame_caps_symbol ?*/[] = {
        /*- for cap in frame_caps -*/
            /*? cap ?*/,
        /*- endfor -*/
};

/*# We only pull frame_caps from the stash. This is because only one caller of register_shared_variable
    should pass a frames parameter. By not stashing the frame_objs we ensure that only the original
    creator passed the frames, and everyone else will still have a None here #*/

/*- if options.architecture in ('aarch32', 'arm_hyp', 'aarch64') -*/
    static int sel4_cache_op(seL4_CPtr frame_cap, seL4_Word start, seL4_Word end, dma_cache_op_t cache_op) {
        switch (cache_op) {
        case DMA_CACHE_OP_CLEAN:
            return seL4_ARM_Page_Clean_Data(frame_cap, start, end);
        case DMA_CACHE_OP_INVALIDATE:
            return seL4_ARM_Page_Invalidate_Data(frame_cap, start, end);
        case DMA_CACHE_OP_CLEAN_INVALIDATE:
            return seL4_ARM_Page_CleanInvalidate_Data(frame_cap, start, end);
        default:
            ZF_LOGF("Invalid cache_op %d", cache_op);
            return -1;
        }
    }
/*- endif -*/

/* Flush data corresponding to the dataport-relative address range from the CPU cache */
int /*? me.interface.name ?*/_flush_cache(size_t start_offset UNUSED, size_t size UNUSED, dma_cache_op_t cache_op UNUSED) {
    /*- if options.architecture in ('aarch32', 'arm_hyp', 'aarch64') -*/

    if (start_offset >= /*? size ?*/ || size > /*? size ?*/ || /*? size ?*/ - size < start_offset) {
        ZF_LOGE("Specified range is outside the bounds of the dataport");
        return -1;
    }

    size_t current_offset = start_offset;
    size_t end_offset = start_offset + size;

    while (current_offset < end_offset) {
        size_t frame_top = MIN(ROUND_UP(current_offset + 1, /*? macros.PAGE_SIZE ?*/), end_offset);
        seL4_CPtr frame_cap = /*? frame_caps_symbol ?*/[current_offset / /*? macros.PAGE_SIZE ?*/];
        size_t frame_start_offset = current_offset % /*? macros.PAGE_SIZE ?*/;
        size_t frame_end_offset = ((frame_top - 1) % /*? macros.PAGE_SIZE ?*/) + 1;
        int error = sel4_cache_op(frame_cap, frame_start_offset,  frame_end_offset, cache_op);
        if (error) {
            ZF_LOGE("Cache flush syscall returned with error: %d", error);
            return error;
        }
        current_offset = frame_top;
    }

    /*- endif -*/
    return 0;
}
