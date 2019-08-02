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

from __future__ import absolute_import, division, print_function, \
    unicode_literals
from camkes.internal.seven import cmp, filter, map, zip

from camkes.internal.exception import CAmkESError
import six

class ParseError(CAmkESError):
    def __init__(self, content, location=None, filename=None, lineno=None):
        assert isinstance(content, six.string_types) or isinstance(content, Exception)
        if location is not None:
            filename = location.filename
            lineno = location.lineno
            min_col = location.min_col
            max_col = location.max_col
        else:
            min_col = None
            max_col = None
        msg = self._format_message(six.text_type(content), filename, lineno,
            min_col, max_col)
        super(ParseError, self).__init__(msg)

class OutcallError(ParseError):
    def __init__(self, content, location=None, filename=None, lineno=None):
        # Allow other embedded syntaxes to have more full featured exceptions.
        super(OutcallError, self).__init__(content, location, filename, lineno)

class DtbBindingError(OutcallError):
    def __init__(self, content):
        # But I personally only care about transmitting a string.
        super(DtbBindingError, self).__init__(content)

class DtbBindingQueryFormatError(DtbBindingError):
    def __init__(self, content):
        super(DtbBindingQueryFormatError, self).__init__(content)

class DtbBindingNodeLookupError(DtbBindingError):
    def __init__(self, content):
        super(DtbBindingNodeLookupError, self).__init__(content)

class DtbBindingSyntaxError(DtbBindingError):
    def __init__(self, content):
        super(DtbBindingSyntaxError, self).__init__(content)

class DtbBindingTypeError(TypeError, DtbBindingError):
    def __init__(self, content):
        super(DtbBindingTypeError, self).__init__(content)

class DtbBindingNotImplementedError(NotImplementedError, DtbBindingError):
    def __init__(self, content):
        super(DtbBindingNotImplementedError, self).__init__(content)
