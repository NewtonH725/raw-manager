#!/usr/bin/env python3
"""
execution/generate_app_icon.py
Genera l'icona ufficiale dell'applicazione per Android, Linux e Windows
utilizzando esattamente il glifo del diaframma fotografico (Icons.camera_rounded, 0xf612).
Centra matematicamente il glifo sui pixel effettivi (getbbox) per evitare
qualsiasi sbilanciamento verticale dovuto alle metriche interne del font.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = Path(__file__).resolve().parent.parent
FONT_PATH = Path("/home/marco/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf")

def generate_glyph_layer(size: int, glyph_ratio: float = 0.68) -> Image.Image:
    """
    Renderizza il glifo ambra del diaframma ad altissima risoluzione (2048px)
    e lo ritaglia sui suoi pixel effettivi (getbbox) per centrarlo
    matematicamente al millimetro sul canvas di destinazione.
    """
    oversample = 2048
    scratch = Image.new("RGBA", (oversample, oversample), (0, 0, 0, 0))
    draw = ImageDraw.Draw(scratch)

    font = ImageFont.truetype(str(FONT_PATH), 1600)
    char = chr(0xf612)
    amber_color = (255, 193, 7, 255)
    draw.text((200, 200), char, font=font, fill=amber_color)

    # Trova il bounding box esatto dei pixel visibili (ignora le metriche asimmetriche del font)
    bbox = scratch.getbbox()
    if bbox is None:
        raise RuntimeError("Impossibile renderizzare il glifo camera_rounded")

    cropped = scratch.crop(bbox)

    # Calcola la dimensione target mantenendo le proporzioni 1:1
    target_dim = int(round(size * glyph_ratio))
    cw, ch = cropped.size
    if cw >= ch:
        new_w = target_dim
        new_h = int(round(target_dim * (ch / cw)))
    else:
        new_h = target_dim
        new_w = int(round(target_dim * (cw / ch)))

    resized_glyph = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Incolla esattamente al centro matematico del canvas di destinazione
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    out.alpha_composite(resized_glyph, dest=(offset_x, offset_y))
    return out

def generate_composite_icon(size: int, circular: bool = True) -> Image.Image:
    """Renderizza l'icona completa con sfondo scuro (#181818), anello dorato (#FFB300) e petali centrati."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size / 2.0
    radius = size * 0.485

    # 1. Sfondo cerchio scuro concentrico
    bg_color = (24, 24, 24, 255)
    border_color = (255, 179, 0, 255)
    border_width = max(2, int(round(size * 0.025)))

    if circular:
        draw.ellipse(
            [center - radius, center - radius, center + radius, center + radius],
            fill=bg_color,
            outline=border_color,
            width=border_width,
        )
    else:
        draw.rectangle([0, 0, size, size], fill=bg_color)

    # 2. Glifo del diaframma perfettamente centrato rispetto al cerchio
    glyph = generate_glyph_layer(size, glyph_ratio=0.66)
    img.alpha_composite(glyph)

    return img

def main():
    print("=== Generazione Icone Perfettamente Centrate per Android, Linux e Windows ===")
    res_dir = BASE_DIR / "android" / "app" / "src" / "main" / "res"

    # 1. Android Adaptive Icons Foreground (108dp x 108dp canvas, safe zone 72dp = 66.6%)
    # Usando ratio 0.60, i petali riempiono l'area circolare di Pixel Launcher in modo pieno e centrato.
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
        fg = generate_glyph_layer(dim, glyph_ratio=0.60)
        fg.save(target_dir / "ic_launcher_foreground.png")
        print(f"[OK] Android Adaptive Foreground: {folder}/ic_launcher_foreground.png ({dim}x{dim})")

    # 2. Android Legacy & Round Icons
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

    # 3. Master Asset (512x512)
    assets_dir = BASE_DIR / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    master = generate_composite_icon(512, circular=True)
    master.save(assets_dir / "app_icon.png")
    print(f"[OK] Master asset: {assets_dir / 'app_icon.png'}")

    # 4. Linux Desktop Icon (256x256)
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

    print("=== Generazione e centratura completate con successo! ===")

if __name__ == "__main__":
    main()
