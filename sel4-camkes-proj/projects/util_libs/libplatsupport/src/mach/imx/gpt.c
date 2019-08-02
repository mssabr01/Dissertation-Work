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

#include <stdio.h>
#include <assert.h>
#include <errno.h>
#include <stdlib.h>

#include <utils/util.h>

#include <platsupport/timer.h>
#include <platsupport/plat/timer.h>

/* The GPT status register is w1c (write 1 to clear), and there are 6 status bits in the iMX
   status register, so writing the value 0b111111 = 0x3F will clear it. */
#define GPT_STATUS_REGISTER_CLEAR 0x3F

/* GPT CONTROL REGISTER BITS */
typedef enum {
    /*
     * This bit enables the GPT.
     */
    EN = 0,

    /*
     * When GPT is disabled (EN=0), then
     * both Main Counter and Prescaler Counter freeze their count at
     * current count values. The ENMOD bit determines the value of
     * the GPT counter when Counter is enabled again (if the EN bit is set).
     *
     *   If the ENMOD bit is 1, then the Main Counter and Prescaler Counter
     *   values are reset to 0 after GPT is enabled (EN=1).
     *
     *   If the ENMOD bit is 0, then the Main Counter and Prescaler Counter
     *   restart counting from their frozen values after GPT is enabled (EN=1).
     *
     *   If GPT is programmed to be disabled in a low power mode (STOP/WAIT), then
     *   the Main Counter and Prescaler Counter freeze at their current count
     *   values when the GPT enters low power mode.
     *
     *   When GPT exits low power mode, the Main Counter and Prescaler Counter start
     *   counting from their frozen values, regardless of the ENMOD bit value.
     *
     *   Setting the SWR bit will clear the Main Counter and Prescalar Counter values,
     *   regardless of the value of EN or ENMOD bits.
     *
     *   A hardware reset resets the ENMOD bit.
     *   A software reset does not affect the ENMOD bit.
     */
    ENMOD = 1,

    /*
     * This read/write control bit enables the operation of the GPT
     *  during debug mode
     */
    DBGEN = 2,

    /*
     *  This read/write control bit enables the operation of the GPT
     *  during wait mode
     */
    WAITEN = 3,

    /*
     * This read/write control bit enables the operation of the GPT
     *  during doze mode
     */
    DOZEN = 4,

    /*
     * This read/write control bit enables the operation of the GPT
     *  during stop mode
     */
    STOPEN = 5,

    /*
     * bits 6-8 -  These bits selects the clock source for the
     *  prescaler and subsequently be used to run the GPT counter.
     *  the following sources are available on i.MX 7 board:
     *  000: no clock
     *  001: peripheral clock
     *  010: high frequency reference clock
     *  011: external clock (CLKIN)
     *  100: low frequency reference clock 32 kHZ
     *  101: crystal oscillator as reference clock 24 MHz
     *  others: reserved
     *  by default the peripheral clock is used.
     *
     *  For imx6 :
     *  000: no clock
     *  001: peripheral clock
     *  010: high frequency reference clock
     *  011: external clock (CLKIN)
     *  100: low frequency reference clock
     *  101: crystal oscillator divided by 8 as reference clock
     *  111: crystal osscillator as reference clock
     */
    CLKSRC = 6,

    /*
     * Freerun or Restart mode.
     *
     * 0 Restart mode
     * 1 Freerun mode
     */
    FRR = 9,

    /* for i.MX7 only
     * enable the 24 MHz clock input from crystal
     * a hardware reset resets the EN_24M bit.
     * a software reset dose not affect the EN_24M bit.
     * 0: disabled
     * 1: enabled
     */
    EN_24M = 10,

    /*
     * Software reset.
     *
     * This bit is set when the module is in reset state and is cleared
     * when the reset procedure is over. Writing a 1 to this bit
     * produces a single wait state write cycle. Setting this bit
     * resets all the registers to their default reset values except
     * for the EN, ENMOD, STOPEN, DOZEN, WAITEN and DBGEN bits in this
     *  control register.
     */
    SWR = 15,

    /* Input capture channel operating modes */
    IM1 = 16, IM2 = 18,

    /* Output compare channel operating modes */
    OM1 = 20, OM2 = 23, OM3 = 26,

    /* Force output compare channel bits */
    FO1 = 29, FO2 = 30, FO3 = 31

} gpt_control_reg;

/* bits in the interrupt/status regiser */
enum gpt_interrupt_register_bits {

    /* Output compare interrupt enable bits */
    OF1IE = 0, OF2IE = 1, OF3IE = 2,

    /* Input capture interrupt enable bits */
    IF1IE = 3, IF2IE = 4,

    /* Rollover interrupt enabled */
    ROV = 5,
};

/* Memory map for GPT. */
struct gpt_map {
    /* gpt control register */
    uint32_t gptcr;
    /* gpt prescaler register */
    uint32_t gptpr;
    /* gpt status register */
    uint32_t gptsr;
    /* gpt interrupt register */
    uint32_t gptir;
    /* gpt output compare register 1 */
    uint32_t gptcr1;
    /* gpt output compare register 2 */
    uint32_t gptcr2;
    /* gpt output compare register 3 */
    uint32_t gptcr3;
    /* gpt input capture register 1 */
    uint32_t gpticr1;
    /* gpt input capture register 2 */
    uint32_t gpticr2;
    /* gpt counter register */
    uint32_t gptcnt;
};

int gpt_start(gpt_t *gpt)
{
    gpt->gpt_map->gptcr |= BIT(EN);
    gpt->high_bits = 0;
    return 0;
}

int gpt_stop(gpt_t *gpt)
{
    /* Disable timer. */
    gpt->gpt_map->gptcr &= ~(BIT(EN));
    gpt->high_bits = 0;
    return 0;
}

void gpt_handle_irq(gpt_t *gpt)
{
    /* we've only set the GPT to interrupt on overflow */
    assert(gpt != NULL);
    if (gpt->gpt_map->gptcr & BIT(FRR)) {
        /* free-run mode, we should only enable the rollover interrupt */
        if (gpt->gpt_map->gptsr & BIT(ROV)) {
            gpt->high_bits++;
        }
    }
    /* clear the interrupt status register */
    gpt->gpt_map->gptsr = GPT_STATUS_REGISTER_CLEAR;
}

uint64_t gpt_get_time(gpt_t *gpt)
{
    uint32_t low_bits = gpt->gpt_map->gptcnt;
    uint32_t high_bits = gpt->high_bits;
    if (gpt->gpt_map->gptsr) {
        /* irq has come in */
        high_bits++;
    }

    uint64_t value = ((uint64_t) high_bits << 32llu) + low_bits;
    /* convert to ns */
    uint64_t ns = (value / (uint64_t)GPT_FREQ) * NS_IN_US * (gpt->prescaler + 1);
    return ns;
}

int gpt_init(gpt_t *gpt, gpt_config_t config)
{
    uint32_t gptcr = 0;
    if (gpt == NULL) {
        return EINVAL;
    }

    gpt->gpt_map = config.vaddr;
    gpt->prescaler = config.prescaler;

    /* Disable GPT. */
    gpt->gpt_map->gptcr = 0;
    gpt->gpt_map->gptsr = GPT_STATUS_REGISTER_CLEAR;

    /* Configure GPT. */
    gpt->gpt_map->gptcr = 0 | BIT(SWR); /* Reset the GPT */
    /* SWR will be 0 when the reset is done */
    while (gpt->gpt_map->gptcr & BIT(SWR));
    /* GPT can do more but for this just set it as free running  so we can tell the time */
    gptcr = BIT(FRR) | BIT(ENMOD);

#ifdef CONFIG_PLAT_IMX7
    /* eanble the 24MHz source and select the oscillator as CLKSRC */
    gptcr |= (BIT(EN_24M) | (5u << CLKSRC));
#else
    gptcr |= BIT(CLKSRC);
#endif

    gpt->gpt_map->gptcr = gptcr;
    gpt->gpt_map->gptir = BIT(ROV); /* Interrupt when the timer overflows */

    /* The prescaler register has two parts when the 24 MHz clocksource is used.
     * The 24MHz crystal clock is devided by the (the top 15-12 bits + 1) before
     * it is fed to the CLKSRC field.
     * The clock selected by the CLKSRC is divided by the (the 11-0 bits + ) again.
     * For unknown reason, when the prescaler for the 24MHz clock is set to zero, which
     * is valid according to the manual, the GPTCNT register does not work. So we
     * set the value at least to 1, using a 12MHz clocksource.
     */

#ifdef CONFIG_PLAT_IMX7
    gpt->gpt_map->gptpr = config.prescaler | (1u << 12);
#else
    gpt->gpt_map->gptpr = config.prescaler; /* Set the prescaler */
#endif

    gpt->high_bits = 0;

    return 0;
}

int gpt_set_timeout(gpt_t  *gpt, uint64_t ns, bool periodic)
{
    uint32_t gptcr = 0;
    uint64_t counter_value = (uint64_t)(GPT_FREQ / (gpt->prescaler + 1)) * (ns / 1000ULL);
    if (counter_value >= (1ULL << 32)) {
        ZF_LOGE("ns too high %llu\n", ns);
        return EINVAL;
    }

    gpt->gpt_map->gptcr = 0;
    gpt->gpt_map->gptsr = GPT_STATUS_REGISTER_CLEAR;
    gpt->gpt_map->gptcr = BIT(SWR);
    while (gpt->gpt_map->gptcr & BIT(SWR));
    gptcr = (periodic ? 0 : BIT(FRR));

#ifdef CONFIG_PLAT_IMX7
    gptcr |= BIT(EN_24M) | (5u << CLKSRC);
#else
    gptcr |= BIT(CLKSRC);
#endif

    gpt->gpt_map->gptcr = gptcr;
    gpt->gpt_map->gptcr1 = (uint32_t)counter_value;
    while (gpt->gpt_map->gptcr1 != counter_value) {
        gpt->gpt_map->gptcr1 = (uint32_t)counter_value;
    }

#ifdef CONFIG_PLAT_IMX7
    gpt->gpt_map->gptpr = gpt->prescaler | BIT(12);
#else
    gpt->gpt_map->gptpr = gpt->prescaler; /* Set the prescaler */
#endif

    gpt->gpt_map->gptir = 1;
    gpt->gpt_map->gptcr |= BIT(EN);

    return 0;
}
