from pathlib import Path
from PIL import Image

ASSETS = Path("assets")
BACKUP = Path("..") / "embun_asli"  # PNG asli dipindah ke luar repositori
MAX_SIDE = {"bentang": 1600, "pohon": 1600, "kartu": 640}


def compress(src):
    rel = src.relative_to(ASSETS)
    if any(part in ("belum", "sudah") for part in rel.parts):
        return
    img = Image.open(src)
    has_alpha = img.mode in ("RGBA", "LA") or "transparency" in img.info
    img = img.convert("RGBA" if has_alpha else "RGB")
    side = MAX_SIDE.get(rel.parts[0], 1600)
    img.thumbnail((side, side), Image.LANCZOS)

    dst = src.with_suffix(".webp")
    img.save(dst, "WEBP", quality=82, method=6)

    keep = BACKUP / rel
    keep.parent.mkdir(parents=True, exist_ok=True)
    before = src.stat().st_size // 1024
    src.replace(keep)
    print(f"{rel}: {before} KB -> {dst.stat().st_size // 1024} KB")


for src in sorted(ASSETS.rglob("*.png")):
    compress(src)

print("Selesai.")