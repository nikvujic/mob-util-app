"""Draws the app's launcher icon: **Pip** (Round 24, Nikola's pick), an
8-bit pixel robot on a 16 x 16 grid, in the Clay theme's colours on its
dark ground. Nearest-neighbour only: every grid pixel is a whole number
of device pixels, so the edges stay crisp.

Writes the legacy icons (mipmap-*/ic_launcher.png, 48 dp, a rounded
square, Pip at 2 dp a pixel), the adaptive icon's foreground
(mipmap-*/ic_launcher_foreground.png: 108 dp, Pip at 4 dp a pixel = 64
dp, inside the 66 dp safe zone; the background is a colour in
values/ic_launcher_background.xml) and its one-colour version for themed
icons (mipmap-*/ic_launcher_monochrome.png: the face cut out).
Run from the repository root: python3 tool/make_icon.py
"""

from PIL import Image, ImageDraw

RES = 'android/app/src/main/res'

GROUND = (0x14, 0x14, 0x13)  # Clay's dark background
COLOURS = {
    'L': (0xD9, 0x77, 0x57),  # head casing, antenna
    'O': (0xC9, 0x64, 0x42),  # body, feet
    'W': (0xF5, 0xF0, 0xE8),  # screen
    'K': (0x14, 0x14, 0x13),  # eyes, mouth (real pixels, not holes)
}

# Pip, one letter a pixel ('.' is empty).
SPRITE = [
    '................',
    '.......W........',
    '.......L........',
    '...LLLLLLLLLL...',
    '..LLLLLLLLLLLL..',
    '..LWWWWWWWWWWL..',
    '..LWKKWWWWKKWL..',
    '..LWKKWWWWKKWL..',
    '..LWWWWWWWWWWL..',
    '..LWWKWWWWKWWL..',
    '..LWWWKKKKWWWL..',
    '..LWWWWWWWWWWL..',
    '..LLLLLLLLLLLL..',
    '...OOOOOOOOOO...',
    '...OO......OO...',
    '................',
]


def draw(size, sprite_size, ground, colours=None):
    """The sprite, [sprite_size] px wide, centred on a [size] px square;
    [colours] instead of [COLOURS] (None leaves a letter out)."""
    colours = colours or COLOURS
    image = Image.new('RGBA', (size, size), ground)
    cell = sprite_size / len(SPRITE)
    left = (size - sprite_size) / 2
    top = (size - sprite_size) / 2
    pen = ImageDraw.Draw(image)
    for y, row in enumerate(SPRITE):
        for x, c in enumerate(row):
            if c == '.' or colours.get(c) is None:
                continue
            pen.rectangle(
                [round(left + x * cell), round(top + y * cell),
                 round(left + (x + 1) * cell) - 1,
                 round(top + (y + 1) * cell) - 1],
                fill=colours[c] + (255,),
            )
    return image


def rounded(image, radius):
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.size[0] - 1, image.size[1] - 1], radius, fill=255)
    out = Image.new('RGBA', image.size, (0, 0, 0, 0))
    out.paste(image, (0, 0), mask)
    return out


DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

for name, scale in DENSITIES.items():
    # Legacy: 48 dp, a rounded square, Pip at 2 dp a pixel (32 dp).
    legacy = round(48 * scale)
    icon = draw(legacy, round(32 * scale), GROUND + (255,))
    rounded(icon, round(10 * scale)).save(
        f'{RES}/mipmap-{name}/ic_launcher.png', optimize=True)
    # Adaptive: 108 dp, the safe circle is 66 dp; Pip at 4 dp a pixel.
    full = round(108 * scale)
    draw(full, round(64 * scale), (0, 0, 0, 0)).save(
        f'{RES}/mipmap-{name}/ic_launcher_foreground.png', optimize=True)

    # Themed icons (Android 13): one colour, the eyes and mouth cut out.
    white = (255, 255, 255)
    mono = {c: (None if c == 'K' else white) for c in COLOURS}
    draw(full, round(64 * scale), (0, 0, 0, 0), mono).save(
        f'{RES}/mipmap-{name}/ic_launcher_monochrome.png', optimize=True)

# A big one to look at.
draw(512, 384, GROUND + (255,)).save('/tmp/icon_preview.png')
