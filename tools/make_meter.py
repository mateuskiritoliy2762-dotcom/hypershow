"""Gera arte/cenario/medidor.png: mostrador semicircular do humor do Hyper (5 faixas com rostos).

Da esquerda (muito feliz, azul) para a direita (furioso, vermelho). O centro do semicírculo
fica no meio da borda de baixo da imagem; o ponteiro é uma peça separada no Studio.
"""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling (desenha em 4096 px; salva em 1024 e em duas metades de 1024 = 2048 px)
W, H = 1024 * SS, 512 * SS
CX, CY = W // 2, H - 8 * SS
R = 500 * SS
LEVELS = ["#3FA9F5", "#39D353", "#FFD23F", "#FF8A3D", "#FF3B3B"]
DARK = "#1B1730"
GOLD = "#FFC83D"

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def polar(r, deg):
    a = math.radians(deg)
    return CX + r * math.cos(a), CY - r * math.sin(a)


# moldura dourada e fundo escuro
d.pieslice((CX - R, CY - R, CX + R, CY + R), 180, 360, fill=GOLD)
r_in = R - 22 * SS
d.pieslice((CX - r_in, CY - r_in, CX + r_in, CY + r_in), 180, 360, fill=DARK)
# 5 faixas coloridas (180° a 0°, da esquerda para a direita)
r_band = R - 34 * SS
for i, color in enumerate(LEVELS):
    start = 180 + i * 36  # ângulos do PIL crescem no sentido horário a partir do eixo x
    d.pieslice((CX - r_band, CY - r_band, CX + r_band, CY + r_band), start, start + 36, fill=color, outline=DARK, width=8 * SS)
# miolo escuro (onde fica o eixo do ponteiro)
r_hub = 170 * SS
d.pieslice((CX - r_hub, CY - r_hub, CX + r_hub, CY + r_hub), 180, 360, fill=DARK)
d.arc((CX - r_hub, CY - r_hub, CX + r_hub, CY + r_hub), 180, 360, fill=GOLD, width=10 * SS)


def face(cx, cy, s, level):
    ink = DARK
    lw = max(4, int(s * 0.12))
    d.ellipse((cx - s, cy - s, cx + s, cy + s), fill="#F7F3FF", outline=ink, width=lw)
    ex, ey, er = s * 0.38, s * 0.18, s * 0.13
    for sx in (-1, 1):
        d.ellipse((cx + sx * ex - er, cy - ey - er, cx + sx * ex + er, cy - ey + er), fill=ink)
    if level >= 3:  # sobrancelhas bravas
        for sx in (-1, 1):
            d.line((cx + sx * s * 0.62, cy - s * 0.55, cx + sx * s * 0.18, cy - s * 0.32), fill=ink, width=lw)
    my = cy + s * 0.38
    if level == 0:
        d.chord((cx - s * 0.5, my - s * 0.45, cx + s * 0.5, my + s * 0.25), 0, 180, fill=ink)
    elif level == 1:
        d.arc((cx - s * 0.45, my - s * 0.45, cx + s * 0.45, my + s * 0.15), 20, 160, fill=ink, width=lw)
    elif level == 2:
        d.line((cx - s * 0.4, my, cx + s * 0.4, my), fill=ink, width=lw)
    elif level == 3:
        d.arc((cx - s * 0.42, my - s * 0.05, cx + s * 0.42, my + s * 0.45), 200, 340, fill=ink, width=lw)
    else:  # boca de dentes cerrados
        pts = []
        for k in range(9):
            pts.append((cx - s * 0.5 + k * s * 0.125, my + (s * 0.1 if k % 2 else -s * 0.1)))
        d.line(pts, fill=ink, width=lw, joint="curve")


r_face = (r_band + r_hub) / 2
for i in range(5):
    deg = 180 - (i + 0.5) * 36  # centro da faixa, ângulo matemático (anti-horário)
    fx, fy = polar(r_face, deg)
    face(fx, fy, 62 * SS, i)

out = img.resize((W // SS, H // SS), Image.LANCZOS)
path = os.path.join(ROOT, "arte", "cenario", "medidor.png")
out.save(path)
print("salvo:", path)
# Versão em alta: 2048x1024 cortada em duas metades (o Roblox aceita no máximo 1024 px por imagem).
hi = img.resize((2048, 1024), Image.LANCZOS)
for name, box in (("medidor_esq.png", (0, 0, 1024, 1024)), ("medidor_dir.png", (1024, 0, 2048, 1024))):
    half_path = os.path.join(ROOT, "arte", "cenario", name)
    hi.crop(box).save(half_path)
    print("salvo:", half_path)

# Vidro: semicírculo translúcido com dois reflexos diagonais (peça separada, quebra na cena de raiva).
glass = Image.new("RGBA", (W, H), (0, 0, 0, 0))
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).pieslice((CX - r_in, CY - r_in, CX + r_in, CY + r_in), 180, 360, fill=255)
tint = Image.new("RGBA", (W, H), (200, 230, 255, 38))
streaks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(streaks)
for x0, width in ((0.22, 60), (0.34, 26)):
    x = W * x0
    sd.polygon([(x, H), (x + width * SS, H), (x + width * SS + H * 0.9, 0), (x + H * 0.9, 0)], fill=(255, 255, 255, 70))
glass = Image.alpha_composite(tint, streaks)
glass.putalpha(Image.composite(glass.getchannel("A"), Image.new("L", (W, H), 0), mask))
path = os.path.join(ROOT, "arte", "cenario", "medidor_vidro.png")
glass.resize((W // SS, H // SS), Image.LANCZOS).save(path)
print("salvo:", path)

# Vidro quebrado (modo furioso): o mesmo vidro com rachaduras saindo do impacto e tom avermelhado.
import random

random.seed(7)
broken = Image.new("RGBA", (W, H), (255, 90, 90, 30))
bd = ImageDraw.Draw(broken)
impact = polar(r_band * 0.62, 180 - 4.5 * 36)  # sobre o rosto furioso
for k in range(14):
    ang = math.radians(k * (360 / 14) + random.uniform(-10, 10))
    x, y = impact
    length = random.uniform(0.45, 1.0) * R
    pts = [(x, y)]
    steps = 6
    for st in range(steps):
        x += math.cos(ang) * length / steps + random.uniform(-14, 14) * SS
        y += math.sin(ang) * length / steps + random.uniform(-14, 14) * SS
        pts.append((x, y))
    bd.line(pts, fill=(255, 255, 255, 210), width=5 * SS, joint="curve")
for ring in (60, 120, 200):  # anéis de rachadura em volta do impacto
    rr = ring * SS
    bd.arc((impact[0] - rr, impact[1] - rr, impact[0] + rr, impact[1] + rr), 0, 360, fill=(255, 255, 255, 120), width=3 * SS)
bd.ellipse((impact[0] - 22 * SS, impact[1] - 22 * SS, impact[0] + 22 * SS, impact[1] + 22 * SS), fill=(255, 255, 255, 230))
broken.putalpha(Image.composite(broken.getchannel("A"), Image.new("L", (W, H), 0), mask))
path = os.path.join(ROOT, "arte", "cenario", "medidor_vidro_quebrado.png")
broken.resize((W // SS, H // SS), Image.LANCZOS).save(path)
print("salvo:", path)
