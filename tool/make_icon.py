"""Draws the app's launcher icon: **Pip** (Round 24, Nikola's pick), an
8-bit pixel robot, in the Clay theme's colours on its dark ground. Since
Round 27 he is his room's idle frame (`lib/widgets/pip_sprites.dart`,
the screen 14 x 9): the same 20-wide grid, the face a pixel right of the
middle as in the room; a test keeps the two the same.

Android 8 and later use the adaptive icon: Clay's dark colour behind
(values/ic_launcher_background.xml) and Pip as a vector in front
(drawable/ic_launcher_foreground.xml, 108 units, Pip 3 units a pixel,
centred), with a one-colour version for themed icons
(drawable/ic_launcher_monochrome.xml, the face cut out). Vectors are
crisp at any size. Older phones use images (mipmap-*/ic_launcher.png,
48 dp, whole device pixels a grid pixel, nearest neighbour only).
Run from the repository root: python3 tool/make_icon.py
"""

from PIL import Image, ImageDraw

RES = 'android/app/src/main/res'

GROUND = (0x14, 0x14, 0x13)  # Clay's dark background
# PipColours (lib/core/theme.dart).
COLOURS = {
    'L': (0xD9, 0x77, 0x57),  # head casing, antenna
    'O': (0xC9, 0x64, 0x42),  # body, feet
    'S': (0xA8, 0x4F, 0x33),  # under the body, feet
    'W': (0xF5, 0xF0, 0xE8),  # screen
    'K': (0x14, 0x14, 0x13),  # eyes, mouth (real pixels, not holes)
    'A': (0xF2, 0xC0, 0x7A),  # the antenna's light
}

# Pip standing (PipFrame.idle), one letter a pixel ('.' is empty).
SPRITE = [
    '.........A..........',
    '.........L..........',
    '...LLLLLLLLLLLLLL...',
    '..LLLLLLLLLLLLLLLL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWKKWWWWWKKWWL..',
    '..LWWWKKWWWWWKKWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWKWWWWKWWWWL..',
    '..LWWWWWKKKKWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LLLLLLLLLLLLLLLL..',
    '...OOOOOOOOOOOOOO...',
    '...SSSSSSSSSSSSSS...',
    '.....OO......OO.....',
    '.....OO......OO.....',
    '.....SS......SS.....',
]

# The drawn part (columns 2-17, all 19 rows), centred in the icon.
LEFT = min(r.find(next(c for c in r if c != '.')) for r in SPRITE)
WIDE = max(len(r.rstrip('.')) for r in SPRITE) - LEFT
TALL = len(SPRITE)


def draw(size, cell, ground, colours=None):
    """The sprite, [cell] px a pixel, centred on a [size] px square;
    [colours] instead of [COLOURS] (None leaves a letter out)."""
    colours = colours or COLOURS
    image = Image.new('RGBA', (size, size), ground)
    left = (size - WIDE * cell) // 2 - LEFT * cell
    top = (size - TALL * cell) // 2
    pen = ImageDraw.Draw(image)
    for y, row in enumerate(SPRITE):
        for x, c in enumerate(row):
            if c == '.' or colours.get(c) is None:
                continue
            pen.rectangle(
                [left + x * cell, top + y * cell,
                 left + (x + 1) * cell - 1, top + (y + 1) * cell - 1],
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
    # Legacy: 48 dp, a rounded square, Pip about 1.6 dp a pixel (whole
    # device pixels).
    legacy = round(48 * scale)
    icon = draw(legacy, max(1, int(1.6 * scale)), GROUND + (255,))
    rounded(icon, round(10 * scale)).save(
        f'{RES}/mipmap-{name}/ic_launcher.png', optimize=True)

# A big one to look at.
draw(512, 24, GROUND + (255,)).save('/tmp/icon_preview.png')


def vector(colours):
    """Pip as a vector drawable for the adaptive icon (Round 27: sharper
    than images, crisp at whatever size the launcher draws it): 108 x 108,
    Pip's pixels as 3-unit squares (48 x 57 units), centred. [colours]
    maps a letter to a colour; letters left out are holes."""
    cell = 3
    left = (108 - WIDE * cell) / 2 - LEFT * cell
    top = (108 - TALL * cell) / 2
    paths = []
    for letter, rgb in colours.items():
        runs = []
        for y, row in enumerate(SPRITE):
            x = 0
            while x < len(row):
                if row[x] != letter:
                    x += 1
                    continue
                start = x
                while x < len(row) and row[x] == letter:
                    x += 1
                runs.append('M%g,%gh%gv%gh%gz' % (
                    left + start * cell, top + y * cell,
                    (x - start) * cell, cell, -(x - start) * cell))
        if runs:
            paths.append(
                '    <path\n'
                '        android:fillColor="#FF%02X%02X%02X"\n'
                '        android:pathData="%s" />' % (rgb + (''.join(runs),)))
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Pip, drawn by tool/make_icon.py: do not edit by hand. -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp"\n'
            '    android:height="108dp"\n'
            '    android:viewportWidth="108"\n'
            '    android:viewportHeight="108">\n' + '\n'.join(paths) +
            '\n</vector>\n')


with open(f'{RES}/drawable/ic_launcher_foreground.xml', 'w') as out:
    out.write(vector(COLOURS))
# Themed icons: one colour, the face cut out.
with open(f'{RES}/drawable/ic_launcher_monochrome.xml', 'w') as out:
    out.write(vector({c: (255, 255, 255) for c in COLOURS if c != 'K'}))
