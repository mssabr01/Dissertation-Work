#!/usr/bin/env python
# -*- coding: utf-8 -*-

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

from __future__ import absolute_import, division, print_function, \
    unicode_literals

import os, sys, unittest

ME = os.path.abspath(__file__)

# Make CAmkES importable
sys.path.append(os.path.join(os.path.dirname(ME), '../../..'))

from camkes.internal.tests.utils import CAmkESTest
from camkes.parser import ParseError, DtbMatchQuery

class TestDTBMatchQuery(CAmkESTest):
    def setUp(self):
        super(TestDTBMatchQuery, self).setUp()
        self.dtbQuery = DtbMatchQuery()
        self.dtbQuery.parse_args(['--dtb', os.path.join(os.path.dirname(ME), "test.dtb")])
        self.dtbQuery.check_options()

    def test_aliases(self):
        node = self.dtbQuery.resolve({'aliases':'usbphy0'})
        self.assertIsInstance(node, dict)

        expected = {
            'compatible' : ["fsl,imx6q-usbphy", "fsl,imx23-usbphy"],
            'reg' : [0x20c9000, 0x1000],
            'interrupts' : [0x0, 0x2c, 0x4],
            'clocks' : [0x4, 0xb6],
            'fsl,anatop' : [0x2],
            'phandle' : [0x2c]
        }
        self.assertEquals(node, expected)

        node = self.dtbQuery.resolve({'aliases':'spi4'})
        expected = {
            '#address-cells' : [0x1],
            '#size-cells' : [0x0],
            'compatible' : ["fsl,imx6q-ecspi", "fsl,imx51-ecspi"],
            'reg' : [0x2018000, 0x4000],
            'interrupts' : [0x0, 0x23, 0x4],
            'clocks' : [0x4, 0x74, 0x4, 0x74],
            'clock-names' : ["ipg", "per"],
            'dmas' : [0x17, 0xb, 0x8, 0x1, 0x17, 0xc, 0x8, 0x2],
            'dma-names' : ["rx", "tx"],
            'status' : ["disabled"]
        };

        self.assertEquals(node, expected)

    def test_paths(self):
        node = self.dtbQuery.resolve({'path':"temp"})
        expected = {
            'compatible' : ["fsl,imx6q-tempmon"],
            'interrupt-parent' : [0x1],
            'interrupts' : [0x0, 0x31, 0x4],
            'fsl,tempmon' : [0x2],
            'fsl,tempmon-data' : [0x3],
            'clocks' : [0x4, 0xac]
        }
        self.assertEquals(node, expected)

        node = self.dtbQuery.resolve({'path': '.*serial.*'})
        expected = {
            'compatible' : ["fsl,imx6q-uart", "fsl,imx21-uart"],
            'reg' : [0x2020000, 0x4000],
            'interrupts' : [0x0, 0x1a, 0x4],
            'clocks' : [0x4, 0xa0, 0x4, 0xa1],
            'clock-names' : ["ipg", "per"],
            'dmas' : [0x17, 0x19, 0x4, 0x0, 0x17, 0x1a, 0x4, 0x0],
            'dma-names' : ["rx", "tx"],
            'status' : ["okay"],
            'pinctrl-names' : ["default"],
            'pinctrl-0' : [0x1a]
        }
        self.assertEquals(node, expected)

    def test_blank(self):
        self.assertRaises(ParseError, self.dtbQuery.resolve, {})

    def test_properties_lvalue_index(self):
        node = self.dtbQuery.resolve({'properties': {'reg[0]': 0x2020000}})
        expected = {
            'dma-names': ['rx', 'tx'],
            'status': ['okay'],
            'clock-names': ['ipg', 'per'],
            'interrupts': [0, 26, 4],
            'pinctrl-names': ['default'],
            'compatible': ['fsl,imx6q-uart', 'fsl,imx21-uart'],
            'dmas': [23, 25, 4, 0, 23, 26, 4, 0],
            'clocks': [4, 160, 4, 161],
            'pinctrl-0': [26], 'reg': [33685504, 16384]
        }
        self.assertEquals(node, expected)

        node = self.dtbQuery.resolve({'properties': {'compatible[0]': 'fsl,imx6q-pwm'}})
        expected = {
            'status': ['okay'],
            'pinctrl-0': [29],
            'clock-names': ['ipg', 'per'],
            'interrupts': [0, 83, 4],
            '#pwm-cells': [2],
            'pinctrl-names': ['default'],
            'compatible': ['fsl,imx6q-pwm', 'fsl,imx27-pwm'],
            'clocks': [4, 62, 4, 145],
            'phandle': [121],
            'reg': [34078720, 16384]
        }
        self.assertEquals(node, expected)

    def test_properties_star_string(self):
        node = self.dtbQuery.resolve({
            'properties':  {
                "clock-names[*]": ["di0_pll", "di1_pll", "di0_sel", "di1_sel", "di2_sel", "di3_sel", "di0", "di1"]
            }
        })

        self.assertIn('#address-cells', node)
        self.assertEquals(node['#address-cells'], [0x1])

        self.assertIn('#size-cells', node)
        self.assertEquals(node['#size-cells'], [0x0])

        self.assertIn('compatible', node)
        self.assertEquals(node['compatible'], ["fsl,imx6q-ldb", "fsl,imx53-ldb"])

        self.assertIn('gpr', node)
        self.assertEquals(node['gpr'], [0x5])

        self.assertIn('status', node)
        self.assertEquals(node['status'], ["okay"])

        self.assertIn('clocks', node)
        self.assertEquals(node['clocks'], [0x4, 0x21, 0x4, 0x22, 0x4, 0x27, 0x4, 0x28, 0x4, 0x29, 0x4, 0x2a, 0x4, 0x87,
                                           0x4, 0x88])

        self.assertIn('clock-names', node)
        self.assertEquals(node['clock-names'], ["di0_pll", "di1_pll", "di0_sel", "di1_sel", "di2_sel", "di3_sel",
                                                "di0", "di1"])

        node = self.dtbQuery.resolve({
            'properties': {
                "interrupt-names[*]": ["gpmi0", "gpmi1", "gpmi2", "gpmi3"]
            }
        })

        expected = {
            'compatible': ["fsl,imx6q-dma-apbh", "fsl,imx28-dma-apbh"],
            'reg': [0x110000, 0x2000],
            'interrupts': [0x0, 0xd, 0x4, 0x0, 0xd, 0x4, 0x0, 0xd, 0x4, 0x0, 0xd, 0x4],
            'interrupt-names': ["gpmi0", "gpmi1", "gpmi2", "gpmi3"],
            '#dma-cells': [0x1],
            'dma-channels': [0x4],
            'clocks': [0x4, 0x6a],
            'phandle': [0xf]
        };
        self.assertEquals(node, expected)

        node = self.dtbQuery.resolve({
            'properties': {
                "compatible[*]": ["fsl,imx6q-pcie", "snps,dw-pcie"]
            }
        })
        expected = {
            'compatible': ["fsl,imx6q-pcie", "snps,dw-pcie"],
            'reg': [0x1ffc000, 0x4000, 0x1f00000, 0x80000],
            'reg-names': ["dbi", "config"],
            '#address-cells': [0x3],
            '#size-cells': [0x2],
            'device_type': ["pci"],
            'bus-range': [0x0, 0xff],
            'ranges': [0x81000000, 0x0, 0x0, 0x1f80000, 0x0, 0x10000, 0x82000000, 0x0, 0x1000000, 0x1000000, 0x0,
                       0xf00000],
            'num-lanes': [0x1],
            'interrupts': [0x0, 0x78, 0x4],
            'interrupt-names': ["msi"],
            '#interrupt-cells': [0x1],
            'interrupt-map-mask': [0x0, 0x0, 0x0, 0x7],
            'interrupt-map': [0x0, 0x0, 0x0, 0x1, 0x1, 0x0, 0x7b, 0x4, 0x0, 0x0, 0x0, 0x2, 0x1, 0x0, 0x7a, 0x4, 0x0,
                              0x0, 0x0, 0x3, 0x1, 0x0, 0x79, 0x4, 0x0, 0x0, 0x0, 0x4, 0x1, 0x0, 0x78, 0x4],
            'clocks': [0x4, 0x90, 0x4, 0xce, 0x4, 0xbd],
            'clock-names': ["pcie", "pcie_bus", "pcie_phy"],
            'status': ["okay"]
        };
        self.assertEquals(node, expected)

    def test_properties_star_word_and_byte(self):
        node = self.dtbQuery.resolve({
            'properties': {
                "clocks[*]": [0x4, 0x98, 0x4, 0x99, 0x4, 0x97, 0x4, 0x96, 0x4, 0x95]
            }
        })

        expected = {
            'compatible': ["fsl,imx6q-gpmi-nand"],
            '#address-cells': [0x1],
            '#size-cells': [0x1],
            'reg': [0x112000, 0x2000, 0x114000, 0x2000],
            'reg-names': ["gpmi-nand", "bch"],
            'interrupts': [0x0, 0xf, 0x4],
            'interrupt-names': ["bch"],
            'clocks': [0x4, 0x98, 0x4, 0x99, 0x4, 0x97, 0x4, 0x96, 0x4, 0x95],
            'clock-names': ["gpmi_io", "gpmi_apb", "gpmi_bch", "gpmi_bch_apb", "per1_bch"],
            'dmas': [0xf, 0x0],
            'dma-names': ["rx-tx"],
            'status': ["disabled"]
        }
        self.assertEquals(node, expected)

if __name__ == '__main__':
    unittest.main()
