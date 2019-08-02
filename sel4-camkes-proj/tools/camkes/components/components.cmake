#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

# import all available components
CAmkESAddImportPath(${CMAKE_CURRENT_LIST_DIR})
CAmkESMaybeAddImportPath(${CMAKE_CURRENT_LIST_DIR}/plat/${KernelPlatform})
CAmkESMaybeAddImportPath(${CMAKE_CURRENT_LIST_DIR}/mach/${KernelArmMach})
CAmkESMaybeAddImportPath(${CMAKE_CURRENT_LIST_DIR}/arch/${KernelArch})

if (EXISTS ${CMAKE_CURRENT_LIST_DIR}/plat/${KernelPlatform}/CMakeLists.txt)
include(${CMAKE_CURRENT_LIST_DIR}/plat/${KernelPlatform}/CMakeLists.txt)
endif()
