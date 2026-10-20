"""Gera o medidor de paciência no estilo neon futurista (arte/cenario/medidor_neon*.png).

Mesma geometria do tools/make_meter.py (centro no meio da borda de baixo, mesmos raios), então o ponteiro e o
vidro continuam alinhados: vidro escuro, 5 faixas translúcidas com contorno neon brilhante, carinhas acesas,
aro duplo com lâmpadas e miolo com anel ciano. Sai em 2048 x 1024, cortado em duas metades de 1024.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4
W, H = 1024 * SS, 512 * SS
CX, CY = W // 2, H - 8 * SS
R = 500 * SS
LEVELS = [(63, 169, 245), (57, 211, 83), (255, 210, 63), (255, 138, 61), (255, 59, 59)]
GOLD = (255, 200, 61)
MAGENTA = (255, 61, 200)
CYAN = (53, 200, 255)
r_band = R - 34 * SS
r_hub = 170 * SS


def polar(r, deg):
    a = math.radians(deg)
    return CX + r * math.cos(a), CY - r * math.sin(a)


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def glow(img, radius):
    return img.filter(ImageFilter.GaussianBlur(radius))


base = layer()
d = ImageDraw.Draw(base)
# vidro escuro
d.pieslice((CX - R, CY - R, CX + R, CY + R), 180, 360, fill=(18, 10, 42, 245))
# faixas translúcidas
for i, color in enumerate(LEVELS):
    start = 180 + i * 36
    d.pieslice((CX - r_band, CY - r_band, CX + r_band, CY + r_band), start, start + 36, fill=color + (95,))
# miolo escuro
d.pieslice((CX - r_hub, CY - r_hub, CX + r_hub, CY + r_hub), 180, 360, fill=(10, 6, 26, 255))

# linhas neon (desenhadas numa camada, depois brilho borrado + traço nítido por cima)
lines = layer()
ld = ImageDraw.Draw(lines)
for i, color in enumerate(LEVELS):
    start = 180 + i * 36
    inset = 14 * SS
    rb = r_band - inset
    ld.arc((CX - rb, CY - rb, CX + rb, CY + rb), start + 1.5, start + 36 - 1.5, fill=color + (255,), width=9 * SS)
    rh = r_hub + inset
    ld.arc((CX - rh, CY - rh, CX + rh, CY + rh), start + 3, start + 36 - 3, fill=color + (255,), width=7 * SS)
    for edge in (start + 2.2, start + 36 - 2.2):
        deg = -edge  # ângulo do PIL (horário) para matemático
        p0 = polar(rh, deg)
        p1 = polar(rb, deg)
        ld.line((p0, p1), fill=color + (255,), width=7 * SS)
# aro duplo
for rr, color, width in ((R - 6 * SS, GOLD, 12 * SS), (R - 26 * SS, MAGENTA, 7 * SS)):
    ld.arc((CX - rr, CY - rr, CX + rr, CY + rr), 180, 360, fill=color + (255,), width=width)
# miolo: anel ciano
ld.arc((CX - r_hub, CY - r_hub, CX + r_hub, CY + r_hub), 180, 360, fill=CYAN + (255,), width=10 * SS)
# base reta
ld.line(((CX - R, CY), (CX + R, CY)), fill=GOLD + (255,), width=10 * SS)

# lâmpadas no aro
bulbs = layer()
bd = ImageDraw.Draw(bulbs)
for k in range(31):
    deg = 180 - k * 6
    x, y = polar(R - 16 * SS, deg)
    rb = 7 * SS
    bd.ellipse((x - rb, y - rb, x + rb, y + rb), fill=(255, 240, 200, 255))


def face(draw, cx, cy, s, level, color):
    ink = (20, 10, 40, 255)
    lw = max(4, int(s * 0.12))
    light = tuple(min(255, int(c * 0.55 + 255 * 0.45)) for c in color)
    draw.ellipse((cx - s, cy - s, cx + s, cy + s), fill=light + (255,), outline=(255, 255, 255, 255), width=lw)
    ex, ey, er = s * 0.38, s * 0.18, s * 0.13
    for sx in (-1, 1):
        draw.ellipse((cx + sx * ex - er, cy - ey - er, cx + sx * ex + er, cy - ey + er), fill=ink)
    if level >= 3:
        for sx in (-1, 1):
            draw.line((cx + sx * s * 0.62, cy - s * 0.55, cx + sx * s * 0.18, cy - s * 0.32), fill=ink, width=lw)
    my = cy + s * 0.38
    if level == 0:
        draw.chord((cx - s * 0.5, my - s * 0.45, cx + s * 0.5, my + s * 0.25), 0, 180, fill=ink)
    elif level == 1:
        draw.arc((cx - s * 0.45, my - s * 0.45, cx + s * 0.45, my + s * 0.15), 20, 160, fill=ink, width=lw)
    elif level == 2:
        draw.line((cx - s * 0.4, my, cx + s * 0.4, my), fill=ink, width=lw)
    elif level == 3:
        draw.arc((cx - s * 0.42, my - s * 0.05, cx + s * 0.42, my + s * 0.45), 200, 340, fill=ink, width=lw)
    else:
        pts = [(cx - s * 0.5 + k * s * 0.125, my + (s * 0.1 if k % 2 else -s * 0.1)) for k in range(9)]
        draw.line(pts, fill=ink, width=lw, joint="curve")


halos = layer()
hd = ImageDraw.Draw(halos)
faces = layer()
fd = ImageDraw.Draw(faces)
r_face = (r_band + r_hub) / 2
for i, color in enumerate(LEVELS):
    deg = 180 - (i + 0.5) * 36
    fx, fy = polar(r_face, deg)
    s = 62 * SS
    hd.ellipse((fx - s * 1.25, fy - s * 1.25, fx + s * 1.25, fy + s * 1.25), fill=color + (255,))
    face(fd, fx, fy, s, i, color)

img = base
img = Image.alpha_composite(img, glow(lines, 18 * SS))
img = Image.alpha_composite(img, glow(lines, 6 * SS))
img = Image.alpha_composite(img, lines)
img = Image.alpha_composite(img, glow(bulbs, 6 * SS))
img = Image.alpha_composite(img, bulbs)
img = Image.alpha_composite(img, glow(halos, 14 * SS))
img = Image.alpha_composite(img, faces)

out = img.resize((W // SS, H // SS), Image.LANCZOS)
out.save(os.path.join(ROOT, "arte", "cenario", "medidor_neon.png"))
hi = img.resize((2048, 1024), Image.LANCZOS)
for name, box in (("medidor_neon_esq.png", (0, 0, 1024, 1024)), ("medidor_neon_dir.png", (1024, 0, 2048, 1024))):
    hi.crop(box).save(os.path.join(ROOT, "arte", "cenario", name))
print("ok")
