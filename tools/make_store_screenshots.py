#!/usr/bin/env python3
"""Met en forme les captures brutes du simulateur pour l'App Store (iPhone 6,9", 1320 x 2868).

Usage : python3 tools/make_store_screenshots.py <dossier des captures brutes>
Les captures brutes viennent du workflow « Captures App Store » (artefact captures-app-store).
Résultat : AppStore/captures/*.png (RVB, sans transparence, comme l'exige App Store Connect).
Dépendances : Pillow et la police Inter (apt install fonts-inter).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "AppStore" / "captures"
WIDTH, HEIGHT = 1320, 2868
NAVY_TOP, NAVY_BOTTOM = (34, 48, 90), (22, 31, 61)
CORAL_LIGHT = (255, 176, 150)
FONT_DIR = Path("/usr/share/fonts/opentype/inter")

# En France, l'app Apple Wallet s'appelle « Cartes » : on cite les deux noms.
SLIDES = [
    ("badge", "Votre badge crèche dans l'app Cartes", "Apple Wallet : il s'affiche tout seul quand vous arrivez"),
    ("editor", "Votre crèche, trouvée autour de vous", "Ou choisissez-la parmi toutes les crèches de Paris"),
    ("about", "Vos données restent sur votre iPhone", "QR code, nom de l'enfant et position ne sont jamais envoyés"),
    ("welcome", "Gratuit, sans compte, sans publicité", "Une initiative de l'association Parents à Paris Centre"),
]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def greedy_wrap(draw: ImageDraw.ImageDraw, text: str, typeface, max_width: float) -> list[str]:
    lines, current = [], ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if not current or draw.textlength(candidate, font=typeface) <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def wrap(draw: ImageDraw.ImageDraw, text: str, typeface, max_width: int) -> list[str]:
    """Même nombre de lignes qu'un retour à la ligne classique, mais des lignes de longueur équilibrée."""
    count = len(greedy_wrap(draw, text, typeface, max_width))
    low, high = 0.0, float(max_width)
    while high - low > 1:
        middle = (low + high) / 2
        if len(greedy_wrap(draw, text, typeface, middle)) <= count:
            high = middle
        else:
            low = middle
    return greedy_wrap(draw, text, typeface, high)


def background() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        draw.line([(0, y), (WIDTH, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM)))
    return image


def compose(raw: Image.Image, title: str, subtitle: str) -> Image.Image:
    canvas = background()
    draw = ImageDraw.Draw(canvas)
    title_font = font("InterDisplay-Bold.otf", 96)
    subtitle_font = font("Inter-Medium.otf", 50)

    y = 150
    for line in wrap(draw, title, title_font, WIDTH - 160):
        draw.text((WIDTH / 2, y), line, font=title_font, fill="white", anchor="mt")
        y += 112
    y += 22
    for line in wrap(draw, subtitle, subtitle_font, WIDTH - 200):
        draw.text((WIDTH / 2, y), line, font=subtitle_font, fill=CORAL_LIGHT, anchor="mt")
        y += 64

    shot_width = 1040
    shot_height = round(raw.height * shot_width / raw.width)
    top = max(y + 70, HEIGHT - shot_height - 60)
    left = (WIDTH - shot_width) // 2
    radius = 78

    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + 24, left + shot_width, top + shot_height + 24), radius, fill=150
    )
    canvas.paste((8, 12, 28), mask=shadow.filter(ImageFilter.GaussianBlur(40)))

    mask = Image.new("L", (shot_width, shot_height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot_width - 1, shot_height - 1), radius, fill=255)
    canvas.paste(raw.convert("RGB").resize((shot_width, shot_height), Image.LANCZOS), (left, top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, top, left + shot_width, top + shot_height), radius, outline=(255, 255, 255), width=3
    )
    return canvas


def main():
    raw_dir = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (scene, title, subtitle) in enumerate(SLIDES, start=1):
        source = raw_dir / f"{scene}.png"
        if not source.exists():
            print("absente :", source)
            continue
        result = compose(Image.open(source), title, subtitle)
        target = OUT / f"{index:02d}-{scene}.png"
        result.save(target, optimize=True)
        print(target, result.size)


if __name__ == "__main__":
    main()
