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

/*- if configuration[me.instance.name].get('environment', 'c').lower() == 'c' -*/

/*- from 'rpc-connector.c' import establish_recv_rpc, recv_first_rpc, complete_recv, begin_recv, begin_reply, complete_reply, reply_recv with context -*/

#include <camkes/dataport.h>

/*? macros.show_includes(me.instance.type.includes) ?*/
/*? macros.show_includes(me.interface.type.includes) ?*/

/*# Determine if we trust our partner. If we trust them, we can be more liberal
 *# with error checking.
 #*/
/*- set _trust_partner = [True] -*/
/*- for f in me.parent.from_ends -*/
  /*- if configuration[f.instance.name].get('trusted') != '"true"' -*/
    /*- do _trust_partner.__setitem__(0, False) -*/
  /*- endif -*/
/*- endfor -*/
/*- set trust_partner = _trust_partner[0] -*/

/*- set connector = namespace() -*/

/*- set buffer = configuration[me.parent.name].get('buffer') -*/
/*- if buffer is none -*/
  /*? establish_recv_rpc(connector, trust_partner, me.interface.name) ?*/
/*- else -*/
  /*- if not isinstance(buffer, six.string_types) -*/
    /*? raise(TemplateError('invalid non-string setting for userspace buffer to back RPC connection', me.parent)) ?*/
  /*- endif -*/
  /*- if len(me.parent.from_ends) != 1 or len(me.parent.to_ends) != 1 -*/
    /*? raise(TemplateError('invalid use of userspace buffer to back RPC connection that is not 1-to-1', me.parent)) ?*/
  /*- endif -*/
  /*- set c = filter(lambda('x: x.name == \'%s\'' % buffer), composition.connections) -*/
  /*- if len(c) == 0 -*/
    /*? raise(TemplateError('invalid setting to non-existent connection for userspace buffer to back RPC connection', me.parent)) ?*/
  /*- endif -*/
  /*- if len(c[0].from_ends) != 1 or len(c[0].to_ends) != 1 -*/
    /*? raise(TemplateError('invalid use of userspace buffer that is not 1-to-1 to back RPC connection', me.parent)) ?*/
  /*- endif -*/
  /*- if not isinstance(c[0].to_end.interface, camkes.ast.Dataport) -*/
    /*? raise(TemplateError('invalid use of non-dataport to back RPC connection', me.parent)) ?*/
  /*- endif -*/
  extern /*? macros.dataport_type(c[0].to_end.interface.type) ?*/ * /*? c[0].to_end.interface.name ?*/;
  /*? establish_recv_rpc(connector, trust_partner, me.interface.name, buffer=('((void*)%s)' % c[0].to_end.interface.name, macros.dataport_size(c[0].to_end.interface.type))) ?*/
/*- endif -*/

/*- include 'rpc-connector-common-to.c' -*/

/*- endif -*/
