"""Download the requested F5 checkpoint at an immutable revision and verify it.

Only downloads data. It never loads or executes a PyTorch checkpoint.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
from urllib.request import Request, urlopen

REPOSITORY = "touati-kamel/f5tts-algerian-darja"
REVISION = "0589d128f0d0de70780a1e46cc425eb8cfa05d6b"
SIZE = 3542591049
SHA256 = "940fb1930b522b50213ef03c815a77364584c83fe9cecf5efa10f887f93265cc"


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(8 * 1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    target = args.destination / "model_last.pt"
    temporary = args.destination / "model_last.pt.partial"
    url = f"https://huggingface.co/{REPOSITORY}/resolve/{REVISION}/model_last.pt"
    if target.exists():
        if target.stat().st_size != SIZE or digest(target) != SHA256:
            raise SystemExit("Existing checkpoint failed verification; refusing to replace it.")
    else:
        for attempt in range(1, 6):
            offset = temporary.stat().st_size if temporary.exists() else 0
            if offset == SIZE:
                break
            if offset > SIZE:
                raise SystemExit("Partial checkpoint is larger than the expected file.")
            headers = {"User-Agent": "DarjaTogether-model-download/1.0"}
            if offset:
                headers["Range"] = f"bytes={offset}-"
            try:
                with urlopen(Request(url, headers=headers), timeout=90) as response:
                    if offset and response.status != 206:
                        raise RuntimeError("Server did not honor download resume; partial file preserved.")
                    if offset and not response.headers.get("Content-Range", "").startswith(f"bytes {offset}-"):
                        raise RuntimeError("Unexpected resume response range.")
                    received, last_report = offset, time.monotonic()
                    with temporary.open("ab" if offset else "wb") as output:
                        while chunk := response.read(4 * 1024 * 1024):
                            output.write(chunk)
                            received += len(chunk)
                            if received > SIZE:
                                raise RuntimeError("Server returned more bytes than expected.")
                            if time.monotonic() - last_report >= 10:
                                print(f"Downloaded {received / 1e9:.2f} / {SIZE / 1e9:.2f} GB ({received / SIZE:.1%})", flush=True)
                                last_report = time.monotonic()
                if received == SIZE:
                    break
            except Exception as error:
                print(f"Attempt {attempt}: {type(error).__name__}: {error}", flush=True)
                if attempt == 5:
                    raise
                time.sleep(min(attempt * 2, 10))
        if not temporary.exists() or temporary.stat().st_size != SIZE:
            raise SystemExit("Download incomplete; rerun to resume.")
        print("Verifying SHA-256...", flush=True)
        if digest(temporary) != SHA256:
            raise SystemExit("Checksum mismatch; partial file preserved for inspection.")
        temporary.rename(target)
    metadata = {"repository": REPOSITORY, "revision": REVISION, "file": target.name,
                "bytes": SIZE, "sha256": SHA256, "verified": True, "source": url}
    (args.destination / "download-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2), flush=True)


if __name__ == "__main__":
    main()
