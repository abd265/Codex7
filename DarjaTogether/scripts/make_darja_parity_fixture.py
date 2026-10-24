"""Create independent PyTorch reference fixtures for the native Darja engine.

Usage: python scripts/make_darja_parity_fixture.py SOURCE_DIR OUTPUT_DIR

Requires torch, numpy, scipy, einops==0.8.2, x-transformers==1.31.14,
and packaging==25.0.
The original, hash-pinned upstream Python implementations execute on CPU. AST
selection avoids optional training/audio-decoder imports unavailable with the
installed PyTorch version; it does not replace any inference mathematics.
No converted MLX weights or native implementation are imported by this script.
"""
from __future__ import annotations

import argparse
import ast
import gc
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import sys
import types
import typing
import urllib.request
import warnings
import wave

import numpy as np
import torch


F5_REVISION = "45868abaabd74aabf03cd673d6dd00cc9d9c01ae"
VOCOS_REVISION = "eb39abfc42c1dee4854d9b10d44dd7d4fd3b0e53"
AUDIO_REVISION = "1255104d89889648f7cf8d786cefa0c77c6f3453"
CHECKPOINT_SHA = "940fb1930b522b50213ef03c815a77364584c83fe9cecf5efa10f887f93265cc"
VOCOS_SHA = "97ec976ad1fd67a33ab2682d29c0ac7df85234fae875aefcc5fb215681a91b2a"
VOCAB_SHA = "c5794435e0d0368d9e6cf335d5e0004464169fa42b4ef7cafdfc3bbddf255e33"
SOURCES = {
    "f5_modules.py": (f"SWivid/F5-TTS/{F5_REVISION}/src/f5_tts/model/modules.py", "92a1d97756bc7773a75c20e0e2fc913b3220f2ae2e6f042126f3ad8a57da9ce8"),
    "f5_dit.py": (f"SWivid/F5-TTS/{F5_REVISION}/src/f5_tts/model/backbones/dit.py", "838484daeea0ffcb5af9048e994721b02016229ed536afaecd6fe0d6d40ecd21"),
    "f5_utils.py": (f"SWivid/F5-TTS/{F5_REVISION}/src/f5_tts/model/utils.py", "37bf43bd5206cc0df0af28939bfdb6fe1d72fb222c88acef922f1da6e7dc8cd2"),
    "torchaudio_functional.py": (f"pytorch/audio/{AUDIO_REVISION}/src/torchaudio/functional/functional.py", "dc462a67270b2250279c47725346b26bc6cdc9dce77dd08602d0fcce68f78711"),
    "torchaudio_transforms.py": (f"pytorch/audio/{AUDIO_REVISION}/src/torchaudio/transforms/_transforms.py", "d73705853d6e8d0f0f212c39e0e3a0256811bcf4ac1a6f5fa8e8c65c26115680"),
    "vocos_modules.py": (f"gemelo-ai/vocos/{VOCOS_REVISION}/vocos/modules.py", "1132b0081333cc4abe1c36b2bd709185ceaa243519ea8903bec7ab08e67d5d64"),
    "vocos_models.py": (f"gemelo-ai/vocos/{VOCOS_REVISION}/vocos/models.py", "7031a1e223678cfeb522046f7e179e3ff9efd70aa32f969a4234880b59be1b71"),
    "vocos_heads.py": (f"gemelo-ai/vocos/{VOCOS_REVISION}/vocos/heads.py", "9fbe0f72b4772ba96b8ad90337242b1b4e179ffa1659d04e6e4759546e9d7c22"),
    "vocos_spectral_ops.py": (f"gemelo-ai/vocos/{VOCOS_REVISION}/vocos/spectral_ops.py", "d5e22c7f0c90c74f016d463aee58e02f02b8381d746b6a6aee2026446fb3ce11"),
}


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def checked(path: Path, expected: str) -> Path:
    if digest(path) != expected:
        raise ValueError(f"Integrity check failed: {path}")
    return path


def fetch_sources(directory: Path) -> list[dict]:
    directory.mkdir(parents=True, exist_ok=True)
    result = []
    for filename, (remote, expected) in SOURCES.items():
        path = directory / filename
        url = "https://raw.githubusercontent.com/" + remote
        if not path.exists():
            request = urllib.request.Request(url, headers={"User-Agent": "DarjaTogether-parity/1"})
            with urllib.request.urlopen(request, timeout=90) as response:
                payload = response.read()
            if hashlib.sha256(payload).hexdigest() != expected:
                raise ValueError(f"Downloaded source hash mismatch: {filename}")
            path.write_bytes(payload)
        checked(path, expected)
        result.append({"file": filename, "url": url, "sha256": expected, "bytes": path.stat().st_size})
    return result


def module(name: str, package: bool = False) -> types.ModuleType:
    value = types.ModuleType(name)
    if package:
        value.__path__ = []
    sys.modules[name] = value
    parent, _, child = name.rpartition(".")
    if parent in sys.modules:
        setattr(sys.modules[parent], child, value)
    return value


def execute_original(path: Path, name: str, *, select: set[str] | None = None,
                     omit_imports: set[str] | None = None, globals_: dict | None = None):
    """Execute original AST nodes, with only explicitly recorded import isolation."""
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    if select is not None:
        tree.body = [node for node in tree.body
                     if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name in select]
        found = {node.name for node in tree.body}
        if found != select:
            raise ValueError(f"Missing upstream definitions: {select - found}")
    if omit_imports:
        tree.body = [node for node in tree.body
                     if not (isinstance(node, ast.ImportFrom) and node.module in omit_imports)
                     and not (isinstance(node, ast.Import) and any(item.name in omit_imports for item in node.names))]
    value = module(name)
    value.__file__ = str(path)
    if globals_:
        value.__dict__.update(globals_)
    exec(compile(tree, str(path), "exec"), value.__dict__)
    return value


def original_implementations(directory: Path):
    # Only these original torchaudio functions/classes are needed for the F5
    # mel transform. This avoids a compiled torchaudio build tied to another
    # torch version; STFT and all transform math remain the upstream code.
    module("torchaudio", package=True)
    module("torchaudio.functional", package=True)
    functional_names = {"spectrogram", "_get_spec_norms", "_hz_to_mel", "_mel_to_hz",
                        "_create_triangular_filterbank", "melscale_fbanks"}
    common = {"torch": torch, "Tensor": torch.Tensor, "math": math, "warnings": warnings,
              "Optional": typing.Optional, "Union": typing.Union,
              "Callable": typing.Callable, "Tuple": typing.Tuple}
    functional = execute_original(directory / "torchaudio_functional.py",
                                  "torchaudio.functional.functional",
                                  select=functional_names, globals_=common)
    for name in functional_names:
        setattr(sys.modules["torchaudio.functional"], name, getattr(functional, name))
    execute_original(directory / "torchaudio_transforms.py", "torchaudio.transforms",
                     select={"Spectrogram", "MelScale", "MelSpectrogram"},
                     globals_={**common, "F": functional})

    module("f5_tts", package=True)
    module("f5_tts.model", package=True)
    module("f5_tts.model.backbones", package=True)
    utils = execute_original(directory / "f5_utils.py", "f5_tts.model.utils",
                             select={"get_tokenizer", "is_package_available"})
    modules = execute_original(directory / "f5_modules.py", "f5_tts.model.modules",
                               omit_imports={"librosa.filters"})
    dit = execute_original(directory / "f5_dit.py", "f5_tts.model.backbones.dit")
    module("vocos", package=True)
    execute_original(directory / "vocos_modules.py", "vocos.modules")
    execute_original(directory / "vocos_spectral_ops.py", "vocos.spectral_ops")
    vocos_models = execute_original(directory / "vocos_models.py", "vocos.models")
    vocos_heads = execute_original(directory / "vocos_heads.py", "vocos.heads")
    return utils, modules, dit, vocos_models, vocos_heads


def save_array(directory: Path, name: str, value, dtype=np.float32) -> dict:
    if isinstance(value, torch.Tensor):
        value = value.detach().cpu().numpy()
    array = np.ascontiguousarray(value, dtype=dtype)
    if not np.isfinite(array).all():
        raise ValueError(f"Non-finite output: {name}")
    path = directory / (name + ".npy")
    np.save(path, array, allow_pickle=False)
    return {"file": path.name, "shape": list(array.shape), "dtype": str(array.dtype),
            "sha256": digest(path), "bytes": path.stat().st_size,
            "minimum": float(array.min()), "maximum": float(array.max()),
            "rms": float(np.sqrt(np.mean(array.astype(np.float64) ** 2)))}


def peak_resident_bytes() -> int:
    if sys.platform == "win32":
        import ctypes
        from ctypes import wintypes

        class ProcessMemoryCounters(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        *[(name, ctypes.c_size_t) for name in (
                            "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                            "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
                            "PagefileUsage", "PeakPagefileUsage")]]

        counters = ProcessMemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.GetCurrentProcess.restype = wintypes.HANDLE
        psapi = ctypes.WinDLL("psapi", use_last_error=True)
        psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD]
        if not psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(), ctypes.byref(counters), counters.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        return counters.PeakWorkingSetSize
    import resource
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return int(peak if sys.platform == "darwin" else peak * 1024)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Directory prepared by prepare_darja_speech_assets.py")
    parser.add_argument("destination", type=Path)
    parser.add_argument("--threads", type=int, default=min(8, os.cpu_count() or 1))
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(args.threads)
    torch.manual_seed(20261023)
    torch.set_float32_matmul_precision("highest")
    versions = {name: importlib.metadata.version(name)
                for name in ("torch", "numpy", "scipy", "einops", "x-transformers", "packaging")}
    if versions["x-transformers"] != "1.31.14" or versions["einops"] != "0.8.2":
        raise ValueError("Install the pinned reference dependencies: x-transformers==1.31.14 einops==0.8.2")
    upstream = args.destination / "_upstream"
    sources = fetch_sources(upstream)
    utils, modules, dit, vocos_models, vocos_heads = original_implementations(upstream)

    checked(args.source / "vocab.txt", VOCAB_SHA)
    vocab, vocab_size = utils.get_tokenizer(str(args.source / "vocab.txt"), "custom")
    phrase = "سلام، واش راكي؟"
    if vocab_size != 2580 or any(character not in vocab for character in phrase):
        raise ValueError("Unexpected original tokenizer mapping")
    text = torch.tensor([[vocab[character] for character in phrase]], dtype=torch.int64)
    rng = np.random.default_rng(20261023)
    x = torch.from_numpy(rng.normal(0, 0.3, (1, 32, 100)).astype(np.float32))
    conditioning = torch.from_numpy(rng.normal(0, 0.1, (1, 32, 100)).astype(np.float32))
    conditioning[:, 16:] = 0
    time = torch.tensor([0.4], dtype=torch.float32)
    arrays = [save_array(args.destination, "x", x),
              save_array(args.destination, "conditioning", conditioning),
              save_array(args.destination, "text", text, np.int32),
              save_array(args.destination, "time", time)]

    print("Loading original verified EMA weights into upstream PyTorch DiT...", flush=True)
    checkpoint_path = checked(args.source / "model_last.pt", CHECKPOINT_SHA)
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True, mmap=True)
    original_state = checkpoint["ema_model_state_dict"]
    # Independent source weights, unchanged PyTorch layouts. Rounding to FP16
    # then back to FP32 matches the values shipped by the converter while
    # leaving layout, naming, and all execution semantics independently tested.
    state = {key.removeprefix("ema_model.transformer."): value.half().float()
             for key, value in original_state.items() if key.startswith("ema_model.transformer.")}
    model = dit.DiT(dim=1024, depth=22, heads=18, dim_head=64, ff_mult=2,
                    text_num_embeds=2580, text_dim=512, text_mask_padding=False,
                    conv_layers=8, pe_attn_head=1).eval()
    model.load_state_dict(state, strict=True, assign=True)
    print(f"Computing original DiT forward ({len(state)} tensors)...", flush=True)
    with torch.inference_mode():
        expected = model(x=x, cond=conditioning, text=text, time=time,
                         drop_audio_cond=False, drop_text=False, cache=False)
    arrays.append(save_array(args.destination, "expected_forward", expected))
    model_tensor_count = len(state)
    del expected, model, state, original_state, checkpoint
    gc.collect()

    with wave.open(str(args.source / "reference-24k-mono.wav"), "rb") as audio:
        if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getframerate() != 24000:
            raise ValueError("Reference must be mono PCM16 at 24 kHz")
        samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").astype(np.float32) / 32768
    with torch.inference_mode():
        mel_channels_first = modules.get_vocos_mel_spectrogram(torch.from_numpy(samples)[None])
        mel = mel_channels_first.transpose(1, 2).contiguous()
    arrays.extend([save_array(args.destination, "reference_samples", samples),
                   save_array(args.destination, "expected_mel", mel)])

    print("Computing original Vocos decode on 32 reference mel frames...", flush=True)
    vocos_path = checked(args.source / "vocos" / "pytorch_model.bin", VOCOS_SHA)
    vocos_state = torch.load(vocos_path, map_location="cpu", weights_only=True, mmap=True)
    backbone = vocos_models.VocosBackbone(input_channels=100, dim=512,
                                          intermediate_dim=1536, num_layers=8).eval()
    head = vocos_heads.ISTFTHead(dim=512, n_fft=1024, hop_length=256, padding="center").eval()
    backbone.load_state_dict({k.removeprefix("backbone."): v for k, v in vocos_state.items()
                              if k.startswith("backbone.")}, strict=True)
    head.load_state_dict({k.removeprefix("head."): v for k, v in vocos_state.items()
                          if k.startswith("head.")}, strict=True)
    # A spoken portion exercises non-silent frequency/phase reconstruction.
    vocos_mel = mel[:, 96:128].contiguous()
    with torch.inference_mode():
        vocos_output = head(backbone(vocos_mel.transpose(1, 2))).squeeze(0)
    arrays.extend([save_array(args.destination, "vocos_mel", vocos_mel),
                   save_array(args.destination, "expected_vocos", vocos_output)])

    manifest = {
        "formatVersion": 1, "seed": 20261023, "device": "cpu", "threads": args.threads,
        "peakResidentBytes": peak_resident_bytes(),
        "versions": versions, "sourceCheckpointSHA256": CHECKPOINT_SHA,
        "sourceVocosSHA256": VOCOS_SHA, "sourceVocabularySHA256": VOCAB_SHA,
        "sourceReferenceSHA256": digest(args.source / "reference-24k-mono.wav"),
        "f5Revision": F5_REVISION, "vocosRevision": VOCOS_REVISION,
        "torchaudioRevision": AUDIO_REVISION, "sourceFiles": sources,
        "referenceMethod": "Unmodified upstream PyTorch inference AST, not native-code reimplementation",
        "importIsolation": {
            "f5ModulesOmittedImports": ["librosa.filters (unused BigVGAN mel path)"],
            "f5UtilsSelectedOriginalFunctions": ["get_tokenizer", "is_package_available"],
            "torchaudioSelectedOriginalFunctions": ["spectrogram", "_get_spec_norms", "_hz_to_mel", "_mel_to_hz", "_create_triangular_filterbank", "melscale_fbanks"],
            "torchaudioSelectedOriginalClasses": ["Spectrogram", "MelScale", "MelSpectrogram"],
            "reason": "Avoid unrelated optional training dependencies and unavailable matching compiled torchaudio; selected function/class bodies unchanged",
        },
        "model": {"state": "EMA", "tensorCount": model_tensor_count,
                  "weightPrecision": "Original source EMA float32 rounded to float16 then float32",
                  "executionPrecision": "float32", "dropAudioConditioning": False,
                  "dropTextConditioning": False, "cache": False,
                  "text": phrase, "tokenIDs": text.tolist()[0]},
        "mel": {"method": "Original F5 get_vocos_mel_spectrogram using original torchaudio classes",
                "layout": "batch,time,mel", "sampleRate": 24000, "nFFT": 1024, "hopLength": 256,
                "power": 1, "scale": "htk", "norm": None, "center": True, "padding": "reflect",
                "logFloor": 1e-5, "inputGain": "PCM16 / 32768, no RMS normalization"},
        "vocos": {"method": "Original Vocos ISTFTHead(VocosBackbone(mel))",
                  "sourceMelFrames": [96, 128], "weightPrecision": "float32",
                  "padding": "center", "window": "Exact checkpoint head.istft.window"},
        "arrays": arrays,
    }
    (args.destination / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"destination": str(args.destination), "arrays": len(arrays),
                      "forwardShape": arrays[4]["shape"], "melShape": arrays[6]["shape"],
                      "vocosShape": arrays[8]["shape"],
                      "peakResidentBytes": manifest["peakResidentBytes"]}), flush=True)


if __name__ == "__main__":
    main()
