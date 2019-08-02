#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Copyright 2017, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

'''Entry point for the runner (template instantiator).'''

from __future__ import absolute_import, division, print_function, \
    unicode_literals
from camkes.internal.seven import cmp, filter, map, zip

# Excuse this horrible prelude. When running under a different interpreter we
# have an import path that doesn't include dependencies like elftools and
# Jinja. We need to juggle the import path prior to importing them. Note, this
# code has no effect when running under the standard Python interpreter.
import platform, subprocess, sys
if platform.python_implementation() != 'CPython':
    path = eval(subprocess.check_output(['python', '-c',
        'import sys; sys.stdout.write(\'%s\' % sys.path)'],
        universal_newlines=True))
    for p in path:
        if p not in sys.path:
            sys.path.append(p)

from camkes.ast import ASTError, Connection, Connector
from camkes.templates import Templates, PLATFORMS, TemplateError
import camkes.internal.log as log
from camkes.internal.version import sources, version
from camkes.internal.exception import CAmkESError
from camkes.runner.NameMangling import Perspective, RUNNER
from camkes.runner.Renderer import Renderer
from camkes.runner.Filters import CAPDL_FILTERS

import argparse, collections, functools, jinja2, locale, numbers, os, re, \
    six, sqlite3, string, sys, traceback, pickle, errno
from capdl import ObjectType, ObjectAllocator, CSpaceAllocator, \
    ELF, lookup_architecture, AddressSpaceAllocator

from camkes.parser import parse_file, ParseError, parse_query_parser_args, print_query_parser_help

CAPDL_STATE_PICKLE = 'capdl_state.p'

class ParserOptions():
    def __init__(self, cpp, cpp_flag, import_path, verbosity, allow_forward_references,save_ast,load_ast, queries):
        self.cpp = cpp
        self.cpp_flag = cpp_flag
        self.import_path = import_path
        self.verbosity = verbosity
        self.allow_forward_references = allow_forward_references
        self.save_ast = save_ast
        self.load_ast = load_ast
        self.queries = queries

class FilterOptions():
    def __init__(self, architecture, realtime, largeframe, largeframe_dma, default_priority,
            default_max_priority, default_affinity,
            default_period, default_budget, default_data, default_size_bits, debug_fault_handlers,
            fprovide_tcb_caps):
        self.architecture = architecture
        self.realtime = realtime
        self.largeframe = largeframe
        self.largeframe_dma = largeframe_dma
        self.default_priority = default_priority
        self.default_max_priority = default_max_priority
        self.default_affinity = default_affinity
        self.default_period = default_period
        self.default_budget = default_budget
        self.default_data = default_data
        self.default_size_bits = default_size_bits
        self.debug_fault_handlers = debug_fault_handlers
        self.fprovide_tcb_caps = fprovide_tcb_caps

class RenderState():
    def __init__(self, obj_space, cspaces={}, pds={}, addr_spaces={}):
        self.obj_space = obj_space
        self.cspaces = cspaces
        self.pds = pds
        self.addr_spaces = addr_spaces

class RenderOptions():
    def __init__(self, file, verbosity, frpc_lock_elision, fspecialise_syscall_stubs,
            fprovide_tcb_caps, fsupport_init, largeframe, largeframe_dma, architecture,
            debug_fault_handlers, default_stack_size, realtime, verification_base_name,
            filter_options, render_state):
        self.file = file
        self.verbosity = verbosity
        self.frpc_lock_elision = frpc_lock_elision
        self.fspecialise_syscall_stubs = fspecialise_syscall_stubs
        self.fprovide_tcb_caps = fprovide_tcb_caps
        self.fsupport_init = fsupport_init
        self.largeframe = largeframe
        self.largeframe_dma = largeframe_dma
        self.architecture = architecture
        self.debug_fault_handlers = debug_fault_handlers
        self.default_stack_size = default_stack_size
        self.realtime = realtime
        self.verification_base_name = verification_base_name
        self.filter_options = filter_options
        self.render_state = render_state

def safe_decode(s):
    '''
    Safely extract a string that may contain invalid character encodings.

    When formatting a traceback that crosses a boundary between compiled and
    interpreted code, the backtracer can lose the frame pointer and start
    appending garbage to the traceback. If we try to print this we trigger a
    UnicodeDecodeError. To avoid this, wrap traceback printing in this
    function.
    '''
    r = []
    for c in s:
        if c not in string.printable:
            r.append('\n  <MALFORMED BYTES>\n')
            break
        r.append(c)
    return ''.join(r)

def _die(options, message):

    if isinstance(message, (list, tuple)):
        for line in message:
            log.error(line)
    else:
        log.error(message)

    tb = traceback.format_exc()
    log.debug('\n --- Python traceback ---\n%s ------------------------\n' %
        safe_decode(tb))
    if options.cache and re.search(r'^\s*File\s+".*\.pyc",\s+line\s+\d+,\s*in'
            r'\s*top-level\s*template\s*code$', tb, flags=re.MULTILINE) is \
            not None:
        log.debug('If the preceding backtrace traverses a pre-compiled '
            'template, you may wish to disable the CAmkES cache and re-run '
            'for a more accurate backtrace.\n')
    sys.exit(-1)

def parse_args(argv, out, err):
    parser = argparse.ArgumentParser(prog='python -m camkes.runner',
        description='instantiate templates based on a CAmkES specification')
    parser.add_argument('--cpp', action='store_true', help='Pre-process the '
        'source with CPP')
    parser.add_argument('--nocpp', action='store_false', dest='cpp',
        help='Do not pre-process the source with CPP')
    parser.add_argument('--cpp-flag', action='append', default=[],
        help='Specify a flag to pass to CPP')
    parser.add_argument('--import-path', '-I', help='Add this path to the list '
        'of paths to search for built-in imports. That is, add it to the list '
        'of directories that are searched to find the file "foo" when '
        'encountering an expression "import <foo>;".', action='append',
        default=[])
    parser.add_argument('--quiet', '-q', help='No output.', dest='verbosity',
        default=1, action='store_const', const=0)
    parser.add_argument('--verbose', '-v', help='Verbose output.',
        dest='verbosity', action='store_const', const=2)
    parser.add_argument('--debug', '-D', help='Extra verbose output.',
        dest='verbosity', action='store_const', const=3)
    parser.add_argument('--outfile', '-O', help='Output to the given file.',
        type=argparse.FileType('w'), required=True, action='append', default=[])
    parser.add_argument('--verification-base-name', type=str,
        help='Identifier to use when generating Isabelle theory files')
    parser.add_argument('--elf', '-E', help='ELF files to contribute to a '
        'CapDL specification.', action='append', default=[])
    parser.add_argument('--item', '-T', help='AST entity to produce code for.',
        required=True, action='append', default=[])
    parser.add_argument('--platform', '-p', help='Platform to produce code '
        'for. Pass \'help\' to see valid platforms.', default='seL4',
        choices=PLATFORMS)
    parser.add_argument('--templates', '-t', help='Extra directories to '
        'search for templates (before builtin templates).', action='append',
        default=[])
    parser.add_argument('--cache', '-c', action='store_true',
        help='Enable code generation cache.')
    parser.add_argument('--cache-dir',
        default=os.path.expanduser('~/.camkes/cache'),
        help='Set code generation cache location.')
    parser.add_argument('--version', action='version', version='%s %s' %
        (argv[0], version()))
    parser.add_argument('--frpc-lock-elision', action='store_true',
        default=True, help='Enable lock elision optimisation in seL4RPC '
        'connector.')
    parser.add_argument('--fno-rpc-lock-elision', action='store_false',
        dest='frpc_lock_elision', help='Disable lock elision optimisation in '
        'seL4RPC connector.')
    parser.add_argument('--fspecialise-syscall-stubs', action='store_true',
        default=True, help='Generate inline syscall stubs to reduce overhead '
        'where possible.')
    parser.add_argument('--fno-specialise-syscall-stubs', action='store_false',
        dest='fspecialise_syscall_stubs', help='Always use the libsel4 syscall '
        'stubs.')
    parser.add_argument('--fprovide-tcb-caps', action='store_true',
        default=True, help='Hand out TCB caps to components, allowing them to '
        'exit cleanly.')
    parser.add_argument('--fno-provide-tcb-caps', action='store_false',
        dest='fprovide_tcb_caps', help='Do not hand out TCB caps, causing '
        'components to fault on exiting.')
    parser.add_argument('--fsupport-init', action='store_true', default=True,
        help='Support pre_init, post_init and friends.')
    parser.add_argument('--fno-support-init', action='store_false',
        dest='fsupport_init', help='Do not support pre_init, post_init and '
        'friends.')
    parser.add_argument('--default-priority', type=int, default=254,
        help='Default component thread priority.')
    parser.add_argument('--default-max-priority', type=int, default=254,
        help='Default component thread maximum priority.')
    parser.add_argument('--default-affinity', type=int, default=0,
        help='Default component thread affinity.')
    parser.add_argument('--default-period', type=int, default=10000,
        help='Default component thread scheduling context period.')
    parser.add_argument('--default-budget', type=int, default=10000,
        help='Default component thread scheduling context budget.')
    parser.add_argument('--default-data', type=int, default=0,
        help='Default component thread scheduling context data.')
    parser.add_argument('--default-size_bits', type=int, default=8,
        help='Default scheduling context size bits.')
    parser.add_argument('--default-stack-size', type=int, default=16384,
        help='Default stack size of each thread.')
    parser.add_argument('--prune', action='store_true',
        help='Minimise the number of functions in generated C files.')
    parser.add_argument('--largeframe', action='store_true',
        help='Try to use large frames when possible.')
    parser.add_argument('--architecture', '--arch', default='aarch32',
        type=lambda x: type('')(x).lower(), choices=('aarch32', 'arm_hyp', 'ia32', 'x86_64', 'aarch64'),
        help='Target architecture.')
    parser.add_argument('--makefile-dependencies', '-MD',
        type=argparse.FileType('w'), help='Write Makefile dependency rule to '
        'FILE')
    parser.add_argument('--allow-forward-references', action='store_true',
        help='allow refering to objects in your specification that are '
        'defined after the point at which they are referenced')
    parser.add_argument('--disallow-forward-references', action='store_false',
        dest='allow_forward_references', help='only permit references in '
        'specifications to objects that have been defined before that point')
    parser.add_argument('--debug-fault-handlers', action='store_true',
        help='provide fault handlers to decode cap and VM faults for the '
        'purposes of debugging')
    parser.add_argument('--largeframe-dma', action='store_true',
        help='promote frames backing DMA pools to large frames where possible')
    parser.add_argument('--realtime', action='store_true',
        help='Target realtime seL4.')

    object_state_group = parser.add_mutually_exclusive_group()
    object_state_group.add_argument('--load-object-state', type=argparse.FileType('rb'),
        help='load previously-generated cap and object state')
    object_state_group.add_argument('--save-object-state', type=argparse.FileType('wb'),
        help='save generated cap and object state to this file')

    parser.add_argument('--save-ast',type=argparse.FileType('wb'), help='cache the ast during the build')
    # To get the AST, there should be either a pickled AST or a file to parse
    adl_group = parser.add_mutually_exclusive_group(required=True)
    adl_group.add_argument('--load-ast',type=argparse.FileType('rb'), help='load the cached ast during the build')
    adl_group.add_argument('--file', '-f', help='Add this file to the list of '
        'input files to parse. Files are parsed in the order in which they are '
        'encountered on the command line.', type=argparse.FileType('r'))

    # Juggle the standard streams either side of parsing command-line arguments
    # because argparse provides no mechanism to control this.
    old_out = sys.stdout
    old_err = sys.stderr
    sys.stdout = out
    sys.stderr = err
    options, argv = parser.parse_known_args(argv[1:])
    queries, argv = parse_query_parser_args(argv)

    sys.stdout = old_out
    sys.stderr = old_err

    if argv:
        print("Unparsed arguments present:\n{0}".format(argv))
        parser.print_help()
        print_query_parser_help()
        exit(1)

    filteroptions = FilterOptions(options.architecture, options.realtime, options.largeframe,
            options.largeframe_dma, options.default_priority, options.default_max_priority,
            options.default_affinity, options.default_period, options.default_budget,
            options.default_data, options.default_size_bits,
            options.debug_fault_handlers, options.fprovide_tcb_caps)

    # Check that verification_base_name would be a valid identifer before
    # our templates try to use it
    if options.verification_base_name is not None:
        if not re.match(r'[a-zA-Z][a-zA-Z0-9_]*$', options.verification_base_name):
            parser.error('Not a valid identifer for --verification-base-name: %r' %
                         options.verification_base_name)

    return options, queries, filteroptions

def parse_file_cached(filename, parser_options):
    if parser_options.load_ast is not None:
        return pickle.load(parser_options.load_ast)
    ast,read = parse_file(filename, parser_options)
    if parser_options.save_ast is not None:
        pickle.dump((ast,read),parser_options.save_ast)
    return ast,read

def rendering_error(item, exn):
    '''Helper to format an error message for template rendering errors.'''
    tb = safe_decode(traceback.format_tb(sys.exc_info()[2]))
    return (['While rendering %s: %s' % (item, line) for line in exn.args] +
            ''.join(tb).splitlines())

def main(argv, out, err):

    # We need a UTF-8 locale, so bail out if we don't have one. More
    # specifically, things like the version() computation traverse the file
    # system and, if they hit a UTF-8 filename, they try to decode it into your
    # preferred encoding and trigger an exception.
    encoding = locale.getpreferredencoding().lower()
    if encoding not in ('utf-8', 'utf8'):
        err.write('CAmkES uses UTF-8 encoding, but your locale\'s preferred '
            'encoding is %s. You can override your locale with the LANG '
            'environment variable.\n' % encoding)
        return -1

    options, queries, filteroptions = parse_args(argv, out, err)

    # Ensure we were supplied equal items and outfiles
    if len(options.outfile) != len(options.item):
        err.write('Different number of items and outfiles. Required one outfile location '
            'per item requested.\n')
        return -1

    # No duplicates in items or outfiles
    if len(set(options.item)) != len(options.item):
        err.write('Duplicate items requested through --item.\n')
        return -1
    if len(set(options.outfile)) != len(options.outfile):
        err.write('Duplicate outfiles requrested through --outfile.\n')
        return -1

    # Save us having to pass debugging everywhere.
    die = functools.partial(_die, options)

    log.set_verbosity(options.verbosity)

    cwd = os.getcwd()

    # Build a list of item/outfile pairs that we have yet to match and process
    all_items = set(zip(options.item, options.outfile))
    done_items = set([])

    def done(s, file, item):
        ret = 0
        if s:
            file.write(s)
            file.close()

        done_items.add((item, file))
        if len(all_items - done_items) == 0:
            if options.save_object_state is not None:
                # Write the render_state to the supplied outfile
                pickle.dump(renderoptions.render_state, options.save_object_state)

            sys.exit(ret)

    filename = None
    if options.file is not None:
        filename = os.path.abspath(options.file.name)

    try:
        # Build the parser options
        parse_options = ParserOptions(options.cpp, options.cpp_flag, options.import_path, options.verbosity, options.allow_forward_references,options.save_ast,options.load_ast, queries)
        ast, read = parse_file_cached(filename, parse_options)
    except (ASTError, ParseError) as e:
        die(e.args)

    # Locate the assembly.
    assembly = ast.assembly
    if assembly is None:
        die('No assembly found')


    # Do some extra checks if the user asked for verbose output.
    if options.verbosity >= 2:

        # Try to catch type mismatches in attribute settings. Note that it is
        # not possible to conclusively evaluate type correctness because the
        # attributes' type system is (deliberately) too loose. That is, the
        # type of an attribute can be an uninterpreted C type the user will
        # provide post hoc.
        for i in assembly.composition.instances:
            for a in i.type.attributes:
                value = assembly.configuration[i.name].get(a.name)
                if value is not None:
                    if a.type == 'string' and not \
                            isinstance(value, six.string_types):
                        log.warning('attribute %s.%s has type string but is '
                            'set to a value that is not a string' % (i.name,
                            a.name))
                    elif a.type == 'int' and not \
                            isinstance(value, numbers.Number):
                        log.warning('attribute %s.%s has type int but is set '
                            'to a value that is not an integer' % (i.name,
                                a.name))
    obj_space = ObjectAllocator()
    obj_space.spec.arch = options.architecture
    render_state = RenderState(obj_space=obj_space)

    templates = Templates(options.platform)
    [templates.add_root(t) for t in options.templates]
    try:
        r = Renderer(templates, options.cache, options.cache_dir)
    except jinja2.exceptions.TemplateSyntaxError as e:
        die('template syntax error: %s' % e)

    # The user may have provided their own connector definitions (with
    # associated) templates, in which case they won't be in the built-in lookup
    # dictionary. Let's add them now. Note, definitions here that conflict with
    # existing lookup entries will overwrite the existing entries. Note that
    # the extra check that the connector has some templates is just an
    # optimisation; the templates module handles connectors without templates
    # just fine.
    extra_templates = set()
    for c in (x for x in ast.items if isinstance(x, Connector) and
            (x.from_template is not None or x.to_template is not None)):
        try:
            # Find a connection that uses this type.
            connection = next(x for x in ast if isinstance(x, Connection) and
                x.type == c)
            # Add the custom templates and update our collection of read
            # inputs. It is necessary to update the read set here to avoid
            # false compilation cache hits when the source of a custom template
            # has changed.
            extra_templates |= templates.add(c, connection)
        except TemplateError as e:
            die('while adding connector %s: %s' % (c.name, e))
        except StopIteration:
            # No connections use this type. There's no point adding it to the
            # template lookup dictionary.
            pass

    # Check if our current target is in the level B cache. The level A cache
    # will 'miss' and this one will 'hit' when the input spec is identical to
    # some previously observed execution modulo a semantically irrelevant
    # element (e.g. an introduced comment).
    ast_hash = None

    # Add custom templates.
    read |= extra_templates

    # Add the CAmkES sources themselves to the accumulated list of inputs.
    read |= set(path for path, _ in sources())

    # Add any ELF files we were passed as inputs.
    read |= set(options.elf)

    # Write a Makefile dependency rule if requested.
    if filename and options.makefile_dependencies is not None:
        options.makefile_dependencies.write('%s: \\\n  %s\n' %
            (filename, ' \\\n  '.join(sorted(read))))

    def apply_capdl_filters(renderoptions):
        # Derive a set of usable ELF objects from the filenames we were passed.
        render_state = renderoptions.render_state
        elfs = {}
        for e in options.elf:
            try:
                name = os.path.basename(e)
                if name in elfs:
                    raise Exception('duplicate ELF files of name \'%s\' encountered' % name)
                elf = ELF(e, name, options.architecture)
                p = Perspective(phase=RUNNER, elf_name=name)
                group = p['group']
                # Avoid inferring a TCB as we've already created our own.
                elf_spec = elf.get_spec(infer_tcb=False, infer_asid=False,
                    pd=render_state.pds[group], use_large_frames=options.largeframe,
                    addr_space=render_state.addr_spaces[group])
                render_state.obj_space.merge(elf_spec, label=group)
                elfs[name] = (e, elf)
            except Exception as inst:
                die('While opening \'%s\': %s' % (e, inst))

        for f in CAPDL_FILTERS:
            try:
                # Pass everything as named arguments to allow filters to
                # easily ignore what they don't want.
                f(ast=ast,
                  obj_space=render_state.obj_space,
                  cspaces=render_state.cspaces,
                  elfs=elfs,
                  options=filteroptions)
            except Exception as inst:
                die('While forming CapDL spec: %s' % inst)

    renderoptions = RenderOptions(options.file, options.verbosity, options.frpc_lock_elision,
        options.fspecialise_syscall_stubs, options.fprovide_tcb_caps, options.fsupport_init,
        options.largeframe, options.largeframe_dma, options.architecture, options.debug_fault_handlers,
        options.default_stack_size, options.realtime,
        options.verification_base_name, filteroptions, render_state)

    def instantiate_misc_templates(renderoptions):
        for (item, outfile) in (all_items - done_items):
            try:
                template = templates.lookup(item)
                if template:
                    g = r.render(
                        assembly, assembly, template, renderoptions.render_state, None,
                        outfile_name=outfile.name, imported=read, options=renderoptions)
                    done(g, outfile, item)
            except TemplateError as inst:
                die(rendering_error(item, inst))

    if "camkes-gen.cmake" in options.item:
        instantiate_misc_templates(renderoptions)

    if options.load_object_state is not None:
        # There is an assumption that if load_object_state is set, we
        # skip all of the component and connector logic below.
        # FIXME: refactor to clarify control flow
        renderoptions.render_state = pickle.load(options.load_object_state)
        apply_capdl_filters(renderoptions)
        instantiate_misc_templates(renderoptions)

        # If a template wasn't instantiated, something went wrong, and we can't recover
        raise CAmkESError("No template instantiated on capdl generation path")

    # We're now ready to instantiate the template the user requested, but there
    # are a few wrinkles in the process. Namely,
    #  1. Template instantiation needs to be done in a deterministic order. The
    #     runner is invoked multiple times and template code needs to be
    #     allocated identical cap slots in each run.
    #  2. Components and connections need to be instantiated before any other
    #     templates, regardless of whether they are the ones we are after. Some
    #     other templates, such as the Makefile depend on the obj_space and
    #     cspaces.
    #  3. All actual code templates, up to the template that was requested,
    #     need to be instantiated. This is related to (1) in that the cap slots
    #     allocated are dependent on what allocations have been done prior to a
    #     given allocation call.

    # Instantiate the per-component source and header files.
    for i in assembly.composition.instances:
        # Don't generate any code for hardware components.
        if i.type.hardware:
            continue

        if i.address_space not in renderoptions.render_state.cspaces:
            p = Perspective(phase=RUNNER, instance=i.name,
                group=i.address_space)
            cnode = renderoptions.render_state.obj_space.alloc(ObjectType.seL4_CapTableObject,
                name=p['cnode'], label=i.address_space)
            renderoptions.render_state.cspaces[i.address_space] = CSpaceAllocator(cnode)
            pd = obj_space.alloc(lookup_architecture(options.architecture).vspace().object, name=p['pd'],
                label=i.address_space)
            addr_space = AddressSpaceAllocator(re.sub(r'[^A-Za-z0-9]', '_', p['elf_name']), pd)
            renderoptions.render_state.pds[i.address_space] = pd
            renderoptions.render_state.addr_spaces[i.address_space] = addr_space

        for t in ('%s/source' % i.name, '%s/header' % i.name,
                '%s/c_environment_source' % i.name,
                '%s/cakeml_start_source' % i.name, '%s/cakeml_end_source' % i.name,
                '%s/linker' % i.name):
            try:
                template = templates.lookup(t, i)
                g = ''
                if template:
                    g = r.render(i, assembly, template, renderoptions.render_state, i.address_space,
                        outfile_name=None, options=renderoptions, my_pd=renderoptions.render_state.pds[i.address_space])
                for (item, outfile) in (all_items - done_items):
                    if item == t:
                        if not template:
                            log.warning('Warning: no template for %s' % item)
                        done(g, outfile, item)
                        break
            except TemplateError as inst:
                die(rendering_error(i.name, inst))

    # Instantiate the per-connection files.
    for c in assembly.composition.connections:

        for t in (('%s/from/source' % c.name, c.from_ends),
                  ('%s/from/header' % c.name, c.from_ends),
                  ('%s/to/source' % c.name, c.to_ends),
                  ('%s/to/header' % c.name, c.to_ends),
                  ('%s/to/cakeml' % c.name, c.to_ends)):

            template = templates.lookup(t[0], c)

            if template is not None:
                for id, e in enumerate(t[1]):
                    item = '%s/%d' % (t[0], id)
                    g = ''
                    try:
                        g = r.render(e, assembly, template, renderoptions.render_state,
                            e.instance.address_space, outfile_name=None,
                            options=renderoptions, my_pd=renderoptions.render_state.pds[e.instance.address_space])
                    except TemplateError as inst:
                        die(rendering_error(item, inst))
                    except jinja2.exceptions.TemplateNotFound:
                        die('While rendering %s: missing template for %s' %
                            (item, c.type.name))
                    for (target, outfile) in (all_items - done_items):
                        if target == item:
                            if not template:
                                log.warning('Warning: no template for %s' % item)
                            done(g, outfile, item)
                            break

        # The following block handles instantiations of per-connection
        # templates that are neither a 'source' or a 'header', as handled
        # above. We assume that none of these need instantiation unless we are
        # actually currently looking for them (== options.item). That is, we
        # assume that following templates, like the CapDL spec, do not require
        # these templates to be rendered prior to themselves.
        # FIXME: This is a pretty ugly way of handling this. It would be nicer
        # for the runner to have a more general notion of per-'thing' templates
        # where the per-component templates, the per-connection template loop
        # above, and this loop could all be done in a single unified control
        # flow.
        for (item, outfile) in (all_items - done_items):
            for t in (('%s/from/' % c.name, c.from_ends),
                    ('%s/to/' % c.name, c.to_ends)):

                if not item.startswith(t[0]):
                    # This is not the item we're looking for.
                    continue

                # If we've reached here then this is the exact item we're after.
                template = templates.lookup(item, c)
                if template is None:
                    die('no registered template for %s' % item)

                for e in t[1]:
                    try:
                        g = r.render(e, assembly, template, renderoptions.render_state,
                            e.instance.address_space, outfile_name=None,
                            options=renderoptions, my_pd=renderoptions.render_state.pds[e.instance.address_space])
                        done(g, outfile, item)
                    except TemplateError as inst:
                        die(rendering_error(item, inst))

    # Perform any per component special generation. This needs to happen last
    # as these template needs to run after all other capabilities have been
    # allocated
    for i in assembly.composition.instances:
        # Don't generate any code for hardware components.
        if i.type.hardware:
            continue
        assert i.address_space in renderoptions.render_state.cspaces
        SPECIAL_TEMPLATES = [('debug', 'debug'), ('simple', 'simple'), ('rump_config', 'rumprun')]
        for special in [bl for bl in SPECIAL_TEMPLATES if assembly.configuration[i.name].get(bl[0])]:
            for t in ('%s/%s' % (i.name, special[1]),):
                try:
                    template = templates.lookup(t, i)
                    g = ''
                    if template:
                        g = r.render(i, assembly, template, renderoptions.render_state,
                            i.address_space, outfile_name=None,
                            options=renderoptions, my_pd=renderoptions.render_state.pds[i.address_space])
                    for (item, outfile) in (all_items - done_items):
                        if item == t:
                            if not template:
                                log.warning('Warning: no template for %s' % item)
                            done(g, outfile, item)
                except TemplateError as inst:
                    die(rendering_error(i.name, inst))

    # Check if there are any remaining items
    not_done = all_items - done_items
    if len(not_done) > 0:
        for (item, outfile) in not_done:
            err.write('No valid element matching --item %s.\n' % item)
        return -1
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv, sys.stdout, sys.stderr))
