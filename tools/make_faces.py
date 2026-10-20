"""Gera os rostos de humor do Hyper em arte/rostos/ (mesmo formato dos outros: tela 344x230).

neutro (amarelo), irritado (laranja), bravo (laranja-avermelhado) e furioso (vermelho, tela avermelhada).
Depois: rodar tools/paint_hyper_faces.py para pintar na textura do modelo.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 344, 230
SS = 4
GOLD = (255, 200, 61)


def screen(tint):
    img = Image.new("RGB", (W * SS, H * SS), tint)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, W * SS - 1, H * SS - 1), radius=34 * SS, outline=GOLD, width=9 * SS)
    return img


def features(draw_fn, color):
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer), color)
    return layer


def compose(tint, draw_fn, color, name):
    base = screen(tint).convert("RGBA")
    layer = features(draw_fn, color)
    glow = layer.filter(ImageFilter.GaussianBlur(10 * SS))
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, layer)
    out = base.convert("RGB").resize((W, H), Image.LANCZOS)
    path = os.path.join(ROOT, "arte", "rostos", f"rosto_{name}.png")
    out.save(path)
    print("salvo:", path)


def s(*v):
    return [x * SS for x in v]


def neutral(d, c):
    for x in (118, 226):
        d.rounded_rectangle(s(x - 13, 70, x + 13, 132), radius=13 * SS, fill=c)
    d.rounded_rectangle(s(132, 160, 212, 174), radius=7 * SS, fill=c)


def brow(d, c, x, sx, lift, width):
    # sobrancelha descendo para o centro do rosto (raiva): ponta de fora alta, de dentro baixa.
    # sx = +1 no olho direito e -1 no esquerdo; x - k*sx fica do lado de dentro (centro do rosto)
    d.line(s(x + 30 * sx, 60 - lift, x - 26 * sx, 84), fill=c, width=width * SS)


def slanted_eye(d, c, x, sx, top, bottom):
    # olho puxado: borda de cima inclinada para o centro
    outer, inner = x + 30 * sx, x - 28 * sx
    d.polygon(s(outer, top, inner, top + 16, x - 6 * sx, bottom), fill=c)


def irritated(d, c):
    for sx, x in ((-1, 118), (1, 226)):
        brow(d, c, x, sx, 0, 13)
        d.rounded_rectangle(s(x - 27, 100, x + 27, 116), radius=8 * SS, fill=c)  # olho meio fechado
    d.arc(s(126, 160, 218, 210), 200, 340, fill=c, width=13 * SS)


def angry(d, c):
    for sx, x in ((-1, 118), (1, 226)):
        brow(d, c, x, sx, 6, 16)
        slanted_eye(d, c, x, sx, 96, 132)
    d.rounded_rectangle(s(116, 152, 228, 198), radius=11 * SS, outline=c, width=11 * SS)
    for x in (144, 172, 200):
        d.line(s(x, 156, x, 194), fill=c, width=8 * SS)


def furious(d, c):
    for sx, x in ((-1, 116), (1, 228)):
        brow(d, c, x, sx, 12, 19)
        slanted_eye(d, c, x, sx, 92, 134)
    teeth = []
    for k in range(9):
        teeth += [(96 + k * 19) * SS, (192 if k % 2 else 156) * SS]
    d.line(teeth, fill=c, width=13 * SS, joint="curve")


compose((14, 12, 20), neutral, (255, 216, 74), "neutro")
compose((16, 11, 14), irritated, (255, 162, 58), "irritado")
compose((22, 10, 10), angry, (255, 106, 42), "bravo")
compose((40, 6, 10), furious, (255, 46, 61), "furioso")
