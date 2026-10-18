#!/usr/bin/env python3
"""Carrousel Instagram (4:5, 1080 x 1350) à partir des captures brutes du simulateur.

Usage : python3 tools/make_instagram_carousel.py [dossier des captures brutes]
Par défaut : AppStore/raw (mis à jour par le workflow « Captures App Store »).
Résultat : AppStore/instagram/01-badge.jpg … 04-welcome.jpg.
Dépendances : Pillow et la police Inter (apt install fonts-inter).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_store_screenshots import CORAL_LIGHT, NAVY_BOTTOM, NAVY_TOP, font, wrap

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "AppStore" / "instagram"
ICON = ROOT / "App" / "BadgeCreche" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
WIDTH, HEIGHT = 1080, 1350
# La grille du profil recadre en 3:4 : rien d'important à moins de 34 px des bords latéraux.
MARGIN = 72
SHOT_WIDTH = 620
# Même position de l'iPhone sur toutes les diapositives, pour un défilement régulier.
SHOT_TOP = 516
MUTED = (178, 188, 214)

# (capture, titre, sous-titre, début du cadrage en pixels de la capture brute ; None = bas de l'écran)
# Un « \n » dans le titre force le retour à la ligne.
SLIDES = [
    ("badge", "Le badge de la crèche, toujours sur votre iPhone",
     "Rangé dans l'app Cartes (Apple Wallet), il s'affiche tout seul en arrivant à la crèche.", 0),
    ("editor", "Votre crèche, trouvée en un geste",
     "Les 3 plus proches vous sont proposées, et toutes les crèches de Paris sont dans la liste.", 0),
    ("about", "Vos données restent\nsur votre iPhone",
     "QR code, nom de l'enfant, position : rien n'est envoyé. L'APPC n'y a jamais accès.", None),
    ("welcome", "Gratuit, sans compte\net sans publicité",
     "Une initiative bénévole de l'association Parents à Paris Centre (APPC).", 0),
]


def background() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        draw.line([(0, y), (WIDTH, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM)))
    return image


def rounded(image: Image.Image, side: int, radius: int) -> tuple[Image.Image, Image.Image]:
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, side - 1, side - 1), radius, fill=255)
    return image.convert("RGB").resize((side, side), Image.LANCZOS), mask


def brand(canvas: Image.Image, corner_text: str) -> None:
    draw = ImageDraw.Draw(canvas)
    side = 64
    icon, mask = rounded(Image.open(ICON), side, 15)
    canvas.paste(icon, (MARGIN, 60), mask)
    draw.text((MARGIN + side + 18, 62), "Badge Crèche", font=font("Inter-SemiBold.otf", 30), fill="white")
    draw.text((MARGIN + side + 18, 99), "par l'APPC", font=font("Inter-Medium.otf", 24), fill=MUTED)
    draw.text((WIDTH - MARGIN, 92), corner_text, font=font("Inter-Medium.otf", 28), fill=MUTED, anchor="rm")


def compose(raw: Image.Image, title: str, subtitle: str, offset: int | None, corner_text: str) -> Image.Image:
    canvas = background()
    brand(canvas, corner_text)
    draw = ImageDraw.Draw(canvas)
    title_font = font("InterDisplay-Bold.otf", 72)
    subtitle_font = font("Inter-Medium.otf", 38)

    y = 176
    for paragraph in title.split("\n"):
        for line in wrap(draw, paragraph, title_font, WIDTH - 2 * MARGIN):
            draw.text((MARGIN, y), line, font=title_font, fill="white")
            y += 84
    y += 18
    for line in wrap(draw, subtitle, subtitle_font, WIDTH - 2 * MARGIN):
        draw.text((MARGIN, y), line, font=subtitle_font, fill=CORAL_LIGHT)
        y += 50

    # Fenêtre de l'iPhone, qui déborde en bas de l'image.
    top = SHOT_TOP
    if y + 30 > top:
        raise SystemExit(f"Texte trop long pour la diapositive : {title!r}")
    scale = SHOT_WIDTH / raw.width
    visible = round((HEIGHT - top) / scale)
    if offset is None:  # cadrage sur le bas de l'écran
        offset = raw.height - visible
    crop = raw.convert("RGB").crop((0, offset, raw.width, offset + visible))
    shot = crop.resize((SHOT_WIDTH, HEIGHT - top), Image.LANCZOS)
    left = (WIDTH - SHOT_WIDTH) // 2
    radius = 40

    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((left, top + 16, left + SHOT_WIDTH, HEIGHT + radius), radius, fill=150)
    canvas.paste((8, 12, 28), mask=shadow.filter(ImageFilter.GaussianBlur(30)))

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SHOT_WIDTH - 1, shot.height + radius), radius, fill=255)
    canvas.paste(shot, (left, top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, top, left + SHOT_WIDTH, HEIGHT + radius), radius, outline=(255, 255, 255), width=3
    )
    return canvas


def main():
    raw_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "AppStore" / "raw"
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (scene, title, subtitle, offset) in enumerate(SLIDES, start=1):
        source = raw_dir / f"{scene}.png"
        if not source.exists():
            print("absente :", source)
            continue
        corner_text = "Glissez →" if index == 1 else f"{index}/{len(SLIDES)}"
        result = compose(Image.open(source), title, subtitle, offset, corner_text)
        target = OUT / f"{index:02d}-{scene}.jpg"
        result.save(target, quality=95, optimize=True)
        print(target, result.size)


if __name__ == "__main__":
    main()
