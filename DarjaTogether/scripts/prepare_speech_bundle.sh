#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts build
test -f scripts/speech-requirements.txt
python3 -m venv build/speech-conversion-venv
converter="$PWD/build/speech-conversion-venv/bin/python"
"$converter" -m pip install --disable-pip-version-check -r scripts/speech-requirements.txt
"$converter" scripts/download_darja_model.py build/speech-source 2>&1 | tee artifacts/speech-download.log
"$converter" scripts/prepare_darja_speech_assets.py --model-dir build/speech-source 2>&1 | tee artifacts/speech-prepare.log
"$converter" scripts/convert_darja_model.py build/speech-source DarjaTogether/Resources/SpeechModel 2>&1 | tee artifacts/speech-conversion.log
"$converter" scripts/validate_speech_bundle.py DarjaTogether/Resources/SpeechModel > artifacts/speech-model-validation.json
if [[ "${DARJA_REUSE_NATIVE_EVIDENCE:-0}" != "1" ]]; then
  "$converter" scripts/make_darja_parity_fixture.py build/speech-source build/speech-parity 2>&1 | tee artifacts/speech-parity-reference.log
  cp build/speech-parity/manifest.json artifacts/speech-parity-manifest.json
fi
# Remove only this build's input checkpoint after the complete inference bundle
# and any new fixtures exist. A release reusing evidence verifies identical model
# hashes against the prior passed run before packaging. The manifest is retained.
"$converter" - <<'PY'
from pathlib import Path
root = Path("build/speech-source").resolve()
checkpoint = (root / "model_last.pt").resolve()
assert checkpoint.parent == root and root.is_relative_to(Path("build").resolve())
if checkpoint.is_file():
    checkpoint.unlink()
PY
