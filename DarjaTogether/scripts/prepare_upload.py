#!/usr/bin/env python3
"""Prepare a reviewable GitHub tree manifest; this script does not upload anything."""
import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDE = {"artifacts", "build", ".build", ".git", "__pycache__", ".DS_Store"}
BINARY = {".png", ".jpg", ".jpeg", ".wav", ".m4a", ".mp3", ".pdf"}

def main():
    entries = []
    for path in sorted(ROOT.rglob("*")):
        relative = path.relative_to(ROOT)
        if not path.is_file() or any(part in EXCLUDE for part in relative.parts):
            continue
        data = path.read_bytes()
        item = {"path": "DarjaTogether/" + relative.as_posix(), "mode": "100755" if path.suffix == ".sh" else "100644", "type": "blob"}
        item["git_sha"] = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if path.suffix.lower() in BINARY:
            item.update(binary=True, content=base64.b64encode(data).decode("ascii"))
        else:
            item["content"] = data.decode("utf-8")
        entries.append(item)
    workflow = ROOT / "scripts/codex7-workflow.yml"
    entries.append({"path": ".github/workflows/darja-together.yml", "mode": "100644", "type": "blob", "content": workflow.read_text(encoding="utf-8")})
    directory = ROOT / "artifacts"
    directory.mkdir(exist_ok=True)
    manifest = directory / "upload-files.json"
    manifest.write_text(json.dumps(entries, ensure_ascii=False), encoding="utf-8")
    chunks, chunk, size = [], [], 0
    for entry in entries:
        cost = len(json.dumps(entry, ensure_ascii=False))
        if chunk and size + cost > 60000:
            chunks.append(chunk)
            chunk, size = [], 0
        chunk.append(entry)
        size += cost
    if chunk:
        chunks.append(chunk)
    for index, chunk in enumerate(chunks):
        (directory / f"upload-part-{index}.json").write_text(json.dumps(chunk, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"manifest": str(manifest), "files": len(entries), "chunks": len(chunks), "binary_files": sum(bool(x.get("binary")) for x in entries), "paths": [x["path"] for x in entries]}, indent=2))

if __name__ == "__main__":
    main()
