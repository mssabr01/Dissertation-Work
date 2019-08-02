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

/*- import 'helpers/error.c' as error with context -*/
/*- import 'helpers/array_check.c' as array_check with context -*/
/*- from 'helpers/tls.c' import make_tls_symbols -*/
/*- import 'helpers/marshal.c' as marshal with context -*/

/*? assert(isinstance(connector, namespace)) ?*/

#include <sel4/sel4.h>
#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sync/sem-bare.h>
#include <camkes/dataport.h>
#include <camkes/error.h>
#include <camkes/tls.h>

/*? macros.show_includes(me.instance.type.includes) ?*/
/*? macros.show_includes(me.interface.type.includes) ?*/

/*- set methods_len = len(me.interface.type.methods) -*/
/*- set instance = me.instance.name -*/
/*- set interface = me.interface.name -*/
/*- set threads = list(six.moves.range(1, 2 + len(me.instance.type.provides) + len(me.instance.type.uses) + len(me.instance.type.emits) + len(me.instance.type.consumes))) -*/

/* Interface-specific error handling */
/*- set error_handler = '%s_error_handler' % me.interface.name -*/
/*? error.make_error_handler(interface, error_handler) ?*/

/*? array_check.make_array_typedef_check_symbols(me.interface.type) ?*/

int /*? me.interface.name ?*/__run(void) {
    /* This function is never actually executed, but we still emit it for the
     * purpose of type checking RPC parameters.
     */
    UNREACHABLE();

    /*# Check any typedefs we have been given are not arrays. #*/
    /*? array_check.perform_array_typedef_check(me.interface.type) ?*/
    return 0;
}

/*- for i, m in enumerate(me.interface.type.methods) -*/

/*- set input_parameters = list(filter(lambda('x: x.direction in [\'refin\', \'in\', \'inout\']'), m.parameters)) -*/
/*? marshal.make_marshal_input_symbols(instance, interface, m.name, '%s_marshal_inputs' % m.name, connector.send_buffer, connector.send_buffer_size, i, methods_len, input_parameters, error_handler, threads) ?*/

/*- set output_parameters = list(filter(lambda('x: x.direction in [\'out\', \'inout\']'), m.parameters)) -*/
/*? marshal.make_unmarshal_output_symbols(instance, interface, m.name, '%s_unmarshal_outputs' % m.name, connector.recv_buffer, i, output_parameters, m.return_type, error_handler, connector.recv_buffer_size_fixed) ?*/

/*- set ret_tls_var = c_symbol('ret_tls_var_from') -*/
/*- if m.return_type is not none -*/
  /*# We will need to take the address of a value representing this return
   *# value at some point. Construct a TLS variable.
   #*/
  /*? make_tls_symbols(macros.show_type(m.return_type), ret_tls_var, threads, False) ?*/
/*- endif -*/

/*- if m.return_type is not none -*/
    /*? macros.show_type(m.return_type) ?*/
/*- else -*/
    void
/*- endif -*/
/*? me.interface.name ?*/_/*? m.name ?*/(
/*? marshal.show_input_parameter_list(m.parameters, ['in', 'refin', 'out', 'inout']) ?*/
) {

    /*- if len(me.parent.from_ends) == 1 and len(me.parent.to_ends) == 1 and len(me.parent.to_end.instance.type.provides + me.parent.to_end.instance.type.uses + me.parent.to_end.instance.type.consumes + me.parent.to_end.instance.type.mutexes + me.parent.to_end.instance.type.semaphores) <= 1 and options.fspecialise_syscall_stubs and methods_len == 1 and m.return_type is none and len(m.parameters) == 0 -*/
        /*? maybe_perform_optimized_empty_call(connector) ?*/
    /*- endif -*/

    /*? begin_send(connector) ?*/

    /*- set ret_val = c_symbol('return') -*/
    /*- set ret_ptr = c_symbol('return_ptr') -*/
    /*- if m.return_type is not none -*/
      /*? macros.show_type(m.return_type) ?*/ /*? ret_val ?*/ UNUSED;
      /*? macros.show_type(m.return_type) ?*/ * /*? ret_ptr ?*/ = TLS_PTR(/*? ret_tls_var ?*/, /*? ret_val ?*/);
    /*- endif -*/

    /* Marshal all the parameters */
    /*- set length = c_symbol('length') -*/
    unsigned /*? length ?*/ = /*? marshal.call_marshal_input('%s_marshal_inputs' % m.name, input_parameters) ?*/;
    if (unlikely(/*? length ?*/ == UINT_MAX)) {
        /* Error in marshalling; bail out. */
        /*- if m.return_type is not none -*/
            /*- if m.return_type == 'string' -*/
                return NULL;
            /*- else -*/
                memset(/*? ret_ptr ?*/, 0, sizeof(* /*? ret_ptr ?*/));
                return * /*? ret_ptr ?*/;
            /*- endif -*/
        /*- else -*/
            return;
        /*- endif -*/
    }

    /*- set size = c_symbol('size') -*/
    unsigned /*? size ?*/;
    /*? perform_call(connector, size, length) ?*/

    /* Unmarshal the response */
    /*- set err = c_symbol('error') -*/
    int /*? err ?*/ = /*? marshal.call_unmarshal_output('%s_unmarshal_outputs' % m.name, size, output_parameters, m.return_type, ret_ptr) ?*/;
    if (unlikely(/*? err ?*/ != 0)) {
        /* Error in unmarshalling; bail out. */
        /*- if m.return_type is not none -*/
            /*- if m.return_type == 'string' -*/
                return NULL;
            /*- else -*/
                memset(/*? ret_ptr ?*/, 0, sizeof(* /*? ret_ptr ?*/));
                return * /*? ret_ptr ?*/;
            /*- endif -*/
        /*- else -*/
            return;
        /*- endif -*/
    }

    /*? release_recv(connector) ?*/

    /*- if m.return_type is not none -*/
        return * /*? ret_ptr ?*/;
    /*- endif -*/
}
/*- endfor -*/
