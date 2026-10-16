#!/usr/bin/env python3
"""Génère l'icône de l'application (et ses variantes) + les visuels du site.

Usage : python3 tools/make_icon.py
Dépendances : Pillow, qrcode (pip install pillow qrcode)

La géométrie (maison + motif QR) est en coordonnées normalisées [0, 1] et
reprise à l'identique dans App/BadgeCreche/Services/PassArtwork.swift pour
les images du pass Wallet.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "App" / "BadgeCreche" / "Assets.xcassets" / "AppIcon.appiconset"
DOCS = ROOT / "docs"

CORAL_TOP = (255, 143, 107)
CORAL_BOTTOM = (255, 107, 74)
CORAL = (255, 122, 89)
NAVY = (34, 48, 90)
WHITE = (255, 255, 255)

HOUSE = [(0.50, 0.15), (0.88, 0.47), (0.79, 0.47), (0.79, 0.85),
         (0.21, 0.85), (0.21, 0.47), (0.12, 0.47)]
HOUSE_ROUNDING = 0.05  # épaisseur du trait arrondi qui adoucit les angles
FINDER = 0.13
FINDERS = [(0.34, 0.505), (0.53, 0.505), (0.34, 0.695)]
CELL = FINDER / 3
MODULES = [(0.53 + c * CELL, 0.695 + r * CELL) for c, r in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]]

SUPERSAMPLE = 4


def draw_motif(draw: ImageDraw.ImageDraw, size: int, house_color, module_color, house_cutout_color):
    s = size
    pts = [(x * s, y * s) for x, y in HOUSE]
    draw.polygon(pts, fill=house_color)
    width = int(HOUSE_ROUNDING * s)
    draw.line(pts + [pts[0]], fill=house_color, width=width, joint="curve")
    r = width / 2
    for x, y in pts:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=house_color)

    for fx, fy in FINDERS:
        x0, y0 = fx * s, fy * s
        f = FINDER * s
        draw.rectangle((x0, y0, x0 + f, y0 + f), fill=module_color)
        inset = 0.025 * s
        draw.rectangle((x0 + inset, y0 + inset, x0 + f - inset, y0 + f - inset), fill=house_cutout_color)
        inset2 = 0.045 * s
        draw.rectangle((x0 + inset2, y0 + inset2, x0 + f - inset2, y0 + f - inset2), fill=module_color)
    c = CELL * s
    for mx, my in MODULES:
        draw.rectangle((mx * s, my * s, mx * s + c, my * s + c), fill=module_color)


def gradient(size: int, top, bottom) -> Image.Image:
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = color
    return img


def render(size: int, background: str) -> Image.Image:
    big = size * SUPERSAMPLE
    if background == "light":
        img = gradient(big, CORAL_TOP, CORAL_BOTTOM).convert("RGBA")
        house, module = WHITE + (255,), NAVY + (255,)
        cutout = house
    elif background == "dark":
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        house, module = CORAL + (255,), NAVY + (255,)
        cutout = house
    elif background == "tinted":
        img = Image.new("RGBA", (big, big), (0, 0, 0, 255))
        house, module = (235, 235, 235, 255), (60, 60, 60, 255)
        cutout = house
    else:
        raise ValueError(background)
    draw_motif(ImageDraw.Draw(img), big, house, module, cutout)
    return img.resize((size, size), Image.LANCZOS)


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    # L'icône App Store ne doit pas contenir de transparence : on aplatit en RGB.
    render(1024, "light").convert("RGB").save(ICONSET / "AppIcon-1024.png", optimize=True)
    render(1024, "dark").save(ICONSET / "AppIcon-1024-dark.png", optimize=True)
    render(1024, "tinted").convert("RGB").save(ICONSET / "AppIcon-1024-tinted.png", optimize=True)

    render(512, "light").convert("RGB").save(DOCS / "icon-512.png", optimize=True)
    render(180, "light").convert("RGB").save(DOCS / "apple-touch-icon.png", optimize=True)

    try:
        import qrcode
    except ImportError:
        print("qrcode non installé : QR de démonstration non généré")
    else:
        qr = qrcode.QRCode(border=4, box_size=16, error_correction=qrcode.constants.ERROR_CORRECT_M)
        qr.add_data("APPC-DEMO-BADGE-0001")
        qr.make(fit=True)
        qr.make_image(fill_color="black", back_color="white").save(DOCS / "demo-qr.png")
    print("Icônes générées dans", ICONSET)


if __name__ == "__main__":
    main()
