#!/usr/bin/env python3
"""
Kecilkan gambar kartu (PNG) menjadi WebP supaya aplikasi tidak membengkak.

Contoh: kartu 1024x1536 PNG ~3,4 MB menjadi WebP 768x1152 ~0,3 MB (hemat ~90%).
Aplikasi otomatis memilih .webp bila ada .png dengan nama yang sama
(lihat AssetCatalog.load), jadi nama berkas TIDAK berubah, hanya ekstensinya.

Pemakaian:
    pip install pillow
    python konversi_kartu_webp.py  assets/kartu/protagonis
    python konversi_kartu_webp.py  assets/kartu/protagonis --hapus-png

Pilihan:
    --lebar N       lebar maksimum (default 768; tinggi mengikuti rasio)
    --mutu N        mutu WebP 1-100 (default 85)
    --hapus-png     hapus PNG asli setelah berhasil dikonversi
                    (tanpa ini kedua berkas ikut terbundel ke aplikasi)
"""
import argparse
import pathlib
import sys

from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", type=pathlib.Path)
    ap.add_argument("--lebar", type=int, default=768)
    ap.add_argument("--mutu", type=int, default=85)
    ap.add_argument("--hapus-png", action="store_true")
    a = ap.parse_args()

    pngs = sorted(a.folder.glob("*.png"))
    if not pngs:
        print(f"Tidak ada PNG di {a.folder}")
        return 1

    before = after = 0
    for p in pngs:
        im = Image.open(p)
        # pertahankan transparansi bila ada, selain itu RGB
        im = im.convert("RGBA" if "A" in im.getbands() else "RGB")
        if im.width > a.lebar:
            h = round(im.height * a.lebar / im.width)
            im = im.resize((a.lebar, h), Image.LANCZOS)
        out = p.with_suffix(".webp")
        im.save(out, "WEBP", quality=a.mutu, method=6)
        b, w = p.stat().st_size, out.stat().st_size
        before += b
        after += w
        print(f"{p.name:40s} {b/1024:7.0f} KB -> {w/1024:5.0f} KB")
        if a.hapus_png:
            p.unlink()

    print(f"\nTotal: {before/1048576:.1f} MB -> {after/1048576:.1f} MB "
          f"(hemat {100*(1-after/before):.0f}%)")
    if not a.hapus_png:
        print("PNG asli masih ada. Hapus (atau pakai --hapus-png) agar tidak "
              "ikut terbundel.")
    return 0


if __name__ == "__main__":
    sys.exit(main())