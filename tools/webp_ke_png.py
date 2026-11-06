"""Ubah ikon webp di web/icons menjadi PNG (menimpa PNG berlogo Flutter).

Pemakaian (dari folder proyek):
  pip install pillow
  python tools/webp_ke_png.py

Membaca  : web/icons/Icon-192.webp, Icon-512.webp,
           Icon-maskable-192.webp, Icon-maskable-512.webp
Menulis  : berkas PNG bernama sama di web/icons/, dan web/favicon.png
Transparansi dipertahankan. Berkas webp tidak dihapus.
"""
import sys
from pathlib import Path
from PIL import Image

ICONS = Path(__file__).resolve().parent.parent / "web" / "icons"
NAMA = ["Icon-192", "Icon-512", "Icon-maskable-192", "Icon-maskable-512"]


def main() -> None:
    hilang = [n for n in NAMA if not (ICONS / f"{n}.webp").exists()]
    if hilang:
        sys.exit("Berkas webp tidak ditemukan di web/icons: "
                 + ", ".join(f"{n}.webp" for n in hilang))

    for n in NAMA:
        im = Image.open(ICONS / f"{n}.webp").convert("RGBA")
        sisi = int(n.rsplit("-", 1)[1])
        if im.size != (sisi, sisi):
            im = im.resize((sisi, sisi), Image.LANCZOS)
        im.save(ICONS / f"{n}.png", optimize=True)
        print("ditulis:", f"web/icons/{n}.png", im.size)

    fav = Image.open(ICONS / "Icon-512.webp").convert("RGBA")
    fav.resize((64, 64), Image.LANCZOS).save(ICONS.parent / "favicon.png", optimize=True)
    print("ditulis: web/favicon.png (64x64)")


if __name__ == "__main__":
    main()