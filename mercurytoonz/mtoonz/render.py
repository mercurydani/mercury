"""Отрисовка мазков и целых кадров. Используется холстом, превью проектов и (дальше) экспортом."""

from __future__ import annotations

from PySide6.QtCore import QRectF, Qt
from PySide6.QtGui import QColor, QImage, QPainter

from .brushes import draw_brush_stroke
from .model import Drawing, Project, Stroke


def draw_stroke(p: QPainter, s: Stroke):
    p.setCompositionMode(QPainter.CompositionMode_DestinationOut if s.erase
                         else QPainter.CompositionMode_SourceOver)
    p.setOpacity(s.opacity)
    draw_brush_stroke(p, s.points, s.color, s.width, s.brush, s.use_pressure, s.erase)
    p.setOpacity(1.0)
    p.setCompositionMode(QPainter.CompositionMode_SourceOver)


def draw_drawing(p: QPainter, drawing: Drawing | None):
    if drawing:
        for s in drawing.strokes:
            draw_stroke(p, s)


def render_frame(project: Project, frame: int, max_width: int | None = None,
                 background: bool = True, size: tuple[int, int] | None = None) -> QImage:
    """Кадр сцены целиком (все видимые слои).
    max_width — уменьшить для превью; size — точный размер результата (для экспорта)."""
    if size is not None:
        w, h = size
        sx, sy = w / project.width, h / project.height
    else:
        scale = 1.0
        if max_width and project.width > max_width:
            scale = max_width / project.width
        w, h = max(1, round(project.width * scale)), max(1, round(project.height * scale))
        sx = sy = scale
    out = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
    out.fill(project.background if background else QColor(0, 0, 0, 0))
    if not project.animation_enabled():
        return out
    p = QPainter(out)
    for layer in reversed(project.layers):
        if not layer.visible:
            continue
        drawing = layer.drawing_at(frame)
        if drawing is None or drawing.is_empty():
            continue
        buf = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
        buf.fill(Qt.transparent)
        bp = QPainter(buf)
        bp.setRenderHint(QPainter.Antialiasing)
        bp.scale(sx, sy)
        bp.setClipRect(QRectF(0, 0, project.width, project.height))
        draw_drawing(bp, drawing)
        bp.end()
        p.setOpacity(layer.opacity)
        p.drawImage(0, 0, buf)
    p.end()
    return out


def first_drawn_frame(project: Project) -> int:
    """Первый кадр, где что-то нарисовано (для обложки проекта)."""
    best = None
    for layer in project.layers:
        for k, d in layer.keys.items():
            if not d.is_empty() and (best is None or k < best):
                best = k
    return best or 0


def render_thumb(project: Project, drawing: Drawing | None, w: int, h: int, dpr: float = 2.0) -> QImage:
    """Миниатюра рисунка для панели слоёв (на прозрачном фоне)."""
    img = QImage(int(w * dpr), int(h * dpr), QImage.Format_ARGB32_Premultiplied)
    img.setDevicePixelRatio(dpr)
    img.fill(Qt.transparent)
    if drawing is None or drawing.is_empty():
        return img
    s = min(w / project.width, h / project.height)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.translate((w - project.width * s) / 2, (h - project.height * s) / 2)
    p.scale(s, s)
    p.setClipRect(QRectF(0, 0, project.width, project.height))
    draw_drawing(p, drawing)
    p.end()
    return img
