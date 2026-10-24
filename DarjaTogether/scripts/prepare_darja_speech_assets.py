#!/usr/bin/env python3
"""Fetch pinned small F5 Darja companions; never download or alter the main checkpoint."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import time
import urllib.request
import wave
from datetime import datetime, timezone

DARJA_REPO = "touati-kamel/f5tts-algerian-darja"
DARJA_REV = "0589d128f0d0de70780a1e46cc425eb8cfa05d6b"
BASE_REPO = "IbrahimSalah/Arabic-F5-TTS-v2"
BASE_REV = "bd9ebf87d99c49789e6b41f3348d01c30b2444aa"
VOCOS_REPO = "charactr/vocos-mel-24khz"
VOCOS_REV = "0feb3fdd929bcd6649e0e7c5a688cf7dd012ef21"
F5_CODE_REV = "45868abaabd74aabf03cd673d6dd00cc9d9c01ae"
REFERENCE_TEXT = "لَا يَمُرُّ يَوْمٌ إِلَّا وَأَسْتَقْبِلُ عِدَّةَ رَسَائِلَ، تَتَضَمَّنُ أَسْئِلَةً مُلِحَّةْ."
REFERENCE_TEXT_SOURCE = "https://colab.research.google.com/drive/1udTmXSarrw9upSVp3tV5xl0Ki-2bTnhU"


def hf_url(repo: str, revision: str, filename: str) -> str:
    return f"https://huggingface.co/{repo}/resolve/{revision}/{filename}"


# All byte counts and SHA-256 values were checked against immutable upstream files.
FILES = [
    ("vocab.txt", hf_url(BASE_REPO, BASE_REV, "vocab.txt"), 11359,
     "c5794435e0d0368d9e6cf335d5e0004464169fa42b4ef7cafdfc3bbddf255e33"),
    ("F5TTS_Base_8_18.yaml", hf_url(BASE_REPO, BASE_REV, "F5TTS_Base_8_18.yaml"), 1906,
     "7842b5c9d0009f00f6ddde5d7944367ae98ff994dfe74d159183a187d4cba9f3"),
    ("reference-original.wav", hf_url(BASE_REPO, BASE_REV, "reference.wav"), 1058478,
     "d6db1e038c67df75cdde9ad1e43ba05f660eebc9346a30617d9b2f3892a5b201"),
    ("vocos/config.yaml", hf_url(VOCOS_REPO, VOCOS_REV, "config.yaml"), 461,
     "da9033922f969a47f0c160010226919e59f27761fd5066f3828d46de6650b0fc"),
    ("vocos/pytorch_model.bin", hf_url(VOCOS_REPO, VOCOS_REV, "pytorch_model.bin"), 54365991,
     "97ec976ad1fd67a33ab2682d29c0ac7df85234fae875aefcc5fb215681a91b2a"),
    ("notices/base-README.md", hf_url(BASE_REPO, BASE_REV, "README.md"), 4190,
     "834eb3c0a56f217bcabc0665da0f71b499066021ad28765ec3a4fcff846ad0ee"),
    ("notices/darja-README.md", hf_url(DARJA_REPO, DARJA_REV, "README.md"), 10387,
     "cbcb1401a00d420406823638325a530d9909b29b9ed42c207a32431cbb402e2c"),
    ("notices/vocos-README.md", hf_url(VOCOS_REPO, VOCOS_REV, "README.md"), 1830,
     "5858497d76d58914b29958a0f448e7b4fd3bb54940100baaa7520d4a56d8b3df"),
    ("notices/F5-TTS-code-LICENSE.txt",
     f"https://raw.githubusercontent.com/SWivid/F5-TTS/{F5_CODE_REV}/LICENSE", 1068,
     "c70811d1402134de900e811d3eaa349eb60f4d38a8f635b27b1e378c630facd2"),
]


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def checked_download(destination: Path, url: str, expected_size: int, expected_hash: str) -> None:
    if destination.exists():
        if destination.stat().st_size == expected_size and digest(destination) == expected_hash:
            print(f"Verified existing {destination.name}", flush=True)
            return
        raise RuntimeError(f"Existing file has unexpected contents: {destination}. Preserve it and resolve manually.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(3):
        temporary = None
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "DarjaTogether-companions/1.0"})
            with urllib.request.urlopen(request, timeout=90) as source:
                with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=destination.name + ".", suffix=".download", delete=False) as target:
                    temporary = Path(target.name)
                    total = 0
                    hasher = hashlib.sha256()
                    while True:
                        block = source.read(1024 * 1024)
                        if not block:
                            break
                        target.write(block)
                        total += len(block)
                        hasher.update(block)
            if total != expected_size or hasher.hexdigest() != expected_hash:
                raise RuntimeError(f"Integrity check failed for {destination.name}: size={total}, sha256={hasher.hexdigest()}")
            os.replace(temporary, destination)
            print(f"Downloaded and verified {destination.name} ({total:,} bytes)", flush=True)
            return
        except Exception:
            if temporary is not None and temporary.exists():
                temporary.unlink()  # Only this function's exact temporary file.
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def wave_metadata(path: Path) -> dict:
    with wave.open(str(path), "rb") as source:
        return {"channels": source.getnchannels(), "sampleRate": source.getframerate(),
                "sampleWidthBytes": source.getsampwidth(), "frames": source.getnframes(),
                "durationSeconds": source.getnframes() / source.getframerate()}


def convert_reference(source_path: Path, destination: Path) -> str:
    with wave.open(str(source_path), "rb") as source:
        channels, width, sample_rate = source.getnchannels(), source.getsampwidth(), source.getframerate()
        raw = source.readframes(source.getnframes())
    if width != 2 or channels != 2 or sample_rate != 44100:
        raise RuntimeError("Published reference format changed; expected PCM16 stereo 44.1 kHz.")
    try:
        import numpy as np
        from scipy.signal import resample_poly
        samples = np.frombuffer(raw, dtype="<i2").astype(np.float64).reshape(-1, channels).mean(axis=1)
        divisor = math.gcd(sample_rate, 24000)
        samples = resample_poly(samples, 24000 // divisor, sample_rate // divisor)
        converted = np.clip(np.rint(samples), -32768, 32767).astype("<i2").tobytes()
        method = "scipy.signal.resample_poly; stereo mean; PCM16 rounding and clipping"
    except ImportError:
        try:
            import audioop
        except ImportError as exc:
            raise RuntimeError("Use Python <=3.12 (audioop), or install numpy and scipy for reference conversion.") from exc
        mono = audioop.tomono(raw, 2, 0.5, 0.5)
        converted, _ = audioop.ratecv(mono, 2, 1, sample_rate, 24000, None)
        method = "Python audioop.tomono(0.5,0.5) + audioop.ratecv; PCM16"
    # This derived, reproducible file is owned by this preparation script.
    with wave.open(str(destination), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(24000)
        target.writeframes(converted)
    return method


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path,
                        default=Path(__file__).resolve().parents[2] / "DarjaTogether-models" / "f5tts-algerian-darja")
    args = parser.parse_args()
    root = args.model_dir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    records = []
    for relative, url, size, sha in FILES:
        destination = root / relative
        checked_download(destination, url, size, sha)
        records.append({"path": relative, "url": url, "bytes": size, "sha256": sha, "origin": "upstream"})
    reference = root / "reference-24k-mono.wav"
    method = convert_reference(root / "reference-original.wav", reference)
    records.append({"path": reference.name, "bytes": reference.stat().st_size, "sha256": digest(reference),
                    "origin": "derived", "derivedFrom": "reference-original.wav", "conversion": method,
                    "audio": wave_metadata(reference)})
    transcript = root / "reference.txt"
    transcript.write_text(REFERENCE_TEXT + "\n", encoding="utf-8")
    records.append({"path": transcript.name, "bytes": transcript.stat().st_size, "sha256": digest(transcript),
                    "origin": "published example transcript", "url": REFERENCE_TEXT_SOURCE})
    manifest = {
        "schemaVersion": 1, "preparedAtUTC": datetime.now(timezone.utc).isoformat(),
        "checkpointsDownloadedByThisScript": False,
        "mainCheckpoint": {"repo": DARJA_REPO, "revision": DARJA_REV, "file": "model_last.pt",
                           "bytes": 3542591049, "sha256": "940fb1930b522b50213ef03c815a77364584c83fe9cecf5efa10f887f93265cc"},
        "base": {"repo": BASE_REPO, "revision": BASE_REV},
        "vocos": {"repo": VOCOS_REPO, "revision": VOCOS_REV},
        "f5CodeRevision": F5_CODE_REV,
        "reference": {"originalAudio": wave_metadata(root / "reference-original.wav"),
                      "text": REFERENCE_TEXT, "textSource": REFERENCE_TEXT_SOURCE,
                      "description": "MSA example supplied by the Arabic base model author for inference; not an Algiers-native speaker claim.",
                      "separateSpeakerConsentDeclarationFound": False},
        "licenses": {
            "darjaDeclared": "apache-2.0",
            "arabicBaseDeclared": "fair-noncommercial-research-license; base card permits research, educational and personal non-commercial uses",
            "upstreamPretrainedWeights": "CC-BY-NC-4.0",
            "f5Code": "MIT",
            "vocosDeclared": "MIT",
            "caveat": "Fine-tune Apache metadata does not establish clearance of inherited noncommercial restrictions or third-party voice rights. This manifest is provenance, not a legal permission certificate."},
        "files": records,
    }
    manifest_path = root / "companions-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Ready: {manifest_path}", flush=True)
    print(f"Converted reference using {method}", flush=True)


if __name__ == "__main__":
    main()
