"""Фирменный стиль: логотип-планета, иконка программы, звук запуска.

Логотип рисуется кодом (QPainter), поэтому один и тот же рисунок используется
в иконке окна, на заставке, в шапке программы и сохраняется в SVG/PNG.
"""

from __future__ import annotations

import math
import os
import struct
import tempfile
import wave
from functools import lru_cache

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import (
    QColor, QFont, QIcon, QLinearGradient, QPainter, QPainterPath, QPen, QPixmap, QRadialGradient,
)

from . import APP_VERSION, theme

# Кратеры: (смещение x, смещение y, радиус) в долях радиуса планеты
CRATERS = [(-0.32, 0.28, 0.17), (0.30, -0.08, 0.12), (0.05, 0.55, 0.09), (0.42, 0.40, 0.07), (-0.05, -0.45, 0.06)]
RING_TILT = -18.0


def _planet_gradient(c: QPointF, r: float) -> QRadialGradient:
    g = QRadialGradient(QPointF(c.x() - 0.38 * r, c.y() - 0.42 * r), 1.55 * r)
    g.setColorAt(0.0, QColor("#ffffff"))
    g.setColorAt(0.22, QColor(theme.PLANET_LIGHT))
    g.setColorAt(0.6, QColor(theme.PLANET_MID))
    g.setColorAt(1.0, QColor(theme.PLANET_DARK))
    return g


def _ring_pen(c: QPointF, r: float, alpha: int = 255) -> QPen:
    g = QLinearGradient(QPointF(c.x() - 1.6 * r, c.y()), QPointF(c.x() + 1.6 * r, c.y()))
    a = QColor("#a9bcff")
    b = QColor(theme.MERCURY_BLUE_LIGHT)
    d = QColor(theme.MERCURY_BLUE)
    for col in (a, b, d):
        col.setAlpha(alpha)
    g.setColorAt(0, a)
    g.setColorAt(0.5, b)
    g.setColorAt(1, d)
    return QPen(g, max(1.0, 0.1 * r), Qt.SolidLine, Qt.RoundCap)


def draw_planet(p: QPainter, c: QPointF, r: float, sx: float = 1.0, sy: float = 1.0,
                ring: float = 1.0, shine: bool = True):
    """Планета Меркурий с кольцом орбиты.
    sx, sy — сплющивание (для анимации прыжка); ring 0..1 — насколько «прорисовано» кольцо."""
    p.save()
    p.setRenderHint(QPainter.Antialiasing)
    p.translate(c)
    p.scale(sx, sy)
    origin = QPointF(0, 0)
    ring_rect = QRectF(-1.62 * r, -0.44 * r, 3.24 * r, 0.88 * r)
    span = int(180 * 16 * max(0.0, min(1.0, ring)))

    # задняя половина кольца — за планетой
    if ring > 0:
        p.save()
        p.rotate(RING_TILT)
        p.setPen(_ring_pen(origin, r, 150))
        p.setBrush(Qt.NoBrush)
        p.drawArc(ring_rect, 0, span)
        p.restore()

    # синее свечение вокруг планеты (как на сайте студии)
    glow = QRadialGradient(origin, 1.35 * r)
    gc = QColor(theme.MERCURY_GLOW)
    for stop, a in ((0.70, 150), (0.80, 70), (1.0, 0)):
        gc.setAlpha(a)
        glow.setColorAt(stop, QColor(gc))
    p.setPen(Qt.NoPen)
    p.setBrush(glow)
    p.drawEllipse(origin, 1.35 * r, 1.35 * r)

    # сама планета
    p.setBrush(_planet_gradient(origin, r))
    p.drawEllipse(origin, r, r)

    # кратеры: тень + светлый край
    clip = QPainterPath()
    clip.addEllipse(origin, r, r)
    p.setClipPath(clip)
    for dx, dy, cr in CRATERS:
        cc = QPointF(dx * r, dy * r)
        p.setBrush(QColor(40, 42, 55, 80))
        p.drawEllipse(cc, cr * r, cr * r * 0.86)
        p.setPen(QPen(QColor(255, 255, 255, 120), max(0.6, r * 0.018)))
        p.setBrush(Qt.NoBrush)
        p.drawArc(QRectF(cc.x() - cr * r, cc.y() - cr * r * 0.86, 2 * cr * r, 1.72 * cr * r), 200 * 16, 140 * 16)
        p.setPen(Qt.NoPen)
    # синий отсвет по краю ночной стороны
    rim = QRadialGradient(QPointF(-0.25 * r, -0.3 * r), 1.35 * r)
    rim.setColorAt(0.0, QColor(74, 108, 255, 0))
    rim.setColorAt(0.72, QColor(74, 108, 255, 0))
    rim.setColorAt(1.0, QColor(74, 108, 255, 170))
    p.setBrush(rim)
    p.drawEllipse(origin, r, r)
    # блик
    if shine:
        p.setBrush(QColor(255, 255, 255, 70))
        p.drawEllipse(QPointF(-0.42 * r, -0.48 * r), 0.2 * r, 0.12 * r)
    p.setClipping(False)

    # передняя половина кольца — поверх планеты
    if ring > 0:
        p.rotate(RING_TILT)
        p.setPen(_ring_pen(origin, r, 255))
        p.drawArc(ring_rect, 180 * 16, span)
    p.restore()


def draw_sparkle(p: QPainter, c: QPointF, size: float, color: QColor):
    path = QPainterPath()
    s, w = size, size * 0.22
    path.moveTo(c.x(), c.y() - s)
    path.quadTo(c.x() + w * 0.3, c.y() - w * 0.3, c.x() + s, c.y())
    path.quadTo(c.x() + w * 0.3, c.y() + w * 0.3, c.x(), c.y() + s)
    path.quadTo(c.x() - w * 0.3, c.y() + w * 0.3, c.x() - s, c.y())
    path.quadTo(c.x() - w * 0.3, c.y() - w * 0.3, c.x(), c.y() - s)
    p.save()
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(Qt.NoPen)
    p.setBrush(color)
    p.drawPath(path)
    p.restore()


def draw_logo_mark(p: QPainter, rect: QRectF, motion: bool = True):
    """Знак: планета, кольцо, искорка и линии движения (анимация!)."""
    r = min(rect.width(), rect.height()) * 0.3
    c = QPointF(rect.center().x() + r * 0.12, rect.center().y() + r * 0.02)
    if motion:
        p.save()
        p.setRenderHint(QPainter.Antialiasing)
        for i, (dy, ln) in enumerate(((-0.45, 0.55), (0.0, 0.8), (0.45, 0.45))):
            pen = QPen(QColor(theme.MERCURY_BLUE_LIGHT if i != 1 else theme.MERCURY_BLUE), max(1.0, r * 0.11),
                       Qt.SolidLine, Qt.RoundCap)
            p.setPen(pen)
            x0 = c.x() - r * 1.25
            p.drawLine(QPointF(x0 - ln * r, c.y() + dy * r), QPointF(x0, c.y() + dy * r))
        p.restore()
    draw_planet(p, c, r)
    draw_sparkle(p, QPointF(c.x() + r * 1.15, c.y() - r * 1.05), r * 0.26, QColor("#ffffff"))
    draw_sparkle(p, QPointF(c.x() + r * 1.5, c.y() - r * 0.55), r * 0.12, QColor("#a9bcff"))


def draw_wordmark(p: QPainter, rect: QRectF, size_px: int, align=Qt.AlignCenter, sub: bool = True):
    p.save()
    p.setRenderHint(QPainter.Antialiasing)
    f = QFont()
    f.setPixelSize(size_px)
    f.setWeight(QFont.Black)
    f.setLetterSpacing(QFont.PercentageSpacing, 98)
    p.setFont(f)
    fm = p.fontMetrics()
    a, b = "Mercury", "Toonz"
    total = fm.horizontalAdvance(a + b)
    if align & Qt.AlignLeft:
        x = rect.left()
    else:
        x = rect.center().x() - total / 2
    y = rect.top() + fm.ascent()
    p.setPen(QColor(theme.TEXT))
    p.drawText(QPointF(x, y), a)
    g = QLinearGradient(QPointF(x + fm.horizontalAdvance(a), 0), QPointF(x + total, 0))
    g.setColorAt(0, QColor(theme.MERCURY_BLUE_LIGHT))
    g.setColorAt(1, QColor(theme.MERCURY_BLUE))
    p.setPen(QPen(g, 1))
    p.drawText(QPointF(x + fm.horizontalAdvance(a), y), b)
    if sub:
        f2 = QFont()
        f2.setPixelSize(max(9, size_px // 3))
        f2.setLetterSpacing(QFont.PercentageSpacing, 125)
        p.setFont(f2)
        p.setPen(QColor(theme.TEXT_MUTED))
        text = "MERCURY STUDIO"
        w2 = p.fontMetrics().horizontalAdvance(text)
        x2 = rect.left() if align & Qt.AlignLeft else rect.center().x() - w2 / 2
        p.drawText(QPointF(x2, y + fm.descent() + p.fontMetrics().ascent() + size_px * 0.15), text)
    p.restore()


@lru_cache(maxsize=16)
def logo_pixmap(size: int, motion: bool = False, dpr: float = 2.0) -> QPixmap:
    pm = QPixmap(int(size * dpr), int(size * dpr))
    pm.setDevicePixelRatio(dpr)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    draw_logo_mark(p, QRectF(0, 0, size, size), motion)
    p.end()
    return pm


@lru_cache(maxsize=1)
def app_icon() -> QIcon:
    icon = QIcon()
    for s in (16, 24, 32, 48, 64, 128, 256):
        pm = QPixmap(s, s)
        pm.fill(Qt.transparent)
        p = QPainter(pm)
        # для маленьких размеров — без линий движения, крупнее
        draw_logo_mark(p, QRectF(-s * 0.08, -s * 0.05, s * 1.12, s * 1.12) if s < 48 else QRectF(0, 0, s, s),
                       motion=s >= 48)
        p.end()
        icon.addPixmap(pm)
    return icon


def save_brand_files(folder: str):
    """Сохраняет логотип в SVG и PNG (для сайта, соцсетей, документации)."""
    from PySide6.QtCore import QSize
    from PySide6.QtSvg import QSvgGenerator
    os.makedirs(folder, exist_ok=True)
    # знак
    gen = QSvgGenerator()
    gen.setFileName(os.path.join(folder, "logo.svg"))
    gen.setSize(QSize(512, 512))
    gen.setViewBox(QRectF(0, 0, 512, 512))
    gen.setTitle("MercuryToonz")
    p = QPainter(gen)
    draw_logo_mark(p, QRectF(0, 0, 512, 512))
    p.end()
    logo_pixmap(512, True, 1.0).save(os.path.join(folder, "logo.png"))
    # знак + надпись на тёмном фоне
    from PySide6.QtGui import QImage
    img = QImage(1200, 400, QImage.Format_ARGB32_Premultiplied)
    img.fill(QColor(theme.SPACE_NIGHT))
    p = QPainter(img)
    draw_logo_mark(p, QRectF(60, 40, 320, 320))
    draw_wordmark(p, QRectF(400, 130, 760, 140), 96, Qt.AlignLeft)
    p.end()
    img.save(os.path.join(folder, "logo-wide.png"))


# ------------------------------------------------------------------ анимация заставки
GRAVITY = 1900.0
RESTITUTION = 0.52
DROP = 165.0
START_DELAY = 0.18


def bounce_schedule():
    """Моменты касаний земли и скорости при касании: [(время, скорость)].
    Общая для анимации и звука, чтобы «бум» совпадал с прыжком."""
    t = START_DELAY + math.sqrt(2 * DROP / GRAVITY)
    v = math.sqrt(2 * GRAVITY * DROP)
    out = [(t, v)]
    for _ in range(3):
        v *= RESTITUTION
        t += 2 * v / GRAVITY
        out.append((t, v))
    return out


def planet_height(t: float) -> tuple[float, float]:
    """Высота над землёй и вертикальная скорость (вверх +) в момент t."""
    if t < START_DELAY:
        return DROP, 0.0
    hits = bounce_schedule()
    t0 = START_DELAY
    if t < hits[0][0]:
        dt = t - t0
        return max(0.0, DROP - GRAVITY * dt * dt / 2), -GRAVITY * dt
    for (ta, va), (tb, _vb) in zip(hits, hits[1:]):
        if t < tb:
            v_up = va * RESTITUTION
            dt = t - ta
            return max(0.0, v_up * dt - GRAVITY * dt * dt / 2), v_up - GRAVITY * dt
    return 0.0, 0.0


# ------------------------------------------------------------------ звук запуска
RATE = 48000


def _env(t, attack, decay):
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def synth_startup_sound() -> list[float]:
    """«Бум-бум-бум» в такт прыжкам планеты и звонкий аккорд в конце."""
    hits = bounce_schedule()
    chime_t = hits[-1][0] + 0.12
    total = chime_t + 1.6
    n = int(total * RATE)
    out = [0.0] * n
    v0 = hits[0][1]
    # прыжки: мягкий «бум» с падающим тоном
    for i, (t, v) in enumerate(hits):
        amp = 0.55 * (v / v0) ** 0.8
        start = int(t * RATE)
        length = int(0.28 * RATE)
        phase = 0.0
        for k in range(length):
            tt = k / RATE
            f = 190 + 140 * i - 110 * min(1.0, tt / 0.12)  # «боинг» вниз
            phase += 2 * math.pi * f / RATE
            e = _env(tt, 0.004, 0.07)
            idx = start + k
            if idx < n:
                out[idx] += amp * e * (math.sin(phase) + 0.25 * math.sin(2 * phase))
    # аккорд: до-ми-соль-до, лёгкое арпеджио, «колокольчик» с обертонами
    notes = [523.25, 659.25, 783.99, 1046.5]
    for j, f in enumerate(notes):
        start = int((chime_t + j * 0.06) * RATE)
        for k in range(n - start):
            tt = k / RATE
            e = _env(tt, 0.006, 0.55)
            if e < 1e-4 and tt > 0.1:
                break
            s = (math.sin(2 * math.pi * f * tt) + 0.35 * math.sin(2 * math.pi * f * 2.01 * tt) * math.exp(-tt * 6)
                 + 0.12 * math.sin(2 * math.pi * f * 3.98 * tt) * math.exp(-tt * 10))
            out[start + k] += 0.16 * e * s
    peak = max(1e-6, max(abs(x) for x in out))
    k = 0.8 / peak
    return [x * k for x in out]


def startup_sound_path() -> str:
    """WAV со звуком запуска (создаётся один раз и кладётся во временную папку)."""
    path = os.path.join(tempfile.gettempdir(), f"mercurytoonz-startup-{APP_VERSION}.wav")
    if not os.path.exists(path):
        samples = synth_startup_sound()
        tmp = path + ".tmp"
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)  # стерео 48 кГц 16 бит — понимают все звуковые карты
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<hh", v, v) for v in
                                   (int(max(-1, min(1, s)) * 32767) for s in samples)))
        os.replace(tmp, path)
    return path
