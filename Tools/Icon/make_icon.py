"""App icon: the goslo radio logo in pixel art, a "G" at the heart of a symmetric sound wave.

64×64 grid scaled ×16 to 1024×1024 (nearest neighbour), opaque and square (iOS rounds
the corners itself). Usage: python3 make_icon.py [output.png]
"""
import sys
from PIL import Image

N = 64
BG, FG = "#0e0e10", "#f5f5f5"
px = [[BG] * N for _ in range(N)]


def fill(x0, y0, x1, y1, c=FG):
    for y in range(max(0, y0), min(N, y1 + 1)):
        for x in range(max(0, x0), min(N, x1 + 1)):
            px[y][x] = c


CY = 32           # the wave is centred on rows 31/32
BAR, GAP = 2, 1   # 2 px bars, 1 px apart
STEP = BAR + GAP

# The G: 9 wide, 20 tall, 2 px strokes, rounded corners, open on the upper right.
GW, GH = 9, 20
gx0, gy0 = (N - GW) // 2, CY - GH // 2
gx1, gy1 = gx0 + GW - 1, gy0 + GH - 1
fill(gx0, gy0 + 2, gx0 + 1, gy1 - 2)          # left side
fill(gx0 + 2, gy0, gx1 - 2, gy0 + 1)          # top
fill(gx0 + 2, gy1 - 1, gx1 - 2, gy1)          # bottom
fill(gx1 - 1, CY - 1, gx1, gy1 - 2)           # right side, lower half only
fill(gx0 + 4, CY - 1, gx1, CY)                # inner bar
for x, y in [(gx0 + 1, gy0 + 1), (gx1 - 1, gy0 + 1), (gx0 + 1, gy1 - 1), (gx1 - 1, gy1 - 1)]:
    px[y][x] = FG                             # round the corners
fill(gx1 - 1, gy0 + 2, gx1, gy0 + 3)          # tip of the G's top hook

# Bars from the G outwards (heights in px), then dots fading into silence.
heights = [14, 10, 16, 8, 4]
dots = 2
for side in (1, -1):
    start = gx1 + 1 + GAP if side == 1 else gx0 - GAP - BAR
    for i, h in enumerate(heights + [2] * dots):
        x = start + side * i * STEP
        top = CY - h // 2
        fill(x, top, x + BAR - 1, top + h - 1)

img = Image.new("RGB", (N, N))
img.putdata([tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for row in px for c in row])
img.resize((1024, 1024), Image.NEAREST).save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
