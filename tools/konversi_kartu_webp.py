#!/usr/bin/env python3
"""
Kecilkan gambar kartu (PNG) menjadi WebP supaya aplikasi tidak membengkak.
Otomatis memindai folder assets/ (termasuk semua subfolder di dalamnya).

Pemakaian dari root direktori embun:
    python tools/konversi_kartu_webp.py
    python tools/konversi_kartu_webp.py --hapus-png
"""
import argparse
import pathlib
import sys

from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    # Default diarahkan ke folder assets yang sejajar dengan tools/
    default_assets = pathlib.Path(__file__).resolve().parent.parent / "assets"
    ap.add_argument("folder", type=pathlib.Path, nargs="?", default=default_assets,
                    help="Target folder (default: embun/assets)")
    ap.add_argument("--lebar", type=int, default=768)
    ap.add_argument("--mutu", type=int, default=85)
    ap.add_argument("--hapus-png", action="store_true")
    a = ap.parse_args()

    if not a.folder.exists():
        print(f"Folder tidak ditemukan: {a.folder}")
        return 1

    # Menggunakan rglob agar otomatis menyisir semua PNG di subfolder assets/...
    pngs = sorted(a.folder.rglob("*.png"))
    if not pngs:
        print(f"Tidak ada berkas PNG yang ditemukan di {a.folder}")
        return 0

    print(f"Memproses {len(pngs)} berkas PNG di: {a.folder}\n")

    before = after = 0
    for p in pngs:
        im = Image.open(p)
        # Pertahankan transparansi bila ada, selain itu RGB
        im = im.convert("RGBA" if "A" in im.getbands() else "RGB")
        if im.width > a.lebar:
            h = round(im.height * a.lebar / im.width)
            im = im.resize((a.lebar, h), Image.LANCZOS)
        out = p.with_suffix(".webp")
        im.save(out, "WEBP", quality=a.mutu, method=6)
        b, w = p.stat().st_size, out.stat().st_size
        before += b
        after += w
        # Tampilkan path relatif terhadap folder assets agar rapi
        rel_path = p.relative_to(a.folder)
        print(f"{str(rel_path):45s} {b/1024:7.0f} KB -> {w/1024:5.0f} KB")
        if a.hapus_png:
            p.unlink()

    print(f"\nTotal: {before/1048576:.1f} MB -> {after/1048576:.1f} MB "
          f"(hemat {100*(1-after/before):.0f}%)")
    if not a.hapus_png:
        print("PNG asli masih ada. Gunakan flag --hapus-png untuk menghapusnya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())