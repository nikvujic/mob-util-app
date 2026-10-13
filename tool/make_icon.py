"""Draws the app's launcher icon (Round 23): an 8-bit pixel character of
our own, a small robot in the Clay theme's colours, on its dark ground.

Writes the legacy icons (mipmap-*/ic_launcher.png) and the adaptive icon's
foreground (mipmap-*/ic_launcher_foreground.png; the background is a
colour in values/ic_launcher_background.xml) and its one-colour version
for themed icons (mipmap-*/ic_launcher_monochrome.png). Run from the repository
root: python3 tool/make_icon.py
"""

from PIL import Image, ImageDraw

RES = 'android/app/src/main/res'

GROUND = (0x14, 0x14, 0x13)  # Clay's dark background
COLOURS = {
    'X': (0xC9, 0x64, 0x42),  # body: Clay's accent
    'L': (0xD9, 0x77, 0x57),  # light edge
    'S': (0xA8, 0x4F, 0x33),  # shade
    'W': (0xF5, 0xF0, 0xE8),  # eye white
    'P': (0x14, 0x14, 0x13),  # pupil
    'M': (0x3A, 0x1E, 0x14),  # mouth
    'A': (0xF2, 0xC0, 0x7A),  # antenna light
}

# 14 x 14, one letter a pixel ('.' is empty).
SPRITE = [
    '......AA......',
    '......AA......',
    '......XX......',
    '..LLLLLLLLLL..',
    '.LXXXXXXXXXXS.',
    '.LXWWWXXWWWXS.',
    '.LXWWPXXWWPXS.',
    '.LXWWPXXWWPXS.',
    '.LXXXXXXXXXXS.',
    '.LXXMMMMMMXXS.',
    '.LXXXMMMMXXXS.',
    '..SSSSSSSSSS..',
    '...XX....XX...',
    '...SS....SS...',
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
    # Legacy: 48 dp, a rounded square, the sprite at 28 dp.
    legacy = round(48 * scale)
    icon = draw(legacy, round(28 * scale), GROUND + (255,))
    rounded(icon, round(10 * scale)).save(
        f'{RES}/mipmap-{name}/ic_launcher.png', optimize=True)
    # Adaptive: 108 dp, the safe circle is 66 dp; the sprite at 48 dp.
    full = round(108 * scale)
    draw(full, round(48 * scale), (0, 0, 0, 0)).save(
        f'{RES}/mipmap-{name}/ic_launcher_foreground.png', optimize=True)

    # Themed icons (Android 13): one colour, the eyes and mouth cut out.
    white = (255, 255, 255)
    mono = {c: (None if c in 'WPM' else white) for c in COLOURS}
    draw(full, round(48 * scale), (0, 0, 0, 0), mono).save(
        f'{RES}/mipmap-{name}/ic_launcher_monochrome.png', optimize=True)

# A big one to look at.
draw(512, 336, GROUND + (255,)).save('/tmp/icon_preview.png')
