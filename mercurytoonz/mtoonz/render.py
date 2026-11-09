"""Отрисовка мазков и целых кадров. Используется холстом, превью проектов и (дальше) экспортом."""

from __future__ import annotations

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QImage, QPainter, QPainterPath, QPen

from .model import Drawing, Project, Stroke


def stroke_path(points) -> QPainterPath:
    """Гладкая кривая через точки (квадратичные сплайны через середины отрезков)."""
    path = QPainterPath()
    if not points:
        return path
    path.moveTo(points[0][0], points[0][1])
    if len(points) == 1:
        path.lineTo(points[0][0] + 0.01, points[0][1])
        return path
    for i in range(1, len(points) - 1):
        x0, y0 = points[i][0], points[i][1]
        x1, y1 = points[i + 1][0], points[i + 1][1]
        path.quadTo(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2)
    path.lineTo(points[-1][0], points[-1][1])
    return path


def draw_stroke(p: QPainter, s: Stroke):
    color = QColor(s.color)
    if s.erase:
        p.setCompositionMode(QPainter.CompositionMode_DestinationOut)
        color = QColor(0, 0, 0)
    else:
        p.setCompositionMode(QPainter.CompositionMode_SourceOver)
    p.setOpacity(s.opacity)
    pts = s.points
    if s.use_pressure and len(pts) > 1 and any(pt[2] != 1.0 for pt in pts):
        # переменная толщина: рисуем отрезками
        for a, b in zip(pts, pts[1:]):
            w = max(0.5, s.width * (a[2] + b[2]) / 2)
            p.setPen(QPen(color, w, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
            p.drawLine(QPointF(a[0], a[1]), QPointF(b[0], b[1]))
    else:
        p.setPen(QPen(color, s.width, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
        p.setBrush(Qt.NoBrush)
        p.drawPath(stroke_path(pts))
    p.setOpacity(1.0)
    p.setCompositionMode(QPainter.CompositionMode_SourceOver)


def draw_drawing(p: QPainter, drawing: Drawing | None):
    if drawing:
        for s in drawing.strokes:
            draw_stroke(p, s)


def render_frame(project: Project, frame: int, max_width: int | None = None,
                 background: bool = True) -> QImage:
    """Кадр сцены целиком (все видимые слои). max_width — уменьшить для превью."""
    scale = 1.0
    if max_width and project.width > max_width:
        scale = max_width / project.width
    w, h = max(1, round(project.width * scale)), max(1, round(project.height * scale))
    out = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
    out.fill(project.background if background else QColor(0, 0, 0, 0))
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
        bp.scale(scale, scale)
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
