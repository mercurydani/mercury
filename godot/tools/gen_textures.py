"""Генератор тайлящихся PBR-текстур для двора (альбедо, нормали, шероховатость).

Запуск: python3 godot/tools/gen_textures.py
Результат: godot/assets/textures/<name>_{albedo,normal,rough}.png (512x512).
Альбедо в основном нейтральное: цвет задаётся цветом вершин в Godot.
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(42)


def tile_noise(scale, octaves=5, persistence=0.5, seed=0):
    """Тайлящийся фрактальный шум через периодическую интерполяцию сетки."""
    r = np.random.default_rng(seed)
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = int(scale * 2 ** o)
        cells = max(cells, 1)
        grid = r.random((cells, cells))
        x = np.linspace(0, cells, N, endpoint=False)
        xi = np.floor(x).astype(int)
        xf = x - xi
        xf = xf * xf * (3 - 2 * xf)
        x0, x1 = xi % cells, (xi + 1) % cells
        g00 = grid[np.ix_(x0, x0)]
        g10 = grid[np.ix_(x1, x0)]
        g01 = grid[np.ix_(x0, x1)]
        g11 = grid[np.ix_(x1, x1)]
        fy = xf[:, None]
        fx = xf[None, :]
        v = (g00 * (1 - fy) + g10 * fy) * (1 - fx) + (g01 * (1 - fy) + g11 * fy) * fx
        out += v * amp
        total += amp
        amp *= persistence
    return out / total


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    n = np.stack([-dx, dy, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, albedo, height, rough, strength=4.0, alpha=None):
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(albedo, 0, 1)
    if a.ndim == 2:
        a = np.stack([a] * 3, -1)
    img = (a * 255).astype(np.uint8)
    if alpha is not None:
        img = np.concatenate([img, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)[..., None]], -1)
        Image.fromarray(img, "RGBA").save(os.path.join(OUT, f"{name}_albedo.png"))
    else:
        Image.fromarray(img, "RGB").save(os.path.join(OUT, f"{name}_albedo.png"))
    Image.fromarray(normal_from_height(height, strength), "RGB").save(os.path.join(OUT, f"{name}_normal.png"))
    rough = np.broadcast_to(np.asarray(rough, dtype=float), (N, N))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(OUT, f"{name}_rough.png"))
    print("saved", name)


def dots(count, rmin, rmax, seed):
    r = np.random.default_rng(seed)
    m = np.zeros((N, N))
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(count):
        cx, cy = r.random(2) * N
        rad = r.uniform(rmin, rmax)
        dx = np.minimum(np.abs(xx - cx), N - np.abs(xx - cx))
        dy = np.minimum(np.abs(yy - cy), N - np.abs(yy - cy))
        d = np.sqrt(dx * dx + dy * dy)
        m = np.maximum(m, np.clip(1 - d / rad, 0, 1))
    return m


# Бетонная панель: пятна, раковины, подтёки
def concrete():
    base = tile_noise(4, 6, 0.55, 1)
    fine = tile_noise(64, 3, 0.5, 2)
    stains = tile_noise(2, 4, 0.6, 3)
    streaks = tile_noise(1, 1, 0.5, 4)[:, :1] * 0 + tile_noise(48, 2, 0.5, 5).mean(0, keepdims=True)
    pits = dots(260, 1.0, 2.8, 6)
    albedo = 0.78 + (base - 0.5) * 0.18 + (fine - 0.5) * 0.08 - np.clip(stains - 0.55, 0, 1) * 0.5 - pits * 0.25
    albedo -= np.clip(streaks - 0.5, 0, 1) * np.linspace(0.0, 0.25, N)[:, None] * 0.6
    height = base * 0.4 + fine * 0.6 - pits * 0.8
    rough = 0.85 + (fine - 0.5) * 0.1
    save("concrete", albedo, height, rough, 3.0)


# Асфальт: тёмная крошка, светлый щебень
def asphalt():
    fine = tile_noise(96, 3, 0.6, 10)
    grain = tile_noise(180, 1, 0.5, 11)
    stones = dots(900, 0.8, 2.2, 12)
    patches = tile_noise(3, 4, 0.55, 13)
    albedo = 0.32 + (fine - 0.5) * 0.15 + stones * 0.22 + (patches - 0.5) * 0.12 + (grain - 0.5) * 0.08
    height = fine * 0.5 + stones * 0.7
    rough = 0.92 - stones * 0.1
    save("asphalt", albedo, height, rough, 6.0)


# Кирпич: кладка с растворными швами
def brick():
    yy, xx = np.mgrid[0:N, 0:N]
    rows = 8
    bh = N / rows
    bw = N / 4
    row = (yy // bh).astype(int)
    off = (row % 2) * bw / 2
    lx = (xx + off) % bw
    ly = yy % bh
    mortar = ((lx < 6) | (ly < 6)).astype(float)
    brick_id = ((xx + off) // bw).astype(int) + row * 13
    tint = np.random.default_rng(20).random(400)[brick_id % 400]
    n = tile_noise(32, 4, 0.5, 21)
    albedo = np.stack([0.62 + tint * 0.12, 0.3 + tint * 0.06, 0.22 + tint * 0.05], -1) * (0.85 + n[..., None] * 0.3)
    albedo = albedo * (1 - mortar[..., None]) + np.array([0.72, 0.7, 0.66]) * mortar[..., None]
    height = (1 - mortar) * 0.8 + n * 0.2
    rough = 0.9 - (1 - mortar) * 0.05
    save("brick", albedo, height, rough, 5.0)


# Кора: вертикальные волокна и трещины
def bark():
    stretch = tile_noise(1, 1, 0.5, 30)
    fib = np.zeros((N, N))
    r = np.random.default_rng(31)
    for o in range(5):
        cols = r.random(int(24 * 2 ** o))
        x = np.linspace(0, len(cols), N, endpoint=False)
        fib += np.interp(x, np.arange(len(cols) + 1), np.append(cols, cols[0]))[None, :] / 2 ** o
    fib /= fib.max()
    n = tile_noise(8, 5, 0.6, 32)
    cracks = np.clip((0.35 - np.abs(fib - 0.5)) * 4, 0, 1) * np.clip(n * 1.6 - 0.3, 0, 1)
    albedo = 0.65 + (n - 0.5) * 0.3 - cracks * 0.45
    height = fib * 0.5 + n * 0.5 - cracks
    save("bark", albedo, height, 0.95 - cracks * 0.05, 6.0)


# Дерево: волокна досок
def wood():
    n = tile_noise(2, 5, 0.6, 40)
    yy, xx = np.mgrid[0:N, 0:N]
    rings = np.sin((yy / N * 28 + n * 6) * np.pi * 2) * 0.5 + 0.5
    fine = tile_noise(128, 2, 0.5, 41)
    albedo = 0.75 + (rings - 0.5) * 0.18 + (fine - 0.5) * 0.08
    height = rings * 0.4 + fine * 0.6
    save("wood", albedo, height, 0.75 + fine * 0.1, 2.5)


# Крашеный металл: облупленная краска и царапины
def metal():
    n = tile_noise(6, 6, 0.55, 50)
    chips = np.clip((tile_noise(12, 5, 0.6, 51) - 0.68) * 8, 0, 1)
    fine = tile_noise(128, 2, 0.5, 52)
    albedo = 0.85 + (n - 0.5) * 0.12 - chips * 0.45 + (fine - 0.5) * 0.04
    height = -chips * 0.6 + fine * 0.2
    rough = 0.55 + chips * 0.35 + (n - 0.5) * 0.1
    save("metal_paint", albedo, height, rough, 4.0)


# Газон: травинки
def grass():
    n = tile_noise(4, 5, 0.55, 60)
    r = np.random.default_rng(61)
    blades = np.zeros((N, N))
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(2500):
        cx, cy = r.random(2) * N
        ang = r.uniform(-0.6, 0.6)
        ln = r.uniform(6, 16)
        t = np.linspace(0, 1, 12)
        px = (cx + np.sin(ang) * ln * t).astype(int) % N
        py = (cy - np.cos(ang) * ln * t).astype(int) % N
        blades[py, px] = np.maximum(blades[py, px], 0.4 + t * 0.6)
    albedo = np.stack([0.32 + n * 0.12, 0.5 + n * 0.15, 0.2 + n * 0.06], -1) * (0.7 + blades[..., None] * 0.5)
    dirt = np.clip((tile_noise(3, 4, 0.6, 62) - 0.7) * 3, 0, 1)
    albedo = albedo * (1 - dirt[..., None]) + np.array([0.42, 0.34, 0.24]) * dirt[..., None]
    save("grass", albedo, blades * 0.7 + n * 0.3, 0.95, 5.0)


# Листва: RGBA-карточка с листьями (для крон)
def leaves():
    r = np.random.default_rng(70)
    alpha = np.zeros((N, N))
    col = np.zeros((N, N, 3))
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(1400):
        cx, cy = r.uniform(30, N - 30, 2)
        # круглая маска карточки, листьев меньше к краю
        if np.hypot(cx - N / 2, cy - N / 2) > N * 0.46 * (0.7 + 0.3 * r.random()):
            continue
        ang = r.uniform(0, np.pi)
        a, b = r.uniform(9, 16), r.uniform(5, 8)
        x0, x1 = int(cx - 18), int(cx + 18)
        y0, y1 = int(cy - 18), int(cy + 18)
        sx, sy = xx[y0:y1, x0:x1] - cx, yy[y0:y1, x0:x1] - cy
        u = sx * np.cos(ang) + sy * np.sin(ang)
        v = -sx * np.sin(ang) + sy * np.cos(ang)
        m = (u / a) ** 2 + (v / b) ** 2 < 1
        shade = r.uniform(0.6, 1.0)
        tone = np.array([0.36, 0.58, 0.2]) * shade + r.uniform(-0.04, 0.04, 3)
        vein = np.abs(v) < 0.8
        c = np.where(vein[..., None], tone * 1.15, tone * (0.85 + 0.15 * (1 - np.abs(v)[..., None] / b)))
        col[y0:y1, x0:x1][m] = c[m]
        alpha[y0:y1, x0:x1][m] = 1.0
    h = alpha * 0.6 + tile_noise(32, 2, 0.5, 71) * 0.4 * alpha
    save("leaves", col, h, 0.8, 3.0, alpha)


# Пучок травы: RGBA-карточка с травинками (для травы на газонах)
def grass_blades():
    r = np.random.default_rng(80)
    alpha = np.zeros((N, N))
    col = np.zeros((N, N, 3))
    for _ in range(140):
        x0 = r.uniform(20, N - 20)
        lean = r.uniform(-60, 60)
        hgt = r.uniform(0.45, 0.98) * N
        w = r.uniform(3, 7)
        tone = np.array([0.3, 0.52, 0.18]) * r.uniform(0.7, 1.15)
        for t in np.linspace(0, 1, 300):
            y = int(N - 1 - t * hgt)
            x = x0 + lean * t * t
            half = w * (1 - t) + 0.5
            xa, xb = int(x - half), int(x + half) + 1
            xa, xb = max(xa, 0), min(xb, N)
            if xa >= xb or y < 0:
                continue
            col[y, xa:xb] = tone * (0.6 + 0.5 * t)
            alpha[y, xa:xb] = 1.0
    save("grass_blades", col, alpha * 0.5, 0.9, 2.0, alpha)


concrete()
asphalt()
brick()
bark()
wood()
metal()
grass()
leaves()
grass_blades()
