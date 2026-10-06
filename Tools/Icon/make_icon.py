"""App icon: machine n° 4 from the goslo records laundromat, a mic behind its porthole.

Pixel art on a 64×64 grid, scaled ×16 to 1024×1024 (nearest neighbour), same palette as
UI/Pixel/TileArt.swift. Usage: python3 make_icon.py [output.png]
"""
import sys
from PIL import Image

N = 64
BG = "#0e0e10"
BODY, BODY_SHADE, BODY_DARK = "#ececf0", "#c8c8d0", "#9a9aa6"
RING, RING_DARK = "#9aa3b0", "#5d6470"
GLASS, WATER, WATER_DARK, SHINE = "#4f7fa0", "#3d6584", "#2c4d66", "#a9c7dc"
NEON, NEON_DARK = "#ff4d2e", "#b8321c"
MIC, MIC_GRILL, MIC_SHINE, HANDLE = "#2a2a30", "#4a4a55", "#8a8a96", "#18181c"

px = [[BG] * N for _ in range(N)]


def fill(x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(N, y1 + 1)):
        for x in range(max(0, x0), min(N, x1 + 1)):
            px[y][x] = c


def disc(cx, cy, r, c, cond=lambda x, y: True):
    for y in range(N):
        for x in range(N):
            if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r and cond(x, y):
                px[y][x] = c


# Body with rounded corners, shading on the right, feet.
fill(11, 7, 52, 56, BODY)
fill(49, 7, 52, 56, BODY_SHADE)
fill(11, 54, 52, 56, BODY_SHADE)
for x, y in [(11, 7), (52, 7), (11, 56), (52, 56)]:
    px[y][x] = BG
fill(14, 57, 17, 58, BODY_DARK)
fill(46, 57, 49, 58, BODY_DARK)

# Control panel: the red "4" plate, a dial, the neon power light.
fill(12, 8, 51, 17, BODY_SHADE)
fill(12, 18, 51, 18, RING)
fill(14, 9, 23, 17, NEON)
fill(14, 17, 23, 17, NEON_DARK)
FOUR = ["...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X."]
for j, row in enumerate(FOUR):
    for i, ch in enumerate(row):
        if ch == "X":
            px[10 + j][16 + i] = "#ffffff"
disc(41, 13, 3.4, RING_DARK)
disc(41, 13, 2.4, RING)
fill(41, 10, 41, 12, MIC)
fill(47, 11, 48, 12, NEON)
fill(26, 12, 35, 13, BODY_DARK)

# Porthole: steel ring, dark gasket, glass, water line.
CX, CY = 32, 37
disc(CX, CY, 16, RING_DARK)
disc(CX, CY, 15, RING)
disc(CX, CY, 12.6, RING_DARK)
disc(CX, CY, 11.6, GLASS)
disc(CX, CY, 11.6, WATER, lambda x, y: y >= CY + 2)
disc(CX, CY, 11.6, WATER_DARK, lambda x, y: y >= CY + 7)
# Glass shine, top left.
for x, y in [(25, 31), (26, 30), (27, 29), (28, 28), (25, 32), (29, 28)]:
    px[y][x] = SHINE

# The mic, standing in the drum.
disc(CX, 33, 4.6, MIC)
for y in range(30, 37):
    for x in range(28, 37):
        if px[y][x] == MIC and (x + y) % 2 == 0:
            px[y][x] = MIC_GRILL
px[30][30] = MIC_SHINE
px[31][29] = MIC_SHINE
fill(28, 37, 36, 37, NEON)
fill(31, 38, 33, 45, HANDLE)
fill(30, 46, 34, 46, HANDLE)

# Bubbles in the water.
for x, y in [(25, 42), (38, 41), (37, 44), (27, 45), (40, 38)]:
    px[y][x] = SHINE

# Door handle.
fill(48, 33, 49, 41, BODY_DARK)

img = Image.new("RGB", (N, N))
img.putdata([tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for row in px for c in row])
img = img.resize((1024, 1024), Image.NEAREST)
img.save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
