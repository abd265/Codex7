#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
model_directory="${1:-$PWD/DarjaTogether/Resources/SpeechModel}"
if [[ "$model_directory" != /* ]]; then model_directory="$PWD/$model_directory"; fi
products="$PWD/build/speech-macos/Build/Products/Release"
executable="$products/DarjaF5Smoke"
test -x "$executable"
python3 scripts/validate_speech_bundle.py "$model_directory" > artifacts/speech-model-validation.json
reference_text="$(cat "$model_directory/reference.txt")"
test -n "$reference_text"
output="$PWD/artifacts/DarjaTogether-native-speech.wav"
export DYLD_FRAMEWORK_PATH="$products/PackageFrameworks:$products"
compute_device="$(python3 - <<'PY'
import json
from pathlib import Path
report = json.loads(Path("artifacts/speech-metal-device.json").read_text())
assert isinstance(report.get("available"), bool), "Missing Metal availability diagnostic"
print("gpu" if report["available"] else "cpu")
PY
)"
echo "Native synthesis validation compute device: $compute_device"
echo "Checking native numerical parity against the independent PyTorch fixtures on CPU."
if ! /usr/bin/time -l "$executable" \
  --model-dir "$model_directory" \
  --parity-dir "$PWD/build/speech-parity" \
  --cpu > artifacts/native-parity-validation.json 2> artifacts/native-parity.log; then
  cat artifacts/native-parity-validation.json
  cat artifacts/native-parity.log >&2
  exit 1
fi
python3 - <<'PY'
import json
from pathlib import Path
metrics = json.loads(Path("artifacts/native-parity-validation.json").read_text())
assert len(metrics) >= 2 and all(item["passed"] for item in metrics), "Native/PyTorch numerical parity failed"
print(json.dumps(metrics, indent=2))
PY
# A real forward pass through this checkpoint and Vocos must succeed; the app's
# AVSpeech fallback and prerecorded output are never used by this executable.
command=("$executable" \
  --model-dir "$model_directory" \
  --reference-wav "$model_directory/reference.wav" \
  --reference-text "$reference_text" \
  --text "${DARJA_SMOKE_TEXT:-سلام، واش راكي؟}" \
  --output "$output" \
  --steps "${DARJA_SMOKE_STEPS:-32}")
if [[ "$compute_device" == "cpu" ]]; then command+=(--cpu); fi
/usr/bin/time -l "${command[@]}" 2>&1 | tee artifacts/native-speech-inference.log
python3 - "$output" "$compute_device" <<'PY'
import array, hashlib, json, math, sys, wave
from pathlib import Path
path = Path(sys.argv[1])
with wave.open(str(path), "rb") as audio:
    assert audio.getnchannels() == 1, "Expected mono speech"
    assert audio.getframerate() == 24000, "Expected 24 kHz speech"
    assert audio.getsampwidth() == 2, "Expected PCM16 speech"
    samples = array.array("h", audio.readframes(audio.getnframes()))
    if sys.byteorder != "little": samples.byteswap()
    duration = len(samples) / 24000
assert 0.1 <= duration <= 60, f"Unexpected generated duration: {duration}"
peak = max(abs(x) for x in samples) / 32768
rms = math.sqrt(sum((x / 32768) ** 2 for x in samples) / len(samples))
assert peak > 0.001 and rms > 0.0001, "Generated audio is silent"
report = {"sampleRate": 24000, "channels": 1, "durationSeconds": duration,
          "peak": peak, "rms": rms, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
          "backend": "DarjaF5 / MLX / Vocos", "computeDevice": sys.argv[2], "physicalIPhoneTested": False}
Path("artifacts/native-speech-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
PY
