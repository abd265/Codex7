import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import wave
import zipfile

from validate_speech_bundle import validate, validate_ipa


class SpeechBundleValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = self.root / "SpeechModel"
        self.bundle.mkdir()
        header = json.dumps({"weight": {"dtype": "F32", "shape": [1], "data_offsets": [0, 4]}}).encode()
        for name in ["model.safetensors", "vocos.safetensors"]:
            (self.bundle / name).write_bytes(struct.pack("<Q", len(header)) + header + struct.pack("<f", 0.25))
        (self.bundle / "mel_filters.npy").write_bytes(b"\x93NUMPYfixture")
        (self.bundle / "vocab.txt").write_text("a\nb\n", encoding="utf8")
        (self.bundle / "vocab.json").write_text('{"a":0,"b":1}', encoding="utf8")
        (self.bundle / "config.json").write_text('{"sample_rate":24000}', encoding="utf8")
        (self.bundle / "reference.txt").write_text("Reference transcript", encoding="utf8")
        with wave.open(str(self.bundle / "reference.wav"), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(24000)
            output.writeframes(struct.pack("<h", 300) * 4800)

    def testCompleteBundleHashesEveryInferenceAsset(self):
        report = validate(self.bundle)
        self.assertEqual(len(report["files"]), 8)
        self.assertEqual(report["totalBytes"], sum(p.stat().st_size for p in self.bundle.iterdir()))
        model = next(x for x in report["files"] if x["file"] == "model.safetensors")
        self.assertEqual(model["sha256"], hashlib.sha256((self.bundle / model["file"]).read_bytes()).hexdigest())

    def testTruncatedTensorCannotPassTheBundleGate(self):
        path = self.bundle / "model.safetensors"
        path.write_bytes(path.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, "tensor extent"):
            validate(self.bundle)

    def testTrainingCheckpointCannotEnterTheApplication(self):
        (self.bundle / "model_last.pt").write_bytes(b"training-state")
        with self.assertRaisesRegex(ValueError, "training checkpoints"):
            validate(self.bundle)

    def testModelBytesMustSurviveIPAPackaging(self):
        report = validate(self.bundle)
        ipa = self.root / "app.ipa"
        with zipfile.ZipFile(ipa, "w") as archive:
            for path in self.bundle.iterdir():
                archive.write(path, "Payload/DarjaTogether.app/SpeechModel/" + path.name)
        self.assertTrue(validate_ipa(ipa, report)["nativeSpeechAssetsVerified"])
        damaged = self.root / "damaged.ipa"
        with zipfile.ZipFile(damaged, "w") as archive:
            for path in self.bundle.iterdir():
                data = path.read_bytes()
                if path.name == "model.safetensors": data = data[:-1] + bytes([data[-1] ^ 1])
                archive.writestr("Payload/DarjaTogether.app/SpeechModel/" + path.name, data)
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            validate_ipa(damaged, report)


if __name__ == "__main__":
    unittest.main()
