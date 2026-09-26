#!/usr/bin/env python3
"""Tests for rejecting simulator and malformed executables before IPA delivery."""
import plistlib
import struct
import unittest
from validate_ipa import ARM64, MACH64, device_binary, validate


def executable(platform=2, cpu=ARM64):
    header = struct.pack("<8I", MACH64, cpu, 0, 2, 1, 24, 0, 0)
    build_version = struct.pack("<6I", 0x32, 24, platform, 0x110000, 0x120000, 0)
    return header + build_version


def manifest(platform="iPhoneOS"):
    return plistlib.dumps({
        "CFBundleSupportedPlatforms": [platform],
        "CFBundleExecutable": "PrismHarbour",
        "CFBundleIdentifier": "com.prismharbour.game",
        "CFBundlePackageType": "APPL",
        "MinimumOSVersion": "17.0",
        "CFBundleShortVersionString": "1.0",
    })


class DeviceBinaryValidationTests(unittest.TestCase):
    def test_accepts_arm64_ios_device(self):
        self.assertEqual(device_binary(executable())["platform"], "iOS device")

    def test_rejects_arm64_simulator(self):
        with self.assertRaisesRegex(ValueError, "iOS-device build platform"):
            device_binary(executable(platform=7))

    def test_rejects_desktop_and_catalyst(self):
        for platform in (1, 6):
            with self.subTest(platform=platform), self.assertRaises(ValueError):
                device_binary(executable(platform=platform))

    def test_rejects_wrong_architecture(self):
        with self.assertRaisesRegex(ValueError, "ARM64"):
            device_binary(executable(cpu=0x01000007))

    def test_rejects_truncated_binary(self):
        for size in (0, 31, 36, 55):
            with self.subTest(size=size), self.assertRaises(ValueError):
                device_binary(executable()[:size])

    def test_rejects_mislabeled_simulator_plist(self):
        with self.assertRaisesRegex(ValueError, "iPhoneOS"):
            validate(manifest("iPhoneSimulator"), executable(), "test.app")

    def test_device_manifest_cannot_hide_simulator_binary(self):
        with self.assertRaisesRegex(ValueError, "iOS-device build platform"):
            validate(manifest(), executable(platform=7), "test.app")

    def test_full_device_manifest_and_binary(self):
        result = validate(manifest(), executable(), "test.app")
        self.assertEqual(result["bundle"], "com.prismharbour.game")

    def test_fat_binary_checks_embedded_platform(self):
        for platform in (2, 7):
            thin = executable(platform=platform)
            fat = struct.pack(">7I", 0xCAFEBABE, 1, ARM64, 0, 28, len(thin), 2) + thin
            if platform == 2:
                self.assertEqual(device_binary(fat)["architecture"], "arm64")
            else:
                with self.assertRaises(ValueError):
                    device_binary(fat)


if __name__ == "__main__":
    unittest.main()