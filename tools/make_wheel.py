"""Gera arte/cenario/roleta.png: roleta do Modificador de Caos, uma fatia por resultado com ícone e nome.

A ordem das fatias TEM que ser a mesma de Config.Wheel.Slices (ReplicatedStorage/Shared/Config.luau):
a fatia 1 fica no topo e as outras seguem no sentido horário. O StageService para a roleta na fatia
do modificador sorteado (ou em SEM CAOS). Os ícones vêm de arte/icones.
"""
import math, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024
C = S // 2
SLICES = [  # (id em Config.Wheel.Slices, texto na fatia, cor, ícone em arte/icones)
    ("Turbo", "TURBO", "#FF9F1C", "icone_turbo"),
    ("LunarGravity", "GRAVIDADE\nLUNAR", "#7B3FE4", "icone_gravidade_lunar"),
    ("SlipperyFloor", "CHÃO\nENSABOADO", "#1FB6FF", "icone_chao_ensaboado"),
    ("BigHead", "CABEÇÃO", "#FF3D8B", "icone_cabecao"),
    ("MeteorShower", "CHUVA DE\nMETEOROS", "#FF5A2E", "icone_chuva_meteoros"),
    ("ReverseControls", "CONTROLES\nINVERTIDOS", "#3D7BFF", "icone_controles_invertidos"),
    ("Blackout", "APAGÃO", "#2B1A6E", "icone_apagao"),
    ("MegaPush", "SUPER\nEMPURRÃO", "#E63FD4", "icone_super_empurrao"),
    ("None", "SEM\nCAOS", "#5B5470", "icone_sem_caos"),
]
N = len(SLICES)
STEP = 360 / N
FONT = ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "impact.ttf"), 30)
ICON = 150  # tamanho do ícone na fatia (px)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
rim = 40
d.ellipse((0, 0, S - 1, S - 1), fill="#FFC83D")
d.ellipse((rim - 10, rim - 10, S - rim + 10, S - rim + 10), fill="#1B1730")
box = (rim, rim, S - rim, S - rim)
for i, (_, _, color, _) in enumerate(SLICES):
    start = -90 - STEP / 2 + i * STEP  # fatia i centrada em -90 + i*STEP (topo = fatia 1)
    d.pieslice(box, start, start + STEP, fill=color, outline="#1B1730", width=10)
# lâmpadas na borda
for k in range(24):
    a = math.radians(k * 15)
    x, y = C + (C - rim / 2) * math.cos(a), C + (C - rim / 2) * math.sin(a)
    d.ellipse((x - 9, y - 9, x + 9, y + 9), fill="#FFF6D5")


def paste_rotated(layer, angle, radius):
    """Cola `layer` no raio dado, girado para ficar reto quando a fatia para no topo."""
    rotated = layer.rotate(-(angle + 90), expand=True, resample=Image.BICUBIC)
    cx = C + radius * math.cos(math.radians(angle))
    cy = C + radius * math.sin(math.radians(angle))
    img.alpha_composite(rotated, (int(cx - rotated.width / 2), int(cy - rotated.height / 2)))


# ícone no meio da fatia e o nome perto da borda
for i, (_, text, _, icon_name) in enumerate(SLICES):
    angle = -90 + i * STEP  # ângulo do centro da fatia (graus, sentido do PIL)
    icon = Image.open(os.path.join(ROOT, "arte", "icones", icon_name + ".png")).convert("RGBA")
    bbox = icon.getbbox()
    if bbox:
        icon = icon.crop(bbox)
    icon.thumbnail((ICON, ICON), Image.LANCZOS)
    paste_rotated(icon, angle, (C - rim) * 0.52)
    layer = Image.new("RGBA", (300, 90), (0, 0, 0, 0))
    ImageDraw.Draw(layer).multiline_text((150, 45), text, font=FONT, fill="white", anchor="mm", align="center",
                                         stroke_width=4, stroke_fill="#1B1730", spacing=0)
    paste_rotated(layer, angle, (C - rim) * 0.83)
# centro com estrela
d = ImageDraw.Draw(img)
d.ellipse((C - 90, C - 90, C + 90, C + 90), fill="#FFC83D", outline="#B8860B", width=10)
pts = []
for k in range(10):
    rr = 72 if k % 2 == 0 else 30
    a = math.radians(-90 + k * 36)
    pts.append((C + rr * math.cos(a), C + rr * math.sin(a)))
d.polygon(pts, fill="#FFF1A8", outline="#B8860B")
out = os.path.join(ROOT, "arte", "cenario", "roleta.png")
img.save(out)
print("salvo:", out)
