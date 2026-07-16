#!/usr/bin/env python3
"""Fix macOS AppIcon.appiconset pixel sizes."""

from __future__ import annotations

import struct
import subprocess
import tempfile
from pathlib import Path

DEST = Path(
    "/Users/karma/Developer/Personal/KarmaAcademyApps/ShotCapture/"
    "ShotCapture/Assets.xcassets/AppIcon.appiconset"
)
MASTER = DEST / ("icon_512x512" + "@" + "2x.png")

# final_name -> pixel size
TARGETS = {
    "icon_16x16.png": 16,
    "icon_16x16" + "@" + "2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32" + "@" + "2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128" + "@" + "2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256" + "@" + "2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512" + "@" + "2x.png": 1024,
}


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    return struct.unpack(">II", data[16:24])


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for name, size in TARGETS.items():
            out = tmp_path / f"{size}.png"
            # Reuse if already generated at this pixel size
            if not out.exists():
                subprocess.check_call(
                    ["sips", "-z", str(size), str(size), str(MASTER), "--out", str(out)],
                    stdout=subprocess.DEVNULL,
                )
            dest = DEST / name
            dest.write_bytes(out.read_bytes())
            subprocess.call(["xattr", "-c", str(dest)])

    print("Verification:")
    all_ok = True
    for name, expected in TARGETS.items():
        w, h = png_size(DEST / name)
        ok = w == expected and h == expected
        all_ok = all_ok and ok
        print(f"{'OK' if ok else 'BAD'} {name}: {w}x{h} (expected {expected}x{expected})")
    if not all_ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
