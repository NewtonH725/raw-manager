#!/usr/bin/env python3
"""
execution/generate_app_icon.py
Genera l'icona ufficiale dell'applicazione per Android, Linux e Windows
utilizzando esattamente il glifo del diaframma fotografico (Icons.camera_rounded, 0xf612).
Include il supporto completo per Adaptive Icons su Android (API 26+) per eliminare
completamente lo sfondo bianco di sistema e occupare l'intero cerchio dell'icona.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = Path(__file__).resolve().parent.parent
FONT_PATH = Path("/home/marco/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf")

def generate_glyph_layer(size: int, glyph_ratio: float = 0.72) -> Image.Image:
    """Renderizza il glifo ambra del diaframma su sfondo trasparente."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    glyph_size = int(size * glyph_ratio)
    font = ImageFont.truetype(str(FONT_PATH), glyph_size)
    char = chr(0xf612)

    bbox = draw.textbbox((0, 0), char, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (size - w) / 2.0 - bbox[0]
    y = (size - h) / 2.0 - bbox[1]

    # Colore ambra vivido (#FFC107) identico al tema dell'app
    draw.text((x, y), char, font=font, fill=(255, 193, 7, 255))
    return img

def generate_composite_icon(size: int, circular: bool = True) -> Image.Image:
    """Renderizza l'icona completa con sfondo scuro (#181818) ed anello dorato (#FFB300)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size / 2.0
    radius = size * 0.485

    # 1. Sfondo cerchio scuro
    bg_color = (24, 24, 24, 255)
    border_color = (255, 179, 0, 255)
    border_width = max(2, int(size * 0.025))

    if circular:
        draw.ellipse(
            [center - radius, center - radius, center + radius, center + radius],
            fill=bg_color,
            outline=border_color,
            width=border_width,
        )
    else:
        draw.rectangle([0, 0, size, size], fill=bg_color)

    # 2. Glifo del diaframma
    glyph = generate_glyph_layer(size, glyph_ratio=0.68)
    img.alpha_composite(glyph)

    return img

def main():
    print("=== Generazione Icone con Adaptive Icons per Android, Linux e Windows ===")
    res_dir = BASE_DIR / "android" / "app" / "src" / "main" / "res"

    # 1. Android Adaptive Icons Foreground (108dp x 108dp canvas)
    # L'icona del diaframma occupa l'area visibile centrale (72dp su 108dp)
    adaptive_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }

    for folder, dim in adaptive_sizes.items():
        target_dir = res_dir / folder
        target_dir.mkdir(parents=True, exist_ok=True)
        # Ratio 0.70 fa sì che il diaframma riempia pienamente la maschera circolare di Pixel Launcher
        fg = generate_glyph_layer(dim, glyph_ratio=0.70)
        fg.save(target_dir / "ic_launcher_foreground.png")
        print(f"[OK] Android Adaptive Foreground: {folder}/ic_launcher_foreground.png ({dim}x{dim})")

    # 2. Android Legacy Icons (ic_launcher.png e ic_launcher_round.png)
    legacy_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, dim in legacy_sizes.items():
        target_dir = res_dir / folder
        icon = generate_composite_icon(dim, circular=True)
        icon.save(target_dir / "ic_launcher.png")
        icon.save(target_dir / "ic_launcher_round.png")
        print(f"[OK] Android Legacy & Round: {folder}/ic_launcher.png ({dim}x{dim})")

    # 3. Master Asset
    assets_dir = BASE_DIR / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    master = generate_composite_icon(512, circular=True)
    master.save(assets_dir / "app_icon.png")
    print(f"[OK] Master asset: {assets_dir / 'app_icon.png'}")

    # 4. Linux Desktop Icon
    linux_res_dir = BASE_DIR / "linux" / "runner" / "resources"
    if linux_res_dir.exists():
        linux_icon = generate_composite_icon(256, circular=True)
        linux_icon.save(linux_res_dir / "app_icon.png")
        print(f"[OK] Linux resources/app_icon.png (256x256)")

    # 5. Windows Desktop Icon (.ico multi-risoluzione)
    windows_res_dir = BASE_DIR / "windows" / "runner" / "resources"
    if windows_res_dir.exists():
        ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        master.save(windows_res_dir / "app_icon.ico", format="ICO", sizes=ico_sizes)
        print(f"[OK] Windows resources/app_icon.ico (multi-risoluzione 16..256)")

    print("=== Generazione icone completata con successo! ===")

if __name__ == "__main__":
    main()
