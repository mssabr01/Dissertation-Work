/*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 */

/* This header was generated by kernel/tools/invocation_header_gen.py.
 *
 * To add an invocation call number, edit libsel4/include/interfaces/sel4.xml.
 *
 */
#ifndef __API_INVOCATION_H
#define __API_INVOCATION_H

enum invocation_label {
    InvalidInvocation,
    UntypedRetype,
    TCBReadRegisters,
    TCBWriteRegisters,
    TCBCopyRegisters,
    TCBConfigure,
    TCBSetPriority,
    TCBSetMCPriority,
    TCBSetSchedParams,
    TCBSetIPCBuffer,
    TCBSetSpace,
    TCBSuspend,
    TCBResume,
    TCBBindNotification,
    TCBUnbindNotification,
#if CONFIG_MAX_NUM_NODES > 1
    TCBSetAffinity,
#endif
#if defined(CONFIG_HARDWARE_DEBUG_API)
    TCBSetBreakpoint,
#endif
#if defined(CONFIG_HARDWARE_DEBUG_API)
    TCBGetBreakpoint,
#endif
#if defined(CONFIG_HARDWARE_DEBUG_API)
    TCBUnsetBreakpoint,
#endif
#if defined(CONFIG_HARDWARE_DEBUG_API)
    TCBConfigureSingleStepping,
#endif
    TCBSetTLSBase,
    CNodeRevoke,
    CNodeDelete,
    CNodeCancelBadgedSends,
    CNodeCopy,
    CNodeMint,
    CNodeMove,
    CNodeMutate,
    CNodeRotate,
    CNodeSaveCaller,
    IRQIssueIRQHandler,
    IRQAckIRQ,
    IRQSetIRQHandler,
    IRQClearIRQHandler,
    DomainSetSet,
    nInvocationLabels
};

#endif /* __API_INVOCATION_H */
