#!/usr/bin/env python3
"""Check the complete native F5 asset directory without importing PyTorch."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave
import zipfile


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def validate(directory):
    directory = Path(directory)
    required = ["model.safetensors", "vocos.safetensors", "mel_filters.npy",
                "vocab.txt", "vocab.json", "config.json", "reference.wav", "reference.txt"]
    for name in required:
        path = directory / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"Missing or empty native speech asset: {name}")
    if any(p.suffix in {".pt", ".pth", ".ckpt"} for p in directory.rglob("*")):
        raise ValueError("The app bundle must not contain training checkpoints")
    for name in ["model.safetensors", "vocos.safetensors"]:
        path = directory / name
        with path.open("rb") as stream:
            length = struct.unpack("<Q", stream.read(8))[0]
            if not 2 <= length <= 32 * 1024 * 1024:
                raise ValueError(f"Invalid safetensors header size: {name}")
            header = json.loads(stream.read(length))
        tensors = {k: v for k, v in header.items() if k != "__metadata__"}
        if not tensors:
            raise ValueError(f"No tensor weights in {name}")
        payload_bytes = path.stat().st_size - 8 - length
        for key, tensor in tensors.items():
            start, end = tensor["data_offsets"]
            if not 0 <= start <= end <= payload_bytes:
                raise ValueError(f"Invalid tensor extent: {name}/{key}")
    config = json.loads((directory / "config.json").read_text(encoding="utf-8"))
    if not isinstance(config, dict) or not config:
        raise ValueError("The native model configuration must be a nonempty object")
    vocabulary = json.loads((directory / "vocab.json").read_text(encoding="utf-8"))
    if not isinstance(vocabulary, dict) or not vocabulary or not all(isinstance(k, str) and isinstance(v, int) and v >= 0 for k, v in vocabulary.items()):
        raise ValueError("The exact exported vocabulary must map tokens to nonnegative IDs")
    if not (directory / "reference.txt").read_text(encoding="utf-8").strip():
        raise ValueError("The reference voice needs its exact transcript")
    with wave.open(str(directory / "reference.wav"), "rb") as reference:
        if reference.getnchannels() != 1 or reference.getframerate() != 24000:
            raise ValueError("The reference voice must be mono 24 kHz WAV")
        if reference.getnframes() < 2400:
            raise ValueError("The reference voice is too short")
    files = [{"file": name, "bytes": (directory / name).stat().st_size,
              "sha256": digest(directory / name)} for name in required]
    return {"directory": str(directory), "totalBytes": sum(f["bytes"] for f in files),
            "format": "native F5 MLX + Vocos", "files": files}


def validate_ipa(ipa, report):
    with zipfile.ZipFile(ipa) as archive:
        prefix = "Payload/DarjaTogether.app/SpeechModel/"
        for asset in report["files"]:
            name = prefix + asset["file"]
            info = archive.getinfo(name)
            if info.file_size != asset["bytes"]:
                raise ValueError(f"Bundled model asset size mismatch: {name}")
            result = hashlib.sha256()
            with archive.open(name) as stream:
                for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
                    result.update(block)
            if result.hexdigest() != asset["sha256"]:
                raise ValueError(f"Bundled model asset checksum mismatch: {name}")
    return {"ipa": str(ipa), "nativeSpeechAssetsVerified": True,
            "totalBytes": report["totalBytes"], "files": report["files"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ipa", type=Path, help="Also verify exact native model bytes inside an IPA")
    args = parser.parse_args()
    report = validate(args.directory)
    if args.ipa:
        report = validate_ipa(args.ipa, report)
    print(json.dumps(report, indent=2))
