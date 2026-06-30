# -*- coding: utf-8 -*-
"""يولّد أيقونة المصحف (quran.ico) بأحجام متعددة."""
from PIL import Image, ImageDraw

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

GREEN_D = (10, 63, 42)
GREEN = (14, 90, 60)
GOLD = (201, 162, 75)
GOLD_L = (230, 205, 150)
CREAM = (250, 246, 232)

# خلفية مربّعة بزوايا دائرية مع تدرّج بسيط (يدوي)
radius = 52
for y in range(S):
    t = y / S
    r = int(GREEN[0] + (GREEN_D[0] - GREEN[0]) * t)
    g = int(GREEN[1] + (GREEN_D[1] - GREEN[1]) * t)
    b = int(GREEN[2] + (GREEN_D[2] - GREEN[2]) * t)
    d.line([(0, y), (S, y)], fill=(r, g, b, 255))

# قناع زوايا دائرية
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, fill=255)
img.putalpha(mask)
d = ImageDraw.Draw(img)

# إطار ذهبي رفيع
d.rounded_rectangle([8, 8, S - 9, S - 9], radius=radius - 8, outline=GOLD, width=4)

# هلال ذهبي بالأعلى (نقتطع قرصاً من قرص)
cx, cy, cr = 122, 60, 28
bg = img.getpixel((cx, cy))  # لون الخلفية لاقتطاع الهلال
d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=GOLD)
d.ellipse([cx - cr + 16, cy - cr - 2, cx + cr + 16, cy + cr - 2], fill=bg)
# نجمة صغيرة بجانب الهلال
sx, sy = 168, 56
d.polygon([(sx, sy - 9), (sx + 3, sy - 2), (sx + 10, sy - 2), (sx + 4, sy + 2),
           (sx + 6, sy + 9), (sx, sy + 5), (sx - 6, sy + 9), (sx - 4, sy + 2),
           (sx - 10, sy - 2), (sx - 3, sy - 2)], fill=GOLD)

# المصحف: صفحتان مفتوحتان
# القاعدة الذهبية (الغلاف)
d.polygon([(40, 150), (128, 128), (216, 150), (216, 205), (128, 188), (40, 205)], fill=GOLD)
# الصفحة اليمنى
d.polygon([(128, 132), (210, 152), (210, 198), (128, 182)], fill=CREAM)
# الصفحة اليسرى
d.polygon([(128, 132), (46, 152), (46, 198), (128, 182)], fill=CREAM)
# الكعب (الوسط)
d.line([(128, 132), (128, 182)], fill=GOLD, width=4)
# أسطر النص
for i, yoff in enumerate((150, 162, 174)):
    d.line([(60, yoff), (120, yoff - 6)], fill=GOLD_L, width=3)
    d.line([(136, yoff - 6), (196, yoff)], fill=GOLD_L, width=3)

sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
out = r"d:\Quran AlKareem\QuranAlKareem.App\quran.ico"
img.save(out, format="ICO", sizes=sizes)
print("saved", out)
