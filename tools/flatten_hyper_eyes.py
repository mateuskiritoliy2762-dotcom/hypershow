"""Achata os calombos dos olhos antigos na tela do Hyper (relevo que a IA esculpiu na malha).

Entrada: arte/hyper/hyper_original.obj (malha exportada do Studio, frente do modelo = -Z)
Saída:   arte/hyper/hyper_corpo.obj   (importar no Studio: Início > Importar > Import 3D)

Em cada olho, os pontos que saem da tela são empurrados de volta até a altura mediana
do anel de tela em volta do olho.
"""
import os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "arte", "hyper", "hyper_original.obj")
DST = os.path.join(ROOT, "arte", "hyper", "hyper_corpo.obj")

# Caixas dos olhos no espaço da malha (medidas no mapa de profundidade da tela).
EYES = [((-2.6, -0.75), (3.9, 6.1)), ((0.75, 2.6), (3.9, 6.1))]
RING = 0.8  # largura do anel em volta do olho usado como referência da tela
FRONT_Z = -2.6  # só a frente da cabeça

lines = open(SRC).read().splitlines()
v_rows = [i for i, l in enumerate(lines) if l.startswith("v ")]
V = np.array([[float(x) for x in lines[i].split()[1:]] for i in v_rows])
x, y, z = V.T
front = z < FRONT_Z

n_rows = [i for i, l in enumerate(lines) if l.startswith("vn ")]
N = np.array([[float(x) for x in lines[i].split()[1:]] for i in n_rows])
# normais usadas por cada vértice (índices do OBJ começam em 1)
normals_of = [[] for _ in range(len(V))]
for l in lines:
    if l.startswith("f "):
        for corner in l.split()[1:]:
            vi, _, ni = corner.split("/")
            normals_of[int(vi) - 1].append(int(ni) - 1)

moved = 0
for (x0, x1), (y0, y1) in EYES:
    box = front & (x >= x0) & (x <= x1) & (y >= y0) & (y <= y1)
    ring = front & ~box & (x >= x0 - RING) & (x <= x1 + RING) & (y >= y0 - RING) & (y <= y1 + RING)
    base_z = np.median(z[ring])  # profundidade típica da tela em volta do olho
    bump = box & (z < base_z)  # mais à frente que a tela (frente = -Z)
    z[bump] = base_z
    # a luz no lugar do calombo passa a seguir a tela em volta
    ring_normal = np.mean([N[n] for vi in np.flatnonzero(ring) for n in normals_of[vi]], axis=0)
    ring_normal /= np.linalg.norm(ring_normal)
    for vi in np.flatnonzero(bump):
        for n in normals_of[vi]:
            N[n] = ring_normal
    moved += int(bump.sum())
    print(f"olho x=[{x0}, {x1}]: tela em z={base_z:.3f}, {int(bump.sum())} pontos achatados")

for row, i in enumerate(v_rows):
    lines[i] = f"v {x[row]:.5f} {y[row]:.5f} {z[row]:.5f}"
for row, i in enumerate(n_rows):
    lines[i] = f"vn {N[row][0]:.5f} {N[row][1]:.5f} {N[row][2]:.5f}"
open(DST, "w").write("\n".join(lines) + "\n")
print(f"{moved} pontos movidos -> {DST}")
