#define CONFIG_KERNEL_MASTER 1
#define CONFIG_ARCH_X86 1
#define CONFIG_ARCH x86
#define CONFIG_ARM_HIKEY_OUTSTANDING_PREFETCHERS 0
#define CONFIG_ARM_HIKEY_PREFETCHER_STRIDE 0
#define CONFIG_ARM_HIKEY_PREFETCHER_NPFSTRM 0
#define CONFIG_SPIKE_CLOCK_FREQ 10000000
#define CONFIG_ARCH_X86_64 1
#define CONFIG_X86_SEL4_ARCH x86_64
#define CONFIG_PLAT pc99
#define CONFIG_PLAT_PC99 1
#define CONFIG_SEL4_ARCH x86_64
#define CONFIG_WORD_SIZE 64
#define CONFIG_ARCH_X86_NEHALEM 1
#define CONFIG_KERNEL_X86_MICRO_ARCH nehalem
#define CONFIG_IRQ_IOAPIC 1
#define CONFIG_KERNEL_IRQ_CONTROLLER IOAPIC
#define CONFIG_MAX_NUM_IOAPIC 1
#define CONFIG_XAPIC 1
#define CONFIG_KERNEL_LAPIC_MODE XAPIC
#define CONFIG_CACHE_LN_SZ 64
#define CONFIG_MAX_VPIDS 0
#define CONFIG_HUGE_PAGE 1
#define CONFIG_SYSCALL 1
#define CONFIG_KERNEL_X86_SYSCALL syscall
#define CONFIG_FXSAVE 1
#define CONFIG_KERNEL_X86_FPU FXSAVE
#define CONFIG_XSAVE_FEATURE_SET 0
#define CONFIG_XSAVE_SIZE 512
#define CONFIG_FSGSBASE_MSR 1
#define CONFIG_KERNEL_FSGS_BASE msr
#define CONFIG_MULTIBOOT_GRAPHICS_MODE_NONE 1
#define CONFIG_KERNEL_MUTLTIBOOT_GFX_MODE none
#define CONFIG_MULTIBOOT1_HEADER 1
#define CONFIG_MULTIBOOT2_HEADER 1
#define CONFIG_KERNEL_SKIM_WINDOW 1
#define CONFIG_KERNEL_X86_IBRS_NONE 1
#define CONFIG_KERNEL_X86_IBRS ibrs_none
#define CONFIG_MAX_RMRR_ENTRIES 1
#define CONFIG_HAVE_FPU 1
#define CONFIG_ROOT_CNODE_SIZE_BITS 17
#define CONFIG_TIMER_TICK_MS 2
#define CONFIG_TIME_SLICE 5
#define CONFIG_RETYPE_FAN_OUT_LIMIT 256
#define CONFIG_MAX_NUM_WORK_UNITS_PER_PREEMPTION 100
#define CONFIG_RESET_CHUNK_BITS 8
#define CONFIG_MAX_NUM_BOOTINFO_UNTYPED_CAPS 230
#define CONFIG_FASTPATH 1
#define CONFIG_NUM_DOMAINS 1
#define CONFIG_NUM_PRIORITIES 256
#define CONFIG_MAX_NUM_NODES 1
#define CONFIG_KERNEL_STACK_BITS 12
#define CONFIG_FPU_MAX_RESTORES_SINCE_SWITCH 64
#define CONFIG_DEBUG_BUILD 1
#define CONFIG_PRINTING 1
#define CONFIG_NO_BENCHMARKS 1
#define CONFIG_KERNEL_BENCHMARK none
#define CONFIG_MAX_NUM_TRACE_POINTS 0
#define CONFIG_IRQ_REPORTING 1
#define CONFIG_COLOUR_PRINTING 1
#define CONFIG_USER_STACK_TRACE_LENGTH 16
#define CONFIG_KERNEL_OPT_LEVEL_O2 1
#define CONFIG_KERNEL_OPT_LEVEL -O2