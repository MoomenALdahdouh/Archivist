#!/bin/zsh
set -euo pipefail
# Deterministic test data generator (seeded).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/Fixtures/generated}"
rm -rf "$OUT"
mkdir -p "$OUT/small" "$OUT/unicode" "$OUT/tree"

python3 - <<'PY' "$OUT"
import os, sys, hashlib, random
out = sys.argv[1]
rng = random.Random(20260815)

def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)

write(os.path.join(out, "small", "empty.txt"), b"")
write(os.path.join(out, "small", "one-byte.bin"), b"A")
write(os.path.join(out, "small", "hello.txt"), b"hello archivist\n")
write(os.path.join(out, "small", "compressible.txt"), b"ababab" * 10000)
write(os.path.join(out, "small", "random.bin"), bytes(rng.getrandbits(8) for _ in range(64 * 1024)))

unicode_names = [
    "مرحبا.txt",
    "ملف مهم.pdf",
    "İstanbul.txt",
    "çalışma.docx",
    "日本語.txt",
    "中文文件.pdf",
    "file with spaces.txt",
]
for name in unicode_names:
    write(os.path.join(out, "unicode", name), name.encode("utf-8"))

deep = os.path.join(out, "tree")
cur = deep
for i in range(12):
    cur = os.path.join(cur, f"level{i}")
write(os.path.join(cur, "leaf.txt"), b"deep\n")

manifest = []
for root, dirs, files in os.walk(out):
    for fn in files:
        path = os.path.join(root, fn)
        h = hashlib.sha256(open(path, "rb").read()).hexdigest()
        rel = os.path.relpath(path, out)
        manifest.append(f"{h}  {rel}")
open(os.path.join(out, "MANIFEST.sha256"), "w").write("\n".join(sorted(manifest)) + "\n")
print(f"Wrote {out}")
PY
