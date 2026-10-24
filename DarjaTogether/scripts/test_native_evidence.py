import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from verify_native_speech_evidence import restore_verified_header_order


class VerifiedSerializationTests(unittest.TestCase):
    def fixture(self, order):
        metadata = {key: {"source": "abc", "precision": "float16"}[key] for key in order}
        header = json.dumps({"__metadata__": metadata, "weight": {"dtype": "F16", "shape": [2], "data_offsets": [0, 4]}}, separators=(",", ":")).encode()
        return struct.pack("<Q", len(header)) + header + b"\x01\x02\x03\x04"

    def test_restores_only_metadata_order_to_exact_previously_tested_bytes(self):
        original = self.fixture(["source", "precision"])
        verified = self.fixture(["precision", "source"])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "model.safetensors"
            path.write_bytes(original)
            report = restore_verified_header_order(path, hashlib.sha256(verified).hexdigest())
            self.assertEqual(path.read_bytes(), verified)
            self.assertTrue(report["tensorPayloadAndOtherHeaderBytesUnchanged"])

    def test_unmatched_payload_hash_fails_without_changing_file(self):
        original = self.fixture(["source", "precision"])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "model.safetensors"
            path.write_bytes(original)
            with self.assertRaisesRegex(AssertionError, "rerun native inference"):
                restore_verified_header_order(path, hashlib.sha256(original + b"different weights").hexdigest())
            self.assertEqual(path.read_bytes(), original)
