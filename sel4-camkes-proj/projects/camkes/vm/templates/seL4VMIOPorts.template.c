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

/*- set config_ioports = configuration[me.parent.to_instance.name].get(me.parent.to_interface.name) -*/
/*- set pci_ioports = [] -*/
/*- set nonpci_ioports = [] -*/
/*- if config_ioports is not none -*/
    /*- for ioport in config_ioports -*/
        /*- set cap = alloc('iport_%d_%d' % (ioport['start'], ioport['end']), seL4_IA32_IOPort, start_port=ioport['start'], end_port=ioport['end']) -*/
        /*- if ioport['pci_device'] is not none -*/
            /*- do pci_ioports.append( (cap, ioport['start'], ioport['end'], ioport['name'].strip('"')) ) -*/
        /*- else -*/
            /*- do nonpci_ioports.append( (cap, ioport['start'], ioport['end'], ioport['name'].strip('"')) ) -*/
        /*- endif -*/
    /*- endfor -*/
/*- endif -*/

int /*? me.interface.name ?*/_num_pci_ioports() {
    return /*? len(pci_ioports) ?*/;
}

int /*? me.interface.name ?*/_num_nonpci_ioports() {
    return /*? len(nonpci_ioports) ?*/;
}

const char */*? me.interface.name ?*/_get_pci_ioport(int num, seL4_CPtr *cap, uint16_t *start, uint16_t *end) {
    /*- if len(pci_ioports) == 0 -*/
        return NULL;
    /*- else -*/
        switch (num) {
        /*- for cap, start, end, name in pci_ioports -*/
            case /*? loop.index0 ?*/:
                *cap = /*? cap ?*/;
                *start = /*? start ?*/;
                *end = /*? end ?*/;
                return "/*? name ?*/";
        /*- endfor -*/
            default:
                return NULL;
        }
    /*- endif -*/
}

const char */*? me.interface.name ?*/_get_nonpci_ioport(int num, seL4_CPtr *cap, uint16_t *start, uint16_t *end) {
    /*- if len(nonpci_ioports) == 0 -*/
        return NULL;
    /*- else -*/
        switch (num) {
        /*- for cap, start, end, name in nonpci_ioports -*/
            case /*? loop.index0 ?*/:
                *cap = /*? cap ?*/;
                *start = /*? start ?*/;
                *end = /*? end ?*/;
                return "/*? name ?*/";
        /*- endfor -*/
            default:
                return NULL;
        }
    /*- endif -*/
}

seL4_CPtr /*? me.interface.name ?*/_get_ioport(uint16_t start, uint16_t end) {
    /*- set all_ports = pci_ioports + nonpci_ioports -*/
    /*- if len(all_ports) == 0 -*/
        return 0;
    /*- else -*/
        /*- for cap, start, end, name in all_ports -*/
        if (start >= /*? start ?*/ && end <= /*? end ?*/) {
            return /*? cap ?*/;
        }
        /*- endfor -*/
        return 0;
    /*- endif -*/
}
