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

"""
Functionality related to handling ELF file input. This is the only section of
this module that relies on elftools, so it is possible to use this module
without elftools installed by not importing this particular file.
"""
from __future__ import absolute_import, division, print_function, \
    unicode_literals

from elftools.elf.elffile import ELFFile
from elftools.elf.constants import P_FLAGS
from .Object import TCB
from .util import PAGE_SIZE, round_down, page_sizes
from .PageCollection import PageCollection
import os, re, six

def _decode(data):
    '''
    Decode ambiguous data retrieved from an ELF file.

    Depending on the version of Python we are running, we may wind up with
    ascii strings, UTF-8 or byte arrays. Only ASCII data can appear in ELF
    files in places we are expecting text (this is not strictly true, but
    `pyelftools` makes this assumption internally, so we may as well stick to
    that) so we decode any byte array as ASCII.
    '''
    if isinstance(data, bytes):
        return data.decode('ascii')
    return data

class ELF(object):
    def __init__(self, elf, name='', arch=None):
        """
        This constructor is overloaded and can accept either a string as the
        parameter 'elf', or a stream to ELF data. 'name' is only used when
        generating CapDL from the ELF file.
        """
        if isinstance(elf, six.string_types):
            f = open(elf, 'rb')
        else:
            f = elf
        self._elf = ELFFile(f)
        self.name = name
        self._symtab = None
        self.arch = arch or self.get_arch()

    def get_entry_point(self):
        return self._elf['e_entry']

    def _get_symbol(self, symbol):

        # If possible, let elftools do all the work.
        if hasattr(self._elf, 'get_symbol_by_name'):
            # From 46ae4bd this functionality is in elftools.
            sym = self._elf.get_symbol_by_name(symbol)
            if isinstance(sym, list):
                # From 9da4c45 get_symbol_by_name returns a list.
                return sym[0]
            return sym

        if self._symtab is None:
            table = self._elf.get_section_by_name('.symtab')
            if not table:
                # This ELF file has been stripped.
                raise Exception('No symbol table available')
            self._symtab = dict([(s.name, s) for s in table.iter_symbols()])

        return self._symtab.get(symbol)

    def get_symbol_vaddr(self, symbol):
        sym = self._get_symbol(symbol)
        if sym:
            return sym['st_value']
        return None

    def get_symbol_size(self, symbol):
        sym = self._get_symbol(symbol)
        if sym:
            return sym['st_size']
        return None

    def _safe_name(self):
        """
        Replace characters that the CapDL tools parse differently.
        """
        return re.sub(r'[^A-Za-z0-9]', '_', self.name)

    def get_arch(self):
        return self._elf.get_machine_arch()

    def check_alignment(self, regions):
        for (vaddr, sizes, caps) in regions:
            for size in sizes:
                assert vaddr % size == 0, "vaddr: 0x%x is not aligned to frame_size: 0x%x" %(vaddr, size)
                vaddr += size

    def regions_in_segment(self, segment, regions):
        seg_start = segment['p_vaddr']
        seg_size = segment['p_memsz']
        seg_end = seg_start + seg_size
        regions_return = []
        for (vaddr, sizes, caps) in regions:
            for size in sizes:
                if vaddr >= (seg_end) or (vaddr+size) < seg_start:
                    pass
                else:
                    assert vaddr >= seg_start and (vaddr + size) <= seg_end, "Regions overlap segments which is not allowed"
                    regions_return.append((vaddr, size))
                vaddr += size
        return regions_return

    def get_pages(self, infer_asid=True, pd=None, use_large_frames=True, addr_space=None):
        """
        Returns a dictionary of pages keyed on base virtual address, that are
        required to ELF load this file. Each dictionary entry is a dictionary
        containing booleans 'read', 'write' and 'execute' for the permissions
        of the page.
        """
        pages = PageCollection(self._safe_name(), self.arch, infer_asid, pd)

        # We assume that this array contains aligned vaddrs and sizes that are frame sizes
        existing_pages = []
        if addr_space:
            # Update symbols with their vaddrs in the AddressSpaceAllocator if we were given one
            existing_pages = [(self.get_symbol_vaddr(symbol), sizes, caps)
                 for (symbol, (sizes, caps)) in addr_space.get_symbols_and_clear().iteritems()]
            self.check_alignment(existing_pages)
            for (vaddr, sizes, caps) in existing_pages:
                addr_space.add_region_with_caps(vaddr, sizes, caps)

        for seg in self._elf.iter_segments():
            if not seg['p_type'] == 'PT_LOAD':
                continue
            if seg['p_memsz'] == 0:
                continue

            regions = [{'addr': seg['p_vaddr'],
                        'size': seg['p_memsz'],
                        'type': 0}]
            relevant_regions = self.regions_in_segment(seg, existing_pages)
            for (reg_vaddr, reg_size) in relevant_regions:
                region = [x for x in regions if
                    reg_vaddr >= x['addr'] and reg_vaddr < (x['addr'] + x['size'])]
                assert len(region) == 1, "section is overlapping which is not allowed"
                region = region[0]
                orig_size = region['size']
                # Shrink the region to the range preceding this section.
                region['size'] = reg_vaddr - region['addr']
                # Append a region for this section itself and that following
                # this section.
                regions += [{'addr': reg_vaddr,
                             'size': reg_size,
                             'type': 1},
                            {'addr': reg_vaddr + reg_size,
                             'size': orig_size - region['size'] - reg_size,
                             'type': 0}]
            # Remove empty regions.
            regions[:] = [x for x in regions if x['size'] != 0]

            r = (seg['p_flags'] & P_FLAGS.PF_R) > 0
            w = (seg['p_flags'] & P_FLAGS.PF_W) > 0
            x = (seg['p_flags'] & P_FLAGS.PF_X) > 0

            # Allocate pages
            for reg in regions:
                if reg['type']:
                    vaddr = reg['addr']
                    pages.add_page(vaddr, r, w, x, reg['size'])
                else:
                    # A range that is eligible for promotion.
                    possible_pages = list(reversed(page_sizes(self.arch)))
                    vaddr = round_down(reg['addr'])
                    remain = reg['addr'] + reg['size'] - vaddr
                    while vaddr < reg['addr'] + reg['size']:
                        size = PAGE_SIZE
                        if use_large_frames:
                            for p in possible_pages:
                                if remain >= p and vaddr % p == 0:
                                    size = p
                                    break
                        pages.add_page(vaddr, r, w, x, size)
                        vaddr += size
                        remain -= size

        return pages

    def get_spec(self, infer_tcb=True, infer_asid=True, pd=None,
            use_large_frames=True, addr_space=None):
        """
        Return a CapDL spec with as much information as can be derived from the
        ELF file in isolation.
        """
        pages = self.get_pages(infer_asid, pd, use_large_frames, addr_space=addr_space)
        spec = pages.get_spec(addr_space.get_regions_and_clear() if addr_space else {})

        if infer_tcb:
            # Create a single TCB.
            tcb = TCB('tcb_%s' % self._safe_name(), ip=self.get_entry_point(),
                elf=self.name)
            spec.add_object(tcb)
            tcb['vspace'] = pages.get_vspace_root()[1]

        return spec

    def __repr__(self):
        return str(self._elf)
