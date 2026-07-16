#!/usr/bin/env python3
"""Install ShotCapture macOS app icons with correct @2x filenames and sizes."""

from __future__ import annotations

import json
import struct
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path("/Users/karma/Developer/Personal/KarmaAcademyApps/ShotCapture")
DEST = ROOT / "ShotCapture/Assets.xcassets/AppIcon.appiconset"
SRC_CANDIDATES = [
    Path("/Users/karma/.cursor/projects/Users-karma-Developer-Personal-KarmaAcademyApps-ShotCapture/assets/ShotCapture-Icon-v9-balanced.png"),
    Path("/Users/karma/.cursor/projects/Users-karma-Developer-Personal-KarmaAcademyApps-ShotCapture/assets/ShotCapture-Icon-v8-propor.png"),
    Path("/Users/karma/.cursor/projects/Users-karma-Developer-Personal-KarmaAcademyApps-ShotCapture/assets/ShotCapture-Icon-v7-bigbg.png"),
]

# pt size -> (1x pixels, 2x pixels)
MAC_SLOTS = [
    ("16x16", 16, 32),
    ("32x32", 32, 64),
    ("128x128", 128, 256),
    ("256x256", 256, 512),
    ("512x512", 512, 1024),
]


def at2x(base: str) -> str:
    # Build filename without writing a literal "name@2x.png" in source if tools mangle it.
    return base + "@" + "2x.png"


def png_dims(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    return struct.unpack(">II", data[16:24])


def load_master() -> Image.Image:
    for src in SRC_CANDIDATES:
        if src.exists():
            img = Image.open(src).convert("RGBA")
            w, h = img.size
            side = min(w, h)
            left = (w - side) // 2
            top = (h - side) // 2
            img = img.crop((left, top, left + side, top + side))
            return img.resize((1024, 1024), Image.Resampling.LANCZOS)
    raise FileNotFoundError("No source icon found")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)

    # Remove everything except we will rewrite Contents.json
    for p in DEST.iterdir():
        if p.name == "Contents.json" or p.suffix.lower() in {".png", ".org", ".net", ".com"}:
            p.unlink()
        elif p.is_file() and "icon_" in p.name:
            p.unlink()

    master = load_master()

    images_json = []
    for size_name, px1, px2 in MAC_SLOTS:
        name1 = f"icon_{size_name}.png"
        name2 = at2x(f"icon_{size_name}")

        path1 = DEST / name1
        path2 = DEST / name2

        master.resize((px1, px1), Image.Resampling.LANCZOS).save(path1, "PNG")
        master.resize((px2, px2), Image.Resampling.LANCZOS).save(path2, "PNG")
        subprocess.call(["xattr", "-c", str(path1)])
        subprocess.call(["xattr", "-c", str(path2)])

        images_json.append({
            "filename": name1,
            "idiom": "mac",
            "scale": "1x",
            "size": size_name,
        })
        images_json.append({
            "filename": name2,
            "idiom": "mac",
            "scale": "2x",
            "size": size_name,
        })

    contents = {"images": images_json, "info": {"author": "xcode", "version": 1}}
    (DEST / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    # Verify
    data = json.loads((DEST / "Contents.json").read_text())
    print("Contents.json filenames:")
    for img in data["images"]:
        fn = img["filename"]
        path = DEST / fn
        w, h = png_dims(path)
        expected = int(img["size"].split("x")[0]) * (2 if img["scale"] == "2x" else 1)
        status = "OK" if w == expected == h else "BAD"
        print(f"  {status} {fn!r}: {w}x{h} (expected {expected})")

    orphans = [p.name for p in DEST.iterdir() if p.suffix in {".org", ".net", ".com"}]
    print("orphans:", orphans or "none")


if __name__ == "__main__":
    main()
