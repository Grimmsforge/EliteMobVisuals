"""Render the addon's art from tools/art/src/*.svg.

Dev-only: the addon ships the generated TGA files and never needs Python.
Run it after editing an SVG, then commit the outputs.

    python tools/art/build-art.py

Needs: pip install cairosvg pillow

Outputs
    media/textures/<name>.tga    128x128 badge textures (greyscale, tinted in game)
    media/textures/end-*.tga     256x256 end pieces, from painted art (tools/art/src/*.webp)
    media/logo/emv-icon-64.tga   compact icon, no wings and padded: minimap button,
                                 addon compartment, TOC IconTexture (addon list)
    media/logo/emv-logo-128.tga  full logo with wings: options window, Settings page
    docs/logo/emv-logo-512.png   CurseForge / README logo
    docs/logo/emv-logo-256.png
    docs/logo/styles-preview.png every bundled style, tinted per classification
    docs/logo/curseforge/emv-curseforge-<size>.png
                                 CurseForge project avatar: the logo on a square
                                 backdrop (curseforge-bg.svg), 1024 master plus
                                 512 and 400; upload the 1024

TGA files are 32-bit uncompressed with a top-left origin, the same encoding as
Epithet's icons, which the client loads without issue.
"""
import io
import pathlib

import cairosvg
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "art" / "src"
TEXTURES = ROOT / "media" / "textures"
LOGO = ROOT / "media" / "logo"
DOCS_LOGO = ROOT / "docs" / "logo"

# Badge textures shipped with the addon. Keep in step with Core/Media.lua.
BADGES = ["badge-wing", "badge-crest", "badge-star", "badge-skull",
          "badge-diamond", "badge-crown", "badge-chevron", "badge-arrow", "glow"]

# End pieces: painted raster art (tools/art/src/<name>.webp), the bar's LEFT
# end, cut out on a transparent background. Converted to greyscale, levelled
# so the brightest metal tints fully, scaled to TEXTURE_END tall and placed at
# the left of a square canvas. Core/Media.lua crops the empty right side away
# with coords = { 0, width / TEXTURE_END, 0, 1 }; the width is printed below.
END_PIECES = ["end-clasp", "end-winged"]
TEXTURE_END = 256
END_WHITE = 190   # source grey that becomes full white (the art's ~90th percentile)

# Default classification colours (Core/Defaults.lua), for the preview sheet.
CLASS_COLOURS = [
    ("Elite", (1.00, 0.82, 0.25)),
    ("Rare Elite", (0.62, 0.86, 1.00)),
    ("Rare", (0.82, 0.84, 0.90)),
    ("Boss", (1.00, 0.36, 0.26)),
]


def render(svg_path: pathlib.Path, size: int) -> Image.Image:
    """Render at 4x then downsample, for clean anti-aliased edges."""
    png = cairosvg.svg2png(url=str(svg_path), output_width=size * 4, output_height=size * 4)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return im.resize((size, size), Image.LANCZOS)


def save_tga(im: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="TGA", orientation=1)  # 1 = top-left origin


def tint(im: Image.Image, rgb) -> Image.Image:
    """Multiply like Texture:SetVertexColor does."""
    r, g, b, a = im.split()
    r = r.point(lambda v: int(v * rgb[0]))
    g = g.point(lambda v: int(v * rgb[1]))
    b = b.point(lambda v: int(v * rgb[2]))
    return Image.merge("RGBA", (r, g, b, a))


def build_end_piece(name: str) -> Image.Image:
    from PIL import ImageOps
    src = Image.open(SRC / f"{name}.webp").convert("RGBA")
    src = src.crop(src.getchannel("A").getbbox())
    grey = ImageOps.grayscale(src.convert("RGB")).point(lambda v: min(255, v * 255 // END_WHITE))
    art = Image.merge("RGBA", (grey, grey, grey, src.getchannel("A")))
    width = round(art.width * TEXTURE_END / art.height)
    art = art.resize((width, TEXTURE_END), Image.LANCZOS)
    canvas = Image.new("RGBA", (TEXTURE_END, TEXTURE_END), (0, 0, 0, 0))
    canvas.alpha_composite(art, (0, 0))
    save_tga(canvas, TEXTURES / f"{name}.tga")
    print(f"  media/textures/{name}.tga  (art width {width} of {TEXTURE_END})")
    return art


def build_preview(rendered: dict) -> None:
    names = [n for n in BADGES if n != "glow"] + END_PIECES
    cell, pad = 72, 12
    w = pad + len(CLASS_COLOURS) * (cell + pad)
    h = pad + len(names) * (cell + pad)
    sheet = Image.new("RGBA", (w, h), (24, 22, 28, 255))
    for row, name in enumerate(names):
        art = rendered[name]
        w = round(cell * art.width / art.height)
        base = art.resize((w, cell), Image.LANCZOS)
        for col, (_, rgb) in enumerate(CLASS_COLOURS):
            sheet.alpha_composite(tint(base, rgb), (pad + col * (cell + pad) + (cell - w) // 2, pad + row * (cell + pad)))
    DOCS_LOGO.mkdir(parents=True, exist_ok=True)
    sheet.save(DOCS_LOGO / "styles-preview.png")


def render_at(svg_path: pathlib.Path, size: int, oversample: int = 2) -> Image.Image:
    png = cairosvg.svg2png(url=str(svg_path), output_width=size * oversample, output_height=size * oversample)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return im.resize((size, size), Image.LANCZOS)


# CurseForge shows the avatar in a rounded square, from a large tile down to a
# small list icon. The wings make the logo wide, so it is sized by its art's
# width and centred on the art's own bounds, with a margin the rounded
# corners and a small-size downscale can't touch.
CF_SIZES = (1024, 512, 400)
CF_ART_WIDTH = 0.90   # the logo's art spans this share of the width


def build_curseforge() -> None:
    out = DOCS_LOGO / "curseforge"
    out.mkdir(parents=True, exist_ok=True)
    master_size = CF_SIZES[0]
    canvas = render_at(SRC / "curseforge-bg.svg", master_size)

    logo = render_at(SRC / "logo.svg", 2048)
    art = logo.crop(logo.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    width = round(master_size * CF_ART_WIDTH)
    height = round(art.height * width / art.width)
    art = art.resize((width, height), Image.LANCZOS)

    # A soft shadow under the emblem lifts it off the backdrop.
    shadow = Image.new("RGBA", art.size, (0, 0, 0, 0))
    shadow.putalpha(art.getchannel("A").point(lambda v: int(v * 0.55)))
    from PIL import ImageFilter
    shadow = shadow.filter(ImageFilter.GaussianBlur(master_size / 90))

    x, y = (master_size - width) // 2, (master_size - height) // 2
    canvas.alpha_composite(shadow, (x, y + master_size // 120))
    canvas.alpha_composite(art, (x, y))

    final = canvas.convert("RGB")   # opaque: no surprises on light or dark themes
    for size in CF_SIZES:
        im = final if size == master_size else final.resize((size, size), Image.LANCZOS)
        path = out / f"emv-curseforge-{size}.png"
        im.save(path, optimize=True)
        print(f"  docs/logo/curseforge/{path.name}")


def main() -> None:
    rendered = {}
    for name in BADGES:
        im = render(SRC / f"{name}.svg", 128)
        rendered[name] = im
        save_tga(im, TEXTURES / f"{name}.tga")
        print(f"  media/textures/{name}.tga")

    for name in END_PIECES:
        rendered[name] = build_end_piece(name)

    logo_svg = SRC / "logo.svg"
    save_tga(render(logo_svg, 128), LOGO / "emv-logo-128.tga")
    print("  media/logo/emv-logo-128.tga")
    save_tga(render(SRC / "icon.svg", 64), LOGO / "emv-icon-64.tga")
    print("  media/logo/emv-icon-64.tga")
    DOCS_LOGO.mkdir(parents=True, exist_ok=True)
    for size in (512, 256):
        render(logo_svg, size).save(DOCS_LOGO / f"emv-logo-{size}.png")
        print(f"  docs/logo/emv-logo-{size}.png")

    build_preview(rendered)
    print("  docs/logo/styles-preview.png")

    build_curseforge()


if __name__ == "__main__":
    main()
