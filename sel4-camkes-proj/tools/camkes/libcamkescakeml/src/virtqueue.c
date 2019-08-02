/*
 * Copyright 2018, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(DATA61_BSD)
 */

#include <string.h>
#include <virtqueue.h>
#include <camkes/virtqueue.h>
#include <utils/util.h>

/* This file contains FFI functions for interacting with virtqueues from CakeML.
 *
 * Some functions are simple wrappers around their C counterparts, whilst others
 * like `driver_send` provide slightly more "functional" abstractions over the low-level
 * interface, with the aim of insulating CakeML from some of the buffer mangling that is
 * more easily accomplished in C. In the future we may want to tear these abstractions down
 * or indeed implement the basic functionality of the virtqueues library in CakeML itself.
 *
 * By convention, the first byte of the array returned will be FFI_SUCCESS (0) if the call
 * succeeded, or FFI_FAILURE (1) if it did not. We may want to add more descriptive errors
 * in the future.
 */

#define FFI_SUCCESS 0
#define FFI_FAILURE 1

void ffivirtqueue_device_init(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_device_t * virtqueue;
    int32_t virtqueue_id;
    memcpy(&virtqueue_id, a + 1, sizeof(virtqueue_id));

    int err = camkes_virtqueue_device_init(&virtqueue, virtqueue_id);

    if (err) {
        ZF_LOGE("%s: unable to create a new virtqueue device", __func__);
        a[0] = FFI_FAILURE;
    } else {
        memcpy(a + 1, &virtqueue, sizeof(virtqueue_device_t *));
        a[0] = FFI_SUCCESS;
    }
}

void ffivirtqueue_driver_init(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_driver_t * virtqueue;
    int32_t virtqueue_id;
    memcpy(&virtqueue_id, a + 1, sizeof(virtqueue_id));

    int err = camkes_virtqueue_driver_init(&virtqueue, virtqueue_id);

    if (err) {
        ZF_LOGE("%s: unable to create a new virtqueue device", __func__);
        a[0] = FFI_FAILURE;
    } else {
        memcpy(a + 1, &virtqueue, sizeof(virtqueue_device_t *));
        a[0] = FFI_SUCCESS;
    }
}

void ffivirtqueue_device_poll(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_device_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    int poll_res = virtqueue_device_poll(virtqueue);

    if (poll_res == -1) {
        ZF_LOGE("%s: device poll failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    memcpy(a + 1, &poll_res, sizeof(poll_res));
    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_driver_poll(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_driver_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    int poll_res = virtqueue_driver_poll(virtqueue);

    if (poll_res == -1) {
        ZF_LOGE("%s: driver poll failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    memcpy(a + 1, &poll_res, sizeof(poll_res));
    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_device_recv(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_device_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    // 1. Dequeue available buffer from virtqueue
    volatile void * available_buff = NULL;
    size_t buf_size = 0;
    int dequeue_res = virtqueue_device_dequeue(virtqueue,
                                               &available_buff,
                                               &buf_size);

    if (dequeue_res) {
        ZF_LOGE("%s: device dequeue failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    // 2. Copy to CakeML buffer
    memcpy(a + 1, &buf_size, sizeof(buf_size));
    memcpy(a + 1 + sizeof(buf_size), (void *) available_buff, buf_size);

    // 3. Enqueue the buffer on the used queue to let the other end know we've finished with it
    int enqueue_res = virtqueue_device_enqueue(virtqueue, available_buff, buf_size);
    if (enqueue_res) {
        ZF_LOGE("%s: device enqueue failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }
    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_device_signal(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_device_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    int signal_res = virtqueue_device_signal(virtqueue);

    if (signal_res != 0) {
        ZF_LOGE("%s: device signal failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_driver_signal(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_driver_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    int signal_res = virtqueue_driver_signal(virtqueue);

    if (signal_res != 0) {
        ZF_LOGE("%s: driver signal failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_driver_recv(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_driver_t * virtqueue;
    memcpy(&virtqueue, a + 1, sizeof(virtqueue));

    // 1. Dequeue used buffer from virtqueue
    volatile void * used_buff = NULL;
    size_t buf_size = 0;
    int dequeue_res = virtqueue_driver_dequeue(virtqueue,
                                               &used_buff,
                                               &buf_size);

    if (dequeue_res) {
        ZF_LOGE("%s: driver dequeue failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    camkes_virtqueue_buffer_free(virtqueue, used_buff);
    a[0] = FFI_SUCCESS;
}

void ffivirtqueue_driver_send(char * c, unsigned long clen, char * a, unsigned long alen) {
    virtqueue_driver_t * virtqueue;
    int offset = 1;
    memcpy(&virtqueue, a + offset, sizeof(virtqueue));
    offset += sizeof(virtqueue);

    size_t message_len = 0;
    memcpy(&message_len, a + offset, sizeof(size_t));
    offset += sizeof(size_t);

    char * message = a + offset;

    volatile void * alloc_buffer = NULL;
    int err = camkes_virtqueue_buffer_alloc(virtqueue, &alloc_buffer, message_len);
    if (err) {
        ZF_LOGE("%s: alloc for driver send failed", __func__);
        a[0] = FFI_FAILURE;
        return;
    }

    memcpy((void *) alloc_buffer, (void *) message, message_len);

    err = virtqueue_driver_enqueue(virtqueue, alloc_buffer, message_len);
    if (err != 0) {
        ZF_LOGE("%s: client enqueue failed", __func__);
        camkes_virtqueue_buffer_free(virtqueue, alloc_buffer);
        a[0] = FFI_FAILURE;
        return;
    }

    a[0] = FFI_SUCCESS;
}
