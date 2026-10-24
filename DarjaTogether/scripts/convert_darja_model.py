"""Convert the verified Darja checkpoint into local MLX Swift inference assets.

PyTorch is used only with weights_only=True. Optimizer/training state is discarded.
The resulting safetensors contain data only; no downloaded Python is executed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
import torch
from safetensors.torch import save_file

CHECKPOINT_SHA = "940fb1930b522b50213ef03c815a77364584c83fe9cecf5efa10f887f93265cc"
VOCOS_SHA = "97ec976ad1fd67a33ab2682d29c0ac7df85234fae875aefcc5fb215681a91b2a"
CONFIG = dict(formatVersion=1, modelID="touati-kamel/f5tts-algerian-darja", sampleRate=24000,
              dim=1024, depth=22, heads=18, dimHead=64, ffMult=2, textDim=512,
              convLayers=8, vocabSize=2580, textMaskPadding=False, peAttentionHeads=1)


def digest(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def checked_load(path, expected):
    if digest(path) != expected:
        raise ValueError(f"Integrity check failed: {path}")
    return torch.load(path, map_location="cpu", weights_only=True, mmap=True)


def model_key(key):
    if key.startswith("ema_model."):
        key = key[len("ema_model."):]
    replacements = (
        (".to_out.", ".to_out.layers."),
        (".text_blocks.", ".text_blocks.layers."),
        (".ff.ff.0.0.", ".ff.ff.layers.0.layers.0."),
        (".ff.ff.2.", ".ff.ff.layers.2."),
        (".time_mlp.", ".time_mlp.layers."),
        (".conv1d.", ".conv1d.layers."),
    )
    for original, replacement in replacements:
        key = key.replace(original, replacement)
    return key


def convert_model(source, destination):
    checkpoint = checked_load(source, CHECKPOINT_SHA)
    state = checkpoint.get("ema_model_state_dict")
    if not isinstance(state, dict):
        raise ValueError("Expected the verified checkpoint's EMA state dictionary")
    tensors, skipped, source_shapes = {}, [], {}
    for original, value in state.items():
        key = model_key(original)
        if not key.startswith("transformer."):
            skipped.append(original)
            continue
        if not isinstance(value, torch.Tensor):
            raise ValueError(f"Non-tensor model entry: {original}")
        if not value.is_floating_point() or not torch.isfinite(value).all():
            raise ValueError(f"Invalid model tensor: {original}")
        source_shapes[original] = list(value.shape)
        if key.endswith("dwconv.weight") or ("input_embed.conv_pos_embed.conv1d.layers." in key and key.endswith("weight")):
            if value.ndim != 3:
                raise ValueError(f"Expected Conv1d weight: {original}")
            value = value.permute(0, 2, 1)
        tensors[key] = value.to(dtype=torch.float16).contiguous()
    # These distinguish the requested Arabic architecture from the stock F5 model.
    checks = {
        "transformer.text_embed.text_embed.weight": (2581, 512),
        "transformer.transformer_blocks.0.attn.to_q.weight": (1152, 1024),
        "transformer.transformer_blocks.21.attn.to_q.weight": (1152, 1024),
    }
    for key, expected in checks.items():
        if key not in tensors or tuple(tensors[key].shape) != expected:
            raise ValueError(f"Architecture mismatch for {key}: expected {expected}")
    if not any("text_blocks.layers.7." in key for key in tensors):
        raise ValueError("Missing the eighth Arabic text-convolution block")
    save_file(tensors, str(destination), metadata={"source_sha256": CHECKPOINT_SHA, "precision": "float16", "state": "EMA", "conv_layout": "out,kernel,in"})
    return {"tensors": len(tensors), "parameters": sum(t.numel() for t in tensors.values()),
            "precision": "float16", "skippedNonTransformerKeys": skipped,
            "sourceShapes": source_shapes}


def convert_vocos(source, destination):
    state = checked_load(source, VOCOS_SHA)
    tensors = {}
    for key, value in state.items():
        if key.startswith("feature_extractor."):
            continue
        if not key.startswith(("backbone.", "head.")):
            raise ValueError(f"Unexpected Vocos key: {key}")
        if not isinstance(value, torch.Tensor) or not torch.isfinite(value).all():
            raise ValueError(f"Invalid Vocos tensor: {key}")
        if key == "backbone.embed.weight" or key.endswith("dwconv.weight"):
            value = value.permute(0, 2, 1)
        tensors[key] = value.to(torch.float32).contiguous()
    save_file(tensors, str(destination), metadata={"source_sha256": VOCOS_SHA, "precision": "float32", "conv_layout": "out,kernel,in"})
    return {"tensors": len(tensors), "parameters": sum(t.numel() for t in tensors.values()), "precision": "float32"}


def mel_filterbank():
    # Match torchaudio.functional.melscale_fbanks(513,0,12000,100,24000,
    # norm=None,mel_scale='htk').T; not librosa's Slaney normalization.
    frequencies = torch.linspace(0, 12000, 513)
    mel_max = 2595.0 * np.log10(1.0 + 12000.0 / 700.0)
    mel_points = torch.linspace(0.0, float(mel_max), 102)
    points = 700.0 * (10.0 ** (mel_points / 2595.0) - 1.0)
    differences = points[1:] - points[:-1]
    slopes = points.unsqueeze(0) - frequencies.unsqueeze(1)
    down = -slopes[:, :-2] / differences[:-1]
    up = slopes[:, 2:] / differences[1:]
    return torch.maximum(torch.zeros(1), torch.minimum(down, up)).T.contiguous().numpy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    # Match upstream get_tokenizer EXACTLY, including its char[:-1] behavior.
    # This published file has a blank line and no final newline: stripping empty
    # lines or renumbering would silently corrupt all later Arabic token IDs.
    with (args.source / "vocab.txt").open(encoding="utf-8") as stream:
        vocab = {line[:-1]: index for index, line in enumerate(stream)}
    if len(vocab) != CONFIG["vocabSize"] or vocab.get(" ") != 0:
        raise ValueError("The exact upstream Arabic vocabulary map has changed")
    (args.destination / "vocab.json").write_text(json.dumps(vocab, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print("Converting verified EMA acoustic weights...", flush=True)
    model = convert_model(args.source / "model_last.pt", args.destination / "model.safetensors")
    print(f"Acoustic model: {model['parameters']:,} parameters", flush=True)
    vocos = convert_vocos(args.source / "vocos/pytorch_model.bin", args.destination / "vocos.safetensors")
    np.save(args.destination / "mel_filters.npy", mel_filterbank())
    for original, target in (("vocab.txt", "vocab.txt"), ("reference-24k-mono.wav", "reference.wav"), ("reference.txt", "reference.txt"), ("companions-manifest.json", "companions-manifest.json")):
        shutil.copyfile(args.source / original, args.destination / target)
    shutil.copytree(args.source / "notices", args.destination / "notices", dirs_exist_ok=True)
    (args.destination / "config.json").write_text(json.dumps(CONFIG, indent=2) + "\n", encoding="utf-8")
    report = {"formatVersion": 1, "checkpointSHA256": CHECKPOINT_SHA, "model": model, "vocos": vocos,
              "torchVersion": torch.__version__, "melScale": "htk", "melNorm": None,
              "files": [{"path": p.relative_to(args.destination).as_posix(), "bytes": p.stat().st_size, "sha256": digest(p)}
                        for p in sorted(args.destination.rglob("*")) if p.is_file() and p.name != "conversion-manifest.json"]}
    (args.destination / "conversion-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"destination": str(args.destination), "modelParameters": model["parameters"],
                      "files": len(report["files"]), "totalBytes": sum(f["bytes"] for f in report["files"])}), flush=True)


if __name__ == "__main__":
    main()
