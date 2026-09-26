#!/usr/bin/env python3
"""Validate a physical-iPhone app/IPA; reject Apple Silicon simulator binaries."""
import argparse
import json
import plistlib
from pathlib import Path
import struct
from zipfile import ZipFile

ARM64 = 0x0100000C
MACH64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
LC_BUILD_VERSION = 0x32


def need(condition, message):
    if not condition:
        raise ValueError(message)


def device_binary(data):
    need(len(data) >= 32, "Missing or truncated Mach-O executable")
    magic = struct.unpack_from(">I", data)[0]
    if magic in (FAT_MAGIC, FAT_MAGIC_64):
        count = struct.unpack_from(">I", data, 4)[0]
        need(0 < count <= 32, "Invalid Mach-O fat header")
        entry_size = 32 if magic == FAT_MAGIC_64 else 20
        need(len(data) >= 8 + count * entry_size, "Truncated Mach-O fat architecture list")
        arm64 = None
        for index in range(count):
            position = 8 + index * entry_size
            cpu = struct.unpack_from(">I", data, position)[0]
            if magic == FAT_MAGIC_64:
                offset, length = struct.unpack_from(">QQ", data, position + 8)
            else:
                offset, length = struct.unpack_from(">II", data, position + 8)
            need(offset + length <= len(data), "Mach-O slice extends past executable")
            if cpu == ARM64:
                arm64 = data[offset:offset + length]
        need(arm64 is not None, "No ARM64 device architecture")
        return device_binary(arm64)

    need(struct.unpack_from("<I", data)[0] == MACH64, "Expected 64-bit little-endian Mach-O")
    _, cpu, _, file_type, count, commands_size, _, _ = struct.unpack_from("<8I", data)
    need(cpu == ARM64, "Not an ARM64 executable")
    need(file_type == 2, "Mach-O is not an application executable")
    need(32 + commands_size <= len(data), "Truncated Mach-O load commands")
    offset, platforms = 32, []
    for _ in range(count):
        need(offset + 8 <= 32 + commands_size, "Invalid Mach-O command count")
        command, length = struct.unpack_from("<II", data, offset)
        need(length >= 8 and offset + length <= 32 + commands_size, "Invalid Mach-O load command")
        if command == LC_BUILD_VERSION:
            need(length >= 24, "Truncated LC_BUILD_VERSION")
            platforms.append(struct.unpack_from("<I", data, offset + 8)[0])
        offset += length
    need(platforms == [2], f"Expected iOS-device build platform 2; found {platforms} (simulator is 7)")
    return {"architecture": "arm64", "platform": "iOS device"}


def validate(info_data, executable, label):
    info = plistlib.loads(info_data)
    need(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"], "Info.plist is not for iPhoneOS")
    need(info.get("CFBundleExecutable") == "PrismHarbour", "Unexpected app executable")
    need(info.get("CFBundleIdentifier") == "com.prismharbour.game", "Unexpected bundle identifier")
    need(info.get("CFBundlePackageType") == "APPL", "Bundle is not an application")
    need(str(info.get("MinimumOSVersion", "")).startswith("17."), "Expected minimum iOS 17")
    result = device_binary(executable)
    result.update({
        "file": str(label),
        "bundle": info["CFBundleIdentifier"],
        "version": info.get("CFBundleShortVersionString"),
        "minimumOS": info.get("MinimumOSVersion"),
        "signing": "Sideloadly or AltStore must sign the unsigned build before installation",
    })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="PrismHarbour .app directory or .ipa archive")
    args = parser.parse_args()
    if args.path.is_dir():
        result = validate(
            (args.path / "Info.plist").read_bytes(),
            (args.path / "PrismHarbour").read_bytes(), args.path,
        )
    else:
        with ZipFile(args.path) as archive:
            need(archive.testzip() is None, "Corrupt IPA archive")
            manifests = [
                name for name in archive.namelist()
                if name.startswith("Payload/") and name.count("/") == 2 and name.endswith(".app/Info.plist")
            ]
            need(manifests == ["Payload/PrismHarbour.app/Info.plist"], "IPA must contain one PrismHarbour app")
            result = validate(
                archive.read("Payload/PrismHarbour.app/Info.plist"),
                archive.read("Payload/PrismHarbour.app/PrismHarbour"), args.path,
            )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, struct.error) as error:
        raise SystemExit(f"Validation failed: {error}")