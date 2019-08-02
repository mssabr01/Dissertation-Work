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

cmake_minimum_required(VERSION 3.8.2)

include("${CMAKE_CURRENT_LIST_DIR}/helpers/application_settings.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers/cakeml.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers/cross_compiling.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers/external-project-helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers/rust.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/helpers/dts.cmake")

set(COMMON_HELPER_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Helper function for modifying the linker flags of a target to set the entry point as _sel4_start
function(SetSeL4Start target)
    set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS " -u _sel4_start -e _sel4_start ")
endfunction(SetSeL4Start)

if(KernelSel4ArchIA32)
    set(LinkOFormat "elf32-i386")
elseif(KernelSel4ArchX86_64)
    set(LinkOFormat "elf64-x86-64")
elseif(KernelSel4ArchAarch32 OR KernelSel4ArchArmHyp)
    set(LinkOFormat "elf32-littlearm")
elseif(KernelSel4ArchAarch64)
    set(LinkOFormat "elf64-littleaarch64")
elseif(KernelSel4ArchRiscV32)
    set(LinkOFormat "elf32-littleriscv")
elseif(KernelSel4ArchRiscV64)
    set(LinkOFormat "elf64-littleriscv")
endif()

# Checks the existence of an argument to cpio -o.
# flag refers to a variable in the parent scope that contains the argument, if
# the argument isn't supported then the flag is set to the empty string in the parent scope.
function(CheckCPIOArgument flag)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/cpio-testfile "Testfile contents")
    execute_process(COMMAND bash -c "echo cpio-testfile | cpio ${${flag}} -o"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_QUIET
        ERROR_QUIET
        RESULT_VARIABLE result)
    if(result)
        set(${flag} "" PARENT_SCOPE)
    endif()
    file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/cpio-testfile)
endfunction()

# Function for declaring rules to build a cpio archive that can be linked
# into another target
function(MakeCPIO output_name input_files)
    cmake_parse_arguments(PARSE_ARGV 2 MAKE_CPIO "" "CPIO_SYMBOL" "DEPENDS")
    if (NOT "${MAKE_CPIO_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to MakeCPIO")
    endif()
    set(archive_symbol "_cpio_archive")
    if (NOT "${MAKE_CPIO_CPIO_SYMBOL}" STREQUAL "")
        set(archive_symbol ${MAKE_CPIO_CPIO_SYMBOL})
    endif()
    # Check that the reproducible flag is available. Don't use it if it isn't.
    set(reproducible_flag "--reproducible")
    CheckCPIOArgument(reproducible_flag)
    set(append "")
    foreach(file IN LISTS input_files)
        # Try and generate reproducible cpio meta-data as we do this:
        # - touch -d @0 file sets the modified time to 0
        # - --owner=root:root sets user and group values to 0:0
        # - --reproducible creates reproducible archives with consistent inodes and device numbering
        list(APPEND commands
            "bash;-c;cd `dirname ${file}` && mkdir -p temp && cd temp && cp -a ${file} . && touch -d @0 `basename ${file}` && echo `basename ${file}` | cpio ${append} ${reproducible_flag} --owner=root:root --quiet -o -H newc --file=${CMAKE_CURRENT_BINARY_DIR}/archive.${output_name}.cpio && rm `basename ${file}` && cd ../ && rmdir temp;&&"
        )
        set(append "--append")
    endforeach()
    list(APPEND commands "true")

    # RiscV doesn't support linking with -r
    set(relocate "-r")
    if(KernelArchRiscV)
        set(relocate "")
    endif()
    add_custom_command(OUTPUT ${output_name}
        COMMAND rm -f archive.${output_name}.cpio
        COMMAND ${commands}
        COMMAND echo "SECTIONS { ._archive_cpio : ALIGN(4) { ${archive_symbol} = . ; *(.*) ; ${archive_symbol}_end = . ; } }"
            > link.${output_name}.ld
        COMMAND ${CROSS_COMPILER_PREFIX}ld -T link.${output_name}.ld --oformat ${LinkOFormat} ${relocate} -b binary archive.${output_name}.cpio -o ${output_name}
        BYPRODUCTS archive.${output_name}.cpio link.${output_name}.ld
        DEPENDS ${input_files} ${MAKE_CPIO_DEPENDS}
        VERBATIM
        COMMENT "Generate CPIO archive ${output_name}"
    )
endfunction(MakeCPIO)

# We need to the real non symlinked list path in order to find the linker script that is in
# the common-tool directory
get_filename_component(real_list "${CMAKE_CURRENT_LIST_DIR}" REALPATH)

function(DeclareRootserver rootservername)
    SetSeL4Start(${rootservername})
    set_property(TARGET ${rootservername} APPEND_STRING PROPERTY LINK_FLAGS " -T ${real_list}/tls_rootserver.lds ")
    if("${KernelArch}" STREQUAL "x86")
        set(IMAGE_NAME "${CMAKE_BINARY_DIR}/images/${rootservername}-image-${KernelSel4Arch}-${KernelPlatform}")
        set(KERNEL_IMAGE_NAME "${CMAKE_BINARY_DIR}/images/kernel-${KernelSel4Arch}-${KernelPlatform}")
        # Declare targets for building the final kernel image
        if(Kernel64)
            add_custom_command(
                OUTPUT "${KERNEL_IMAGE_NAME}"
                COMMAND ${CROSS_COMPILER_PREFIX}objcopy -O elf32-i386 $<TARGET_FILE:kernel.elf> "${KERNEL_IMAGE_NAME}"
                VERBATIM
                DEPENDS kernel.elf
                COMMENT "objcopy kernel into bootable elf"
            )
        else()
            add_custom_command(
                OUTPUT "${KERNEL_IMAGE_NAME}"
                COMMAND cp $<TARGET_FILE:kernel.elf> "${KERNEL_IMAGE_NAME}"
                VERBATIM
                DEPENDS kernel.elf
            )
        endif()
        add_custom_command(OUTPUT "${IMAGE_NAME}"
            COMMAND cp $<TARGET_FILE:${rootservername}> "${IMAGE_NAME}"
            DEPENDS ${rootservername}
        )
        add_custom_target(rootserver_image ALL DEPENDS "${IMAGE_NAME}" "${KERNEL_IMAGE_NAME}" kernel.elf $<TARGET_FILE:${rootservername}> ${rootservername})
    elseif("${KernelArch}" STREQUAL "arm")
        set(IMAGE_NAME "${CMAKE_BINARY_DIR}/images/${rootservername}-image-arm-${KernelPlatform}")
        set(binary_efi_list "binary;efi")
        if(${ElfloaderImage} IN_LIST binary_efi_list)
            # If not an elf we construct an intermediate rule to do an objcopy to binary
            add_custom_command(OUTPUT "${IMAGE_NAME}"
                COMMAND ${CROSS_COMPILER_PREFIX}objcopy -O binary $<TARGET_FILE:elfloader> "${IMAGE_NAME}"
                DEPENDS $<TARGET_FILE:elfloader> elfloader
            )
        elseif("${ElfloaderImage}" STREQUAL "uimage")
            # Add custom command for converting to uboot image
            add_custom_command(OUTPUT "${IMAGE_NAME}"
            COMMAND mkimage  -A arm64 -O qnx -T kernel -C none -a $<TARGET_PROPERTY:elfloader,PlatformEntryAddr> -e $<TARGET_PROPERTY:elfloader,PlatformEntryAddr> -d $<TARGET_FILE:elfloader> "${IMAGE_NAME}"
            DEPENDS $<TARGET_FILE:elfloader> elfloader
            )
        else()
            add_custom_command(OUTPUT "${IMAGE_NAME}"
                COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:elfloader> "${IMAGE_NAME}"
                DEPENDS $<TARGET_FILE:elfloader> elfloader
            )
        endif()
        add_custom_target(rootserver_image ALL DEPENDS "${IMAGE_NAME}" elfloader ${rootservername})
        # Set the output name for the rootserver instead of leaving it to the generator. We need
        # to do this so that we can put the rootserver image name as a property and have the
        # elfloader pull it out using a generator expression, since generator expression cannot
        # nest (i.e. in the expansion of $<TARGET_FILE:tgt> 'tgt' cannot itself be a generator
        # expression. Nor can a generator expression expand to another generator expression and
        # get expanded again. As a result we just fix the output name and location of the rootserver
        set_property(TARGET "${rootservername}" PROPERTY OUTPUT_NAME "${rootservername}")
        get_property(rootimage TARGET "${rootservername}" PROPERTY OUTPUT_NAME)
        get_property(dir TARGET "${rootservername}" PROPERTY BINARY_DIR)
        set_property(TARGET rootserver_image PROPERTY ROOTSERVER_IMAGE "${dir}/${rootimage}")
    elseif(KernelArchRiscV)
        set(IMAGE_NAME "${CMAKE_BINARY_DIR}/images/${rootservername}-image-riscv-${KernelPlatform}")
        # On RISC-V we need to package up our final elf image into the Berkeley boot loader
        # which is what the following custom command is achieving

        # TODO: Currently we do not support native RISC-V builds, because there
        # is no native environment to test this. Thus CROSS_COMPILER_PREFIX is
        # always set and the BBL build below uses it to create the the
        # "--host=..." parameter. For now, make the build fail if
        # CROSS_COMPILER_PREFIX if not set. It seems that native builds can
        # simply omit the host parameter.
        if("${CROSS_COMPILER_PREFIX}" STREQUAL "")
            message(FATAL_ERROR "CROSS_COMPILER_PREFIX not set.")
        endif()

        # Get host string which is our cross compiler minus the trailing '-'
        string(REGEX REPLACE "^(.*)-$" "\\1" host ${CROSS_COMPILER_PREFIX})
        add_custom_command(OUTPUT "${IMAGE_NAME}"
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/bbl
            COMMAND cd ${CMAKE_BINARY_DIR}/bbl &&
                    ${BBL_PATH}/configure --quiet
                    --host=${host}
                    --with-payload=$<TARGET_FILE:elfloader> &&
                    make -s clean && make -s > /dev/null
            COMMAND cp ${CMAKE_BINARY_DIR}/bbl/bbl ${IMAGE_NAME}
            DEPENDS $<TARGET_FILE:elfloader> elfloader
            )
        add_custom_target(rootserver_image ALL DEPENDS "${IMAGE_NAME}" elfloader ${rootservername})
        set_property(TARGET "${rootservername}" PROPERTY OUTPUT_NAME "${rootservername}")
        get_property(rootimage TARGET "${rootservername}" PROPERTY OUTPUT_NAME)
        get_property(dir TARGET "${rootservername}" PROPERTY BINARY_DIR)
        set_property(TARGET rootserver_image PROPERTY ROOTSERVER_IMAGE "${dir}/${rootimage}")
    else()
        message(FATAL_ERROR "Unsupported architecture.")
    endif()
    # Store the image and kernel image as properties
    # We use relative paths to the build directory
    file(RELATIVE_PATH IMAGE_NAME_REL ${CMAKE_BINARY_DIR} ${IMAGE_NAME})
    if (NOT "${KERNEL_IMAGE_NAME}" STREQUAL "")
        file(RELATIVE_PATH KERNEL_IMAGE_NAME_REL ${CMAKE_BINARY_DIR} ${KERNEL_IMAGE_NAME})
    endif()
    set_property(TARGET rootserver_image PROPERTY IMAGE_NAME "${IMAGE_NAME_REL}")
    set_property(TARGET rootserver_image PROPERTY KERNEL_IMAGE_NAME "${KERNEL_IMAGE_NAME_REL}")
endfunction(DeclareRootserver)

# Help macro for testing a config and appending to a list that is destined for a qemu -cpu line
macro(TestQemuCPUFeature config feature string)
    if(${config})
        set(${string} "${${string}},+${feature}")
    else()
        set(${string} "${${string}},-${feature}")
    endif()
endmacro(TestQemuCPUFeature)

# Function for the user for configuration the simulation script. Valid values for property are
#  'GRAPHIC' if set to TRUE disables the -nographic flag
#  'MEM_SIZE' if set will override the memory size given to qemu
function(SetSimulationScriptProperty property value)
    # define the target if it doesn't already exist
    if(NOT (TARGET simulation_script_prop_target))
        add_custom_target(simulation_script_prop_target)
    endif()
    set_property(TARGET simulation_script_prop_target PROPERTY "${property}" "${value}")
endfunction(SetSimulationScriptProperty)

macro(SetDefaultMemSize default)
    set(QemuMemSize "$<IF:$<BOOL:$<TARGET_PROPERTY:simulation_script_prop_target,MEM_SIZE>>,$<TARGET_PROPERTY:simulation_script_prop_target,MEM_SIZE>,${default}>")
endmacro(SetDefaultMemSize)

# Helper function that generates targets that will attempt to generate a ./simulate style script
function(GenerateSimulateScript)
    set(error "")
    set(KERNEL_IMAGE_NAME "$<TARGET_PROPERTY:rootserver_image,KERNEL_IMAGE_NAME>")
    set(IMAGE_NAME "$<TARGET_PROPERTY:rootserver_image,IMAGE_NAME>")
    # Define simulation script target if it doesn't exist to simplify the generator expressions
    if(NOT (TARGET simulation_script_prop_target))
        add_custom_target(simulation_script_prop_target)
    endif()
    set(sim_graphic_opt "$<IF:$<BOOL:$<TARGET_PROPERTY:simulation_script_prop_target,GRAPHIC>>,,-nographic>")
    set(sim_serial_opt "")
    set(sim_cpu "")
    set(sim_cpu_opt "")
    set(sim_machine "")
    if(KernelArchX86)
        # Try and simulate the correct micro architecture and features
        if(KernelX86MicroArchNehalem)
            set(sim_cpu "Nehalem")
        elseif(KernelX86MicroArchGeneric)
            set(sim_cpu "qemu64")
        elseif(KernelX86MicroArchWestmere)
            set(sim_cpu "Westmere")
        elseif(KernelX86MicroArchSandy)
            set(sim_cpu "SandyBridge")
        elseif(KernelX86MicroArchIvy)
            set(sim_cpu "IvyBridge")
        elseif(KernelX86MicroArchHaswell)
            set(sim_cpu "Haswell")
        elseif(KernelX86MicroArchBroadwell)
            set(sim_cpu "Broadwell")
        else()
            set(error "Unknown x86 micro-architecture for simulation")
        endif()
        TestQemuCPUFeature(KernelVTX vme sim_cpu_opt)
        TestQemuCPUFeature(KernelHugePage pdpe1gb sim_cpu_opt)
        TestQemuCPUFeature(KernelFPUXSave xsave sim_cpu_opt)
        TestQemuCPUFeature(KernelXSaveXSaveOpt xsaveopt sim_cpu_opt)
        TestQemuCPUFeature(KernelXSaveXSaveC xsavec sim_cpu_opt)
        TestQemuCPUFeature(KernelFSGSBaseInst fsgsbase sim_cpu_opt)
        TestQemuCPUFeature(KernelSupportPCID invpcid sim_cpu_opt)
        set(sim_cpu "${sim_cpu}")
        set(sim_cpu_opt "${sim_cpu_opt},enforce")
        set(QemuBinaryMachine "qemu-system-x86_64")
        set(sim_serial_opt "-serial mon:stdio")
        SetDefaultMemSize("512M")
    elseif(KernelPlatformKZM)
        set(QemuBinaryMachine "qemu-system-arm")
        set(sim_machine "kzm")
        SetDefaultMemSize("128M")
    elseif(KernelPlatformSabre)
        set(QemuBinaryMachine "qemu-system-arm")
        set(sim_serial_opt "-s -serial null -serial mon:stdio")
        set(sim_machine "sabrelite")
        SetDefaultMemSize("1024M")
    elseif(KernelPlatformZynq7000)
        set(QemuBinaryMachine "qemu-system-arm")
        set(sim_serial_opt "-s -serial null -serial mon:stdio")
        set(sim_machine "xilinx-zynq-a9")
        SetDefaultMemSize("1024M")
    elseif(KernelPlatformWandQ)
        set(QemuBinaryMachine "qemu-system-arm")
        set(sim_serial_opt "-s -serial mon:stdio")
        set(sim_machine "sabrelite")
        SetDefaultMemSize("2048M")
    elseif(KernelPlatformRpi3 AND KernelSel4ArchAarch64)
        set(QemuBinaryMachine "qemu-system-aarch64")
        set(sim_serial_opt "-s -serial null -serial mon:stdio")
        set(sim_machine "raspi3")
        SetDefaultMemSize("1024M")
    elseif(KernelPlatformSpike)
        if (KernelSel4ArchRiscV32)
            set(binary "qemu-system-riscv32")
            SetDefaultMemSize("2000M")
        elseif(KernelSel4ArchRiscV64)
            set(binary "qemu-system-riscv64")
            SetDefaultMemSize("4095M")
        endif()
        set(QemuBinaryMachine "${binary}")
        set(sim_machine "spike_v1.10")
        set(sim_serial_opt "-s -serial mon:stdio")
    else()
        set(error "Unsupported platform or architecture for simulation")
    endif()
    set(sim_path "${CMAKE_BINARY_DIR}/simulate")
    if (NOT "${error}" STREQUAL "")
        set(script "#!/bin/sh\\necho ${error} && exit -1")
        add_custom_command(OUTPUT "${sim_path}"
            COMMAND echo "${script}" > "${sim_path}"
            COMMAND chmod u+x "${sim_path}"
            VERBATIM
        )
    else()
        add_custom_command(OUTPUT "${sim_path}"
            COMMAND ${CMAKE_COMMAND} -DCONFIGURE_INPUT_FILE=${COMMON_HELPER_DIR}/simulate_scripts/simulate.py
            -DCONFIGURE_OUTPUT_FILE=${sim_path} -DQEMU_SIM_BINARY=${QemuBinaryMachine} -DQEMU_SIM_CPU=${sim_cpu}
            -DQEMU_SIM_MACHINE=${sim_machine} -DQEMU_SIM_CPU_OPT=${sim_cpu_opt} -DQEMU_SIM_GRAPHIC_OPT=${sim_graphic_opt}
            -DQEMU_SIM_SERIAL_OPT=${sim_serial_opt} -DQEMU_SIM_MEM_SIZE_OPT=${QemuMemSize} -DQEMU_SIM_KERNEL_FILE=${KERNEL_IMAGE_NAME}
            -DQEMU_SIM_INITRD_FILE=${IMAGE_NAME} -P ${COMMON_HELPER_DIR}/helpers/configure_file.cmake
            COMMAND chmod u+x "${sim_path}"
            VERBATIM
            COMMAND_EXPAND_LISTS
        )
    endif()
    add_custom_target(simulate_gen ALL DEPENDS "${sim_path}")
endfunction(GenerateSimulateScript)

# Define function for constructing a target for a library from a legacy build system Makefile
# This is incredibly fragile and rarely works out of the box. Generally needs tweaking or
# can be used as inspiration for rolling your own wrapper
function(AddLegacyLibrary target_name lib_name glob_deps other_deps)
    set(LEGACY_STAGE_DIR "${CMAKE_BINARY_DIR}/stage/${KernelArch}/${KernelPlatform}")
    file(GLOB deps RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" ${glob_deps})

    # Check if our other_deps have any interesting header directories we should use
    # TODO: This should probably use generator expressions and TARGET_PROPERTY to
    # avoid the problem of calling get_property on targets that are not yet defined
    foreach(dep ${other_deps})
        get_property(dep_paths TARGET ${dep} PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
        foreach(dep_path ${dep_paths})
            set(extra_nk_cflags "${extra_nk_cflags} -I${dep_path}")
        endforeach()
    endforeach()
    set(nk_cflags "${CMAKE_C_FLAGS} \
                -I${LEGACY_STAGE_DIR}/include \
                -I${LEGACY_STAGE_DIR}/include/${KernelArch} \
                -I${LEGACY_STAGE_DIR}/include/${KernelPlatform} \
                -I${CMAKE_CURRENT_BINARY_DIR}/stage/include \
                -I${CMAKE_CURRENT_BINARY_DIR}/stage/include/${KernelArch} \
                -I${CMAKE_CURRENT_BINARY_DIR}/stage/include/${KernelPlatform} \
                -I$<JOIN:$<TARGET_PROPERTY:Configuration,INTERFACE_INCLUDE_DIRECTORIES>, -I> \
                ${extra_nk_cflags}"
    )
    if(Kernel64)
        list(APPEND extra_environment "KERNEL_64=y")
    else()
        list(APPEND extra_environment "KERNEL_32=y")
    endif()
    if(CCACHEFOUND)
        set(ccache "ccache")
    endif()

    add_custom_command(
        OUTPUT "${LEGACY_STAGE_DIR}/lib/${lib_name}"
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/stage/placeholder"
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/include/generated/autoconf.h"
        OUTPUT .config
        COMMAND touch "${CMAKE_CURRENT_BINARY_DIR}/stage/placeholder"
        COMMAND cp -a "$<TARGET_PROPERTY:Configuration,INTERFACE_INCLUDE_DIRECTORIES>/autoconf.h" "${CMAKE_CURRENT_BINARY_DIR}/include/generated/autoconf.h"
        COMMAND mkdir -p "${CMAKE_CURRENT_BINARY_DIR}/kbuild/tools"
        COMMAND cp -a "${COMMON_PATH}/../kbuild-tool" "${CMAKE_CURRENT_BINARY_DIR}/kbuild/tools/kbuild"
        # What we want to do is "echo ${LEGACY_CONFIG_ENV} | sed 's/ /\n/g'" but there is a bug in the
        # ninja generator where the \n will create a newline in the output file in the middle of a string
        # thus resulting in a syntax error. Therefore we do a stupid work around to avoid having to write \n
        # in the command string
        COMMAND echo ${LEGACY_CONFIG_ENV} | sh -c "read line; for file in $line; do echo $file; done" > .config
        # NK_CFLAGS and NK_FLAGS (NK_ASFLAGS?) should get set as well
        # also TOOLPREFIX
        COMMAND
            # Setup environment variables
            export NK_CFLAGS=${nk_cflags}
                NK_LDFLAGS=${CMAKE_EXE_LINKER_FLAGS}
                CPPFLAGS=${nk_cflags}
                SEL4_COMMON=${COMMON_PATH}
                ARCH=${KernelArch}
                PLAT=${KernelPlatform}
                TYPE_SUFFIX=${KernelWordSize}
                ${LEGACY_CONFIG_ENV}
                ${extra_environment}
                "TOOLPREFIX=${ccache} ${CROSS_COMPILE_PREFIX}"
                SEL4_ARCH=${KernelSel4Arch} &&
            CFLAGS= LDFLAGS=
            # Invoke make in the binary directory on the Makefile
            make -C "${CMAKE_CURRENT_BINARY_DIR}" -f "${CMAKE_CURRENT_SOURCE_DIR}/Makefile"
                -rR "--include-dir=${CMAKE_CURRENT_BINARY_DIR}/kbuild"
            # Arguments we pass to Make
            "BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            "SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            # Initialize stage as a private stage directory so that we can construct
            # sensible include directory on the final target
            "STAGE_DIR=${CMAKE_CURRENT_BINARY_DIR}/stage"
            # srctree is normally the root directory, but we will put it as the binary directory
            # instead to isolate builds
            "srctree=${CMAKE_CURRENT_BINARY_DIR}"
        COMMAND cp -a "${CMAKE_CURRENT_BINARY_DIR}/stage/lib" "${LEGACY_STAGE_DIR}"
        COMMAND cp -a "${CMAKE_CURRENT_BINARY_DIR}/stage/include" "${LEGACY_STAGE_DIR}"
        DEPENDS ${deps} ${other_deps} Configuration
        VERBATIM
        COMMENT "Invoking legacy compilation for ${target_name}"
    )

    add_custom_target(${target_name}_gen
        DEPENDS "${LEGACY_STAGE_DIR}/lib/${lib_name}" ${other_deps}
    )

    # Pretend that the library we just generated is an 'imported' library
    # This allows us to talk about our customly generated library like it's
    # a first class library target in CMake (well almost)
    add_library(${target_name}_imported STATIC IMPORTED)
    add_dependencies(${target_name}_imported ${target_name}_gen ${other_deps} Configuration)
    set_property(TARGET ${target_name}_imported PROPERTY IMPORTED_LOCATION "${LEGACY_STAGE_DIR}/lib/${lib_name}")

    # Define an interface library for our target. This interface library is needed as we cannot
    # describe include directories on imported libraries. The solution is to have this interface
    # library that describes the include directories, and then describe an 'INTERFACE_LINK_LIBRARY'
    # which is a library that must be linked in when this interface library is used.
    add_library(${target_name} INTERFACE)
    add_dependencies(${target_name} ${target_name}_gen ${other_deps} ${target_name}_imported Configuration)
    set_property(TARGET ${target_name} PROPERTY INTERFACE_LINK_LIBRARIES "${target_name}_imported")
    target_include_directories(${target_name} INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/stage/include")
endfunction(AddLegacyLibrary)
