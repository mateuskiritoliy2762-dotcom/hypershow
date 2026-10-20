"""Desenha os rostos do Hyper direto na textura do modelo 3D (na tela da TV): uma textura por rosto.

Entradas (arte/hyper/):
  textura_base.png        textura original do modelo (exportada do Studio)
  tela_triangulos.txt     triângulos da frente da cabeça: por linha, 3x "x y z u v" (espaço da malha)
Saída: arte/hyper/textura_<rosto>.png (enviar ao Roblox e pôr os IDs em Config.Hyper.FaceTextures e o feliz em tools/build_hyper.luau)

Para cada texel não roxo desses triângulos (tela e moldura laranja, rosto antigo), calcula a posição 3D
e projeta de frente o rosto de arte/rostos/. Assim o rosto acompanha a curva da tela.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HYPER = os.path.join(ROOT, "arte", "hyper")
FACES = {
    "feliz": "Happy", "chocado": "Shocked", "rindo": "Laughing",
    "malvado": "Evil", "contagem": "Countdown", "triste": "Sad",
    "neutro": "Neutral", "irritado": "Irritated", "bravo": "Angry", "furioso": "Furious",
}
EDGE_TOLERANCE = -0.04  # inclui texels na borda dos triângulos (evita riscos laranja nas emendas)
FACE_BOOST = 1.1  # clareia o rosto para compensar a luz roxa do cenário

base = np.array(Image.open(os.path.join(HYPER, "textura_base.png")).convert("RGBA"))
H, W = base.shape[:2]
tris = np.loadtxt(os.path.join(HYPER, "tela_triangulos.txt")).reshape(-1, 3, 5)
pos, uv = tris[:, :, :3], tris[:, :, 3:] * [W, H]


def is_purple(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    return (b > r) & (b > g + 30)


# Retângulo (x, y) da tela: triângulos cuja cor no centro não é roxa.
centers_uv = uv.mean(axis=1).astype(int).clip(0, [W - 1, H - 1])
screen = ~is_purple(base[centers_uv[:, 1], centers_uv[:, 0]])
centers = pos[screen].mean(axis=1)
min_x, max_x = centers[:, 0].min(), centers[:, 0].max()
min_y, max_y = centers[:, 1].min(), centers[:, 1].max()

# Texels a pintar e a posição 3D de cada um (calculado uma vez, vale para todos os rostos).
targets = {}
for (a, b, c), p in zip(uv, pos):
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(den) < 1e-9:
        continue
    x0, x1 = max(0, int(min(a[0], b[0], c[0])) - 1), min(W - 1, int(max(a[0], b[0], c[0])) + 1)
    y0, y1 = max(0, int(min(a[1], b[1], c[1])) - 1), min(H - 1, int(max(a[1], b[1], c[1])) + 1)
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    w1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
    w2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
    w3 = 1 - w1 - w2
    inside = (w1 >= EDGE_TOLERANCE) & (w2 >= EDGE_TOLERANCE) & (w3 >= EDGE_TOLERANCE)
    for px, py, u1, u2, u3 in zip(xs[inside].astype(int), ys[inside].astype(int), w1[inside], w2[inside], w3[inside]):
        targets[(py, px)] = p[0] * u1 + p[1] * u2 + p[2] * u3

keys = [k for k in targets if not is_purple(base[k[0], k[1]][None])[0]]
rows = np.array([k[0] for k in keys])
cols = np.array([k[1] for k in keys])
xyz = np.array([targets[k] for k in keys])
# De frente, o +X da malha fica à esquerda de quem olha.
fu = ((max_x - xyz[:, 0]) / (max_x - min_x)).clip(0, 1)
fv = ((max_y - xyz[:, 1]) / (max_y - min_y)).clip(0, 1)

for file_name, key in FACES.items():
    face = np.array(Image.open(os.path.join(ROOT, "arte", "rostos", f"rosto_{file_name}.png")).convert("RGB"))
    fh, fw = face.shape[:2]
    colors = face[(fv * (fh - 1)).astype(int), (fu * (fw - 1)).astype(int)].astype(float) * FACE_BOOST
    out = base.copy()
    out[rows, cols, :3] = colors.clip(0, 255).astype(np.uint8)
    out[rows, cols, 3] = 255
    Image.fromarray(out).save(os.path.join(HYPER, f"textura_{file_name}.png"))
print(f"{len(keys)} texels pintados por rosto; tela x=[{min_x:.2f}, {max_x:.2f}] y=[{min_y:.2f}, {max_y:.2f}]")
