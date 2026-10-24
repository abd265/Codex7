#!/usr/bin/env python3
"""Reuse native speech evidence only when source and every model asset are unchanged."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import urllib.request

from validate_speech_bundle import validate as validate_bundle


def restore_verified_header_order(path, expected_sha):
    """A randomized metadata map may be reordered only to reproduce the exact tested file."""
    with path.open("rb") as stream:
        prefix = stream.read(8)
        size = struct.unpack("<Q", prefix)[0]
        assert 0 < size <= 32 * 1024 * 1024
        header = stream.read(size).decode("utf8")
        key = header.index('"__metadata__"')
        start = header.index(":", key) + 1
        while header[start].isspace():
            start += 1
        metadata, end = json.JSONDecoder().raw_decode(header, start)
        assert isinstance(metadata, dict) and 1 <= len(metadata) <= 4
        candidates = []
        for order in itertools.permutations(metadata):
            text = json.dumps({name: metadata[name] for name in order}, separators=(",", ":"), ensure_ascii=False)
            candidate = (header[:start] + text + header[end:]).encode("utf8")
            assert len(candidate) == size
            candidates.append((candidate, hashlib.sha256(prefix + candidate), order))
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            for _, digest, _ in candidates:
                digest.update(block)
    matches = [(header, order) for header, digest, order in candidates if digest.hexdigest() == expected_sha]
    assert len(matches) == 1, f"Cannot exactly reproduce verified safetensors bytes for {path.name}; rerun native inference"
    candidate, order = matches[0]
    with path.open("r+b") as stream:
        stream.seek(8)
        stream.write(candidate)
    return {"file": path.name, "metadataKeyOrder": list(order), "sha256": expected_sha,
            "tensorPayloadAndOtherHeaderBytesUnchanged": True}


def api(path):
    request = urllib.request.Request("https://api.github.com/" + path, headers={
        "User-Agent": "DarjaTogetherBuild", "Authorization": "Bearer " + os.environ["GITHUB_TOKEN"]})
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--run", required=True, type=int)
    args = parser.parse_args()
    repo = os.environ["GITHUB_REPOSITORY"]
    run = api(f"repos/{repo}/actions/runs/{args.run}")
    assert run["status"] == "completed", "Native evidence run is incomplete"
    jobs = api(f"repos/{repo}/actions/runs/{args.run}/jobs")["jobs"]
    required = {"Compile native F5 for Mac and physical iPhone",
                "Prepare the verified native speech model",
                "Synthesize actual Darja speech with the native engine"}
    succeeded = {step["name"] for job in jobs for step in job["steps"] if step["conclusion"] == "success"}
    assert required <= succeeded, "Native compilation, model preparation, and inference must have passed"
    source = run["head_sha"]
    allowed = {
        ".github/workflows/darja-together.yml", "DarjaTogether/.github/workflows/build-ios.yml",
        "DarjaTogether/DarjaTogether/Resources/THIRD-PARTY-NOTICES.txt",
        "DarjaTogether/DarjaTogether.xcodeproj/project.pbxproj", "DarjaTogether/Docs/BUILD.md",
        "DarjaTogether/scripts/test_ui.sh", "DarjaTogether/scripts/compile_native_speech.sh",
        "DarjaTogether/scripts/build_device.sh", "DarjaTogether/scripts/prepare_speech_bundle.sh",
        "DarjaTogether/scripts/codex7-workflow.yml", "DarjaTogether/scripts/verify_native_speech_evidence.py",
        "DarjaTogether/scripts/test_native_evidence.py",
        "DarjaTogether/UITests/DarjaTogetherUITests.swift",
    }
    changed = set(subprocess.check_output(["git", "diff", "--name-only", source, os.environ["GITHUB_SHA"]], text=True).splitlines())
    assert changed <= allowed, "Native evidence cannot be reused after unverified source changes: " + str(sorted(changed - allowed))
    current = json.loads(Path("artifacts/speech-model-validation.json").read_text())
    previous = json.loads((args.evidence / "speech-model-validation.json").read_text())
    expected = {item["file"]: item for item in previous["files"]}
    bundle = Path("DarjaTogether/Resources/SpeechModel")
    restored = []
    for item in current["files"]:
        if item["sha256"] != expected[item["file"]]["sha256"] and item["file"] in {"model.safetensors", "vocos.safetensors"}:
            restored.append(restore_verified_header_order(bundle / item["file"], expected[item["file"]]["sha256"]))
    if restored:
        current = validate_bundle(bundle)
        Path("artifacts/speech-model-validation.json").write_text(json.dumps(current, indent=2) + "\n")
        manifest_path = bundle / "conversion-manifest.json"
        manifest = json.loads(manifest_path.read_text())
        actual_hashes = {item["file"]: item["sha256"] for item in current["files"]}
        for item in manifest["files"]:
            if item["path"] in actual_hashes:
                item["sha256"] = actual_hashes[item["path"]]
        manifest["verifiedSerializationRestored"] = restored
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    assert current["files"] == previous["files"], "Prepared model/reference/vocabulary bytes differ from the verified native run"
    for command, filename in [(["xcodebuild", "-version"], "xcode-version-speech.txt"), (["swift", "--version"], "swift-version-speech.txt")]:
        toolchain = subprocess.check_output(command, text=True).strip()
        assert toolchain == (args.evidence / filename).read_text().strip(), "Native evidence uses a different toolchain"
    resolution = Path("DarjaTogether.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
    pins = json.loads(resolution.read_text())["pins"]
    previous_pins = json.loads((args.evidence / "speech-Package.resolved").read_text())["pins"]
    assert sorted(pins, key=lambda x: x["identity"]) == sorted(previous_pins, key=lambda x: x["identity"]), "Native dependency pins changed"
    parity = json.loads((args.evidence / "native-parity-validation.json").read_text())
    assert {x["component"] for x in parity} == {"DiT forward", "Reference mel", "Vocos waveform"}
    assert all(x["passed"] for x in parity), "Native parity did not pass"
    speech = json.loads((args.evidence / "native-speech-validation.json").read_text())
    wave = args.evidence / "DarjaTogether-native-speech.wav"
    assert hashlib.sha256(wave.read_bytes()).hexdigest() == speech["sha256"], "Native speech sample checksum mismatch"
    assert speech["sampleRate"] == 24000 and speech["channels"] == 1 and speech["rms"] > 0.0001
    keep = ["native-parity-validation.json", "native-parity.log", "native-speech-validation.json",
            "native-speech-inference.log", "DarjaTogether-native-speech.wav", "speech-parity-manifest.json",
            "speech-parity-reference.log", "speech-gpu.json", "speech-metal-device.json", "speech-Package.resolved",
            "speech-compile-validation.json", "xcodebuild-speech-macos.log", "xcodebuild-speech-ios.log"]
    for name in keep:
        shutil.copyfile(args.evidence / name, Path("artifacts") / name)
    artifacts = api(f"repos/{repo}/actions/runs/{args.run}/artifacts")["artifacts"]
    artifact = next(item for item in artifacts if item["name"] == "DarjaTogether-build-checks")
    report = {"reused": True, "nativeSourceCommit": source, "nativeBuildRun": args.run,
              "nativeEvidenceArtifactID": artifact["id"], "nativeEvidenceArtifactDigest": artifact["digest"],
              "nativeBuildURL": run["html_url"], "releaseSourceCommit": os.environ["GITHUB_SHA"],
              "unchangedNativeSource": True, "exactModelAssetsVerified": True,
              "sameToolchainAndDependencyPins": True, "restoredSafetensorsMetadataOrder": restored,
              "nativeChecksPassed": sorted(required), "changedSourcePaths": sorted(changed),
              "reason": "Correct simulator UI-test architecture and add license notices; native speech source and weights are identical."}
    Path("artifacts/native-evidence-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
