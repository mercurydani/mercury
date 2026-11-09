"""Таймлайн: дорожки (видео и звук) слева, кадры справа, линейка и бегунок.

Рисованные слои живут в отдельной панели «Слои». На таймлайне — только дорожки:
  * «Анимация» — нарисованный мультфильм; на ней видны ключевые кадры выбранного слоя
    (и бледными чёрточками — ключи остальных слоёв);
  * видеодорожки — для видео, картинок и GIF (импорт появится на следующих шагах);
  * звуковые дорожки — звуковые клипы с волной; клипы можно таскать по времени и между дорожками.
"""

from __future__ import annotations

from PySide6.QtCore import QPointF, QRectF, QSize, Qt, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPen, QPolygonF
from PySide6.QtWidgets import (
    QFrame, QHBoxLayout, QInputDialog, QLabel, QMenu, QScrollBar, QSlider, QSpinBox,
    QToolButton, QVBoxLayout, QWidget,
)

from .. import icons, theme
from ..audio import PEAKS_PER_SECOND
from ..model import Project
from ..state import EditorState

HEAD_W = 200
HEADER_H = 26
ROW_H = 38

C_ROW = QColor("#1a1c26")
C_ROW_ALT = QColor("#1d1f2a")
C_ROW_CUR = QColor("#252838")
C_GRID = QColor("#272a37")
C_GRID_5 = QColor("#343849")
C_OUTSIDE = QColor("#14151d")
C_SPAN = QColor("#383d50")
C_SPAN_CUR = QColor("#4a4f66")
C_SPAN_EMPTY = QColor("#292c3a")
C_VIDEO = QColor("#5cc8ff")
C_AUDIO = QColor("#3fbf7f")


class TimelineCanvas(QWidget):
    scrolled = Signal()

    def __init__(self, project: Project, state: EditorState, actions: dict):
        super().__init__()
        self.project = project
        self.state = state
        self.actions = actions
        self.cell_w = 18
        self.hoff = 0
        self.voff = 0
        self._scrubbing = False
        self._drag = None          # (id клипа, кадр захвата, исходная дорожка)
        self._drag_delta = 0
        self._drag_row = -1
        self.setMouseTracking(True)
        self.setMinimumHeight(HEADER_H + ROW_H * 2)
        self.setFocusPolicy(Qt.ClickFocus)
        for sig in (project.structureChanged, project.contentChanged):
            sig.connect(self.update)
        project.frameChanged.connect(lambda _: self.update())
        project.layerChanged.connect(lambda _: self.update())

    # ---------- геометрия ----------
    def grid_width(self) -> int:
        return max(0, self.width() - HEAD_W)

    def content_width(self) -> int:
        return (self.project.frame_count + 40) * self.cell_w

    def content_height(self) -> int:
        return len(self.project.tracks) * ROW_H

    def frame_at(self, x: float) -> int:
        return int((x - HEAD_W + self.hoff) // self.cell_w)

    def row_at(self, y: float) -> int:
        return int((y - HEADER_H + self.voff) // ROW_H)

    def frame_x(self, f: float) -> float:
        return HEAD_W + f * self.cell_w - self.hoff

    def row_y(self, r: int) -> float:
        return HEADER_H + r * ROW_H - self.voff

    def ensure_frame_visible(self, f: int):
        x = f * self.cell_w
        gw = self.grid_width()
        if x < self.hoff:
            self.hoff = x
        elif x + self.cell_w > self.hoff + gw:
            self.hoff = x + self.cell_w - gw + self.cell_w * 4
        else:
            return
        self.scrolled.emit()
        self.update()

    # ---------- отрисовка ----------
    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(theme.BG_PANEL))
        proj = self.project
        cw = self.cell_w
        first = max(0, self.hoff // cw)
        last = (self.hoff + self.grid_width()) // cw + 1

        p.save()
        p.setClipRect(HEAD_W, HEADER_H, self.grid_width(), self.height() - HEADER_H)
        for r, track in enumerate(proj.tracks):
            y = self.row_y(r)
            if y > self.height() or y + ROW_H < HEADER_H:
                continue
            cur = r == proj.current_track
            p.fillRect(QRectF(HEAD_W, y, self.grid_width(), ROW_H), C_ROW_CUR if cur else (C_ROW_ALT if r % 2 else C_ROW))
            out_x = self.frame_x(proj.frame_count)
            if out_x < self.width():
                p.fillRect(QRectF(out_x, y, self.width() - out_x, ROW_H), C_OUTSIDE)
            if track.animation:
                for f in range(first, last + 1):
                    x = self.frame_x(f)
                    p.setPen(C_GRID_5 if (f + 1) % 5 == 0 else C_GRID)
                    p.drawLine(QPointF(x + cw - 0.5, y), QPointF(x + cw - 0.5, y + ROW_H))
            if self._drag is not None and r == self._drag_row:
                p.fillRect(QRectF(HEAD_W, y, self.grid_width(), ROW_H), QColor(63, 191, 127, 22))
            p.setPen(C_GRID)
            p.drawLine(QPointF(HEAD_W, y + ROW_H - 0.5), QPointF(self.width(), y + ROW_H - 0.5))
            if track.animation:
                self._paint_animation(p, track, y, first, last)
            elif track.kind == "audio":
                for clip in track.clips:
                    if self._drag is not None and clip.id == self._drag[0]:
                        continue
                    self._paint_clip(p, clip, clip.start, y, cur, track.enabled)
            elif not track.clips:
                p.setPen(QColor("#4a4f58"))
                f = QFont(self.font())
                f.setPixelSize(11)
                p.setFont(f)
                p.drawText(QRectF(HEAD_W + 10, y, 600, ROW_H), Qt.AlignVCenter,
                           "Пустая видеодорожка — сюда можно будет добавить видео, картинки и GIF")
        # перетаскиваемый клип рисуем поверх, на дорожке под курсором
        if self._drag is not None:
            found = proj.find_clip(self._drag[0])
            if found and 0 <= self._drag_row < len(proj.tracks):
                _t, clip = found
                self._paint_clip(p, clip, max(0, clip.start + self._drag_delta), self.row_y(self._drag_row),
                                 True, True)
        cx = self.frame_x(proj.current_frame)
        p.fillRect(QRectF(cx, HEADER_H, cw, self.height()), QColor(255, 90, 79, 24))
        p.restore()

        self._paint_ruler(p, first, last)
        px = cx + cw / 2
        if px >= HEAD_W:
            p.setPen(QPen(QColor(theme.PLAYHEAD), 1.5))
            p.drawLine(QPointF(px, HEADER_H), QPointF(px, self.height()))
        self._paint_heads(p)
        p.end()

    def _paint_animation(self, p: QPainter, track, y, first, last):
        """Дорожка «Анимация»: экспозиции выбранного слоя + ключи остальных слоёв."""
        proj = self.project
        cw = self.cell_w
        layer = proj.draw_layer()
        p.setRenderHint(QPainter.Antialiasing)
        dim = not track.enabled
        # ключи остальных слоёв — бледные риски сверху
        for other in proj.layers:
            if other is layer or not other.visible:
                continue
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(other.tag))
            for k in other.keys:
                if first <= k <= last:
                    p.drawRoundedRect(QRectF(self.frame_x(k) + cw / 2 - 1.5, y + 3, 3, 5), 1, 1)
        if layer is None:
            p.setRenderHint(QPainter.Antialiasing, False)
            return
        keys = layer.sorted_keys()
        for i, k in enumerate(keys):
            end = keys[i + 1] if i + 1 < len(keys) else proj.frame_count
            end = max(end, k + 1)
            if end <= first or k > last:
                continue
            drawing = layer.keys[k]
            empty = drawing.is_empty()
            x0, x1 = self.frame_x(k), self.frame_x(end)
            span = QRectF(x0 + 1, y + 10, x1 - x0 - 2, ROW_H - 16)
            if empty:
                p.setPen(QPen(C_SPAN_CUR, 1))
                p.setBrush(C_SPAN_EMPTY)
            else:
                p.setPen(Qt.NoPen)
                p.setBrush(C_SPAN_CUR)
            p.setOpacity(0.5 if dim else 1.0)
            p.drawRoundedRect(span, 3, 3)
            if not empty:
                p.fillRect(QRectF(span.left() + 2, span.bottom() - 2, span.width() - 4, 2), QColor(layer.tag))
            c = QPointF(x0 + cw / 2, span.center().y())
            r = min(4.5, cw / 2 - 2)
            if empty:
                p.setBrush(Qt.NoBrush)
                p.setPen(QPen(QColor(theme.TEXT), 1.4))
            else:
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(theme.TEXT))
            p.drawEllipse(c, r, r)
            if end - k > 1:
                ex = self.frame_x(end - 1)
                p.setPen(Qt.NoPen)
                p.setBrush(QColor(theme.TEXT_MUTED))
                p.drawRect(QRectF(ex + cw / 2 - 2.5, c.y() - 3.5, 5, 7))
        p.setOpacity(1.0)
        p.setRenderHint(QPainter.Antialiasing, False)

    def _paint_clip(self, p: QPainter, clip, start, y, cur, enabled):
        fps = max(1, self.project.fps)
        end = start + max(1, round(clip.duration * fps))
        x0, x1 = self.frame_x(start), self.frame_x(end)
        if x1 < HEAD_W or x0 > self.width():
            return
        rect = QRectF(x0 + 1, y + 3, x1 - x0 - 2, ROW_H - 6)
        p.setRenderHint(QPainter.Antialiasing)
        base = QColor("#2a6b4d" if cur else "#24563f") if enabled else QColor("#3a3f47")
        p.setPen(QPen(C_AUDIO, 1) if cur else Qt.NoPen)
        p.setBrush(base)
        p.drawRoundedRect(rect, 4, 4)
        if clip.peaks:
            mid = rect.center().y() + 4
            half = rect.height() / 2 - 6
            vis0, vis1 = max(rect.left(), HEAD_W), min(rect.right(), self.width())
            px_per_sec = self.cell_w * fps
            p.setPen(QPen(QColor("#9be3bf" if enabled else "#6b7280"), 1))
            xi = int(vis0)
            while xi < vis1:
                t0 = (xi - rect.left()) / px_per_sec
                i0 = int(t0 * PEAKS_PER_SECOND)
                i1 = max(i0 + 1, int((t0 + 1 / px_per_sec) * PEAKS_PER_SECOND))
                chunk = clip.peaks[i0:i1]
                if chunk:
                    h = max(0.5, max(chunk) * half)
                    p.drawLine(QPointF(xi + 0.5, mid - h), QPointF(xi + 0.5, mid + h))
                xi += 1
        p.setPen(QColor("#e6fff2"))
        f = QFont(self.font())
        f.setPixelSize(11)
        p.setFont(f)
        p.drawText(QRectF(max(rect.left(), HEAD_W) + 6, rect.top(), rect.width(), 14),
                   Qt.AlignLeft | Qt.AlignVCenter, clip.name)
        p.setRenderHint(QPainter.Antialiasing, False)

    def _paint_ruler(self, p: QPainter, first, last):
        proj = self.project
        cw = self.cell_w
        p.fillRect(QRectF(HEAD_W, 0, self.grid_width(), HEADER_H), QColor(theme.BG_PANEL))
        p.save()
        p.setClipRect(HEAD_W, 0, self.grid_width(), HEADER_H)
        f = QFont(self.font())
        f.setPointSizeF(8.5)
        p.setFont(f)
        step = 5 if cw >= 12 else 10
        for fr in range(first, last + 1):
            x = self.frame_x(fr)
            n = fr + 1
            outside = fr >= proj.frame_count
            if n % step == 0 or n == 1:
                p.setPen(QColor(theme.TEXT_MUTED if not outside else "#4a4f58"))
                p.drawText(QRectF(x - 20, 2, cw + 40, HEADER_H - 8), Qt.AlignHCenter | Qt.AlignTop, str(n))
                p.drawLine(QPointF(x + cw / 2, HEADER_H - 6), QPointF(x + cw / 2, HEADER_H))
            else:
                p.setPen(QColor("#3c414b"))
                p.drawLine(QPointF(x + cw / 2, HEADER_H - 3), QPointF(x + cw / 2, HEADER_H))
        cx = self.frame_x(proj.current_frame) + cw / 2
        label = str(proj.current_frame + 1)
        w = max(22, p.fontMetrics().horizontalAdvance(label) + 10)
        badge = QRectF(cx - w / 2, 3, w, 16)
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(theme.PLAYHEAD))
        p.drawRoundedRect(badge, 4, 4)
        p.drawPolygon(QPolygonF([QPointF(cx - 4, 19), QPointF(cx + 4, 19), QPointF(cx, HEADER_H - 1)]))
        p.setPen(QColor("#ffffff"))
        f.setBold(True)
        p.setFont(f)
        p.drawText(badge, Qt.AlignCenter, label)
        p.restore()
        p.setPen(QColor(theme.BORDER))
        p.drawLine(QPointF(HEAD_W, HEADER_H - 0.5), QPointF(self.width(), HEADER_H - 0.5))

    def _paint_heads(self, p: QPainter):
        proj = self.project
        p.fillRect(QRectF(0, 0, HEAD_W, self.height()), QColor(theme.BG_PANEL))
        p.save()
        p.setClipRect(0, HEADER_H, HEAD_W, self.height() - HEADER_H)
        for r, track in enumerate(proj.tracks):
            y = self.row_y(r)
            if y > self.height() or y + ROW_H < HEADER_H:
                continue
            cur = r == proj.current_track
            p.fillRect(QRectF(0, y, HEAD_W, ROW_H), C_ROW_CUR if cur else C_ROW)
            video = track.kind == "video"
            accent = C_VIDEO if video else C_AUDIO
            p.fillRect(QRectF(0, y, 3, ROW_H), accent if cur else accent.darker(220))
            on = track.enabled
            toggle = ("eye" if on else "eye-off") if video else ("speaker" if on else "speaker-off")
            p.drawPixmap(QPointF(10, y + (ROW_H - 16) / 2),
                         icons.pixmap(toggle, theme.TEXT if on else theme.TEXT_MUTED, 16))
            p.drawPixmap(QPointF(34, y + (ROW_H - 16) / 2),
                         icons.pixmap("lock" if track.locked else "unlock",
                                      theme.ACCENT if track.locked else theme.TEXT_MUTED, 16))
            kind_icon = ("film" if not track.animation else "brush") if video else "music"
            p.drawPixmap(QPointF(60, y + (ROW_H - 14) / 2), icons.pixmap(kind_icon, accent.name(), 14))
            p.setPen(QColor(theme.TEXT if on else theme.TEXT_MUTED))
            f = QFont(self.font())
            f.setBold(cur)
            p.setFont(f)
            p.drawText(QRectF(82, y, HEAD_W - 88, ROW_H), Qt.AlignVCenter | Qt.AlignLeft,
                       p.fontMetrics().elidedText(track.name, Qt.ElideRight, HEAD_W - 90))
            p.setPen(C_GRID)
            p.drawLine(QPointF(0, y + ROW_H - 0.5), QPointF(HEAD_W, y + ROW_H - 0.5))
        p.restore()
        p.fillRect(QRectF(0, 0, HEAD_W, HEADER_H), QColor(theme.BG_PANEL))
        p.setPen(QColor(theme.TEXT_MUTED))
        f = QFont(self.font())
        f.setPointSizeF(8.5)
        f.setBold(True)
        p.setFont(f)
        p.drawText(QRectF(10, 0, 180, HEADER_H), Qt.AlignVCenter, "ДОРОЖКИ")
        p.setPen(QColor(theme.BORDER))
        p.drawLine(QPointF(0, HEADER_H - 0.5), QPointF(HEAD_W, HEADER_H - 0.5))
        p.drawLine(QPointF(HEAD_W - 0.5, 0), QPointF(HEAD_W - 0.5, self.height()))

    # ---------- ввод ----------
    def _menu(self, items, pos):
        menu = QMenu(self)
        for it in items:
            if it is None:
                menu.addSeparator()
            elif isinstance(it, str):
                menu.addAction(self.actions[it])
            else:
                menu.addAction(*it)
        menu.exec(pos)

    def mousePressEvent(self, e):
        pos = e.position()
        x, y = pos.x(), pos.y()
        proj = self.project
        if x < HEAD_W:
            if y < HEADER_H:
                return
            r = self.row_at(y)
            if not (0 <= r < len(proj.tracks)):
                if e.button() == Qt.RightButton:
                    self._menu(["track_add_video", "track_add_audio"], e.globalPosition().toPoint())
                return
            track = proj.tracks[r]
            if e.button() == Qt.LeftButton and 6 <= x <= 30:
                track.enabled = not track.enabled
                proj.mark_dirty()
                proj.contentChanged.emit()
            elif e.button() == Qt.LeftButton and 30 < x <= 54:
                track.locked = not track.locked
                proj.mark_dirty()
                self.update()
            else:
                proj.set_track(r)
                if e.button() == Qt.RightButton:
                    self._menu([("Переименовать…", lambda: self._rename(r)), None,
                                "track_add_video", "track_add_audio", None, "track_delete"],
                               e.globalPosition().toPoint())
            return
        f = self.frame_at(x)
        if y < HEADER_H:
            if e.button() == Qt.LeftButton:
                self._scrubbing = True
                proj.set_frame(f)
            return
        r = self.row_at(y)
        if not (0 <= r < len(proj.tracks)):
            proj.set_frame(f)
            if e.button() == Qt.LeftButton:
                self._scrubbing = True
            return
        proj.set_track(r)
        track = proj.tracks[r]
        clip = track.clip_at(f, proj.fps) if track.kind == "audio" else None
        if clip is not None and e.button() == Qt.LeftButton and not track.locked:
            self._drag = (clip.id, f, track)
            self._drag_delta = 0
            self._drag_row = r
            self.setCursor(Qt.ClosedHandCursor)
            return
        proj.set_frame(f)
        if e.button() == Qt.LeftButton:
            self._scrubbing = True
        elif e.button() == Qt.RightButton:
            if track.animation:
                self._menu(["key", "key_blank", "key_remove", None, "frame_insert", "frame_remove", None, "clear"],
                           e.globalPosition().toPoint())
            elif clip is not None:
                self._menu([("Удалить звук", lambda: proj.delete_clip(clip.id))], e.globalPosition().toPoint())
            elif track.kind == "audio":
                self._menu(["record_audio", "import_audio"], e.globalPosition().toPoint())

    def mouseMoveEvent(self, e):
        if self._drag is not None:
            proj = self.project
            found = proj.find_clip(self._drag[0])
            if found is None:
                self._drag = None
                return
            _t, clip = found
            self._drag_delta = max(-clip.start, self.frame_at(e.position().x()) - self._drag[1])
            r = self.row_at(e.position().y())
            if 0 <= r < len(proj.tracks) and proj.tracks[r].kind == "audio":
                self._drag_row = r
            self.update()
            return
        if self._scrubbing:
            self.project.set_frame(self.frame_at(e.position().x()))
            self.ensure_frame_visible(self.project.current_frame)

    def mouseReleaseEvent(self, e):
        self._scrubbing = False
        if self._drag is not None:
            clip_id, grab_frame, src = self._drag
            proj = self.project
            dst = proj.tracks[self._drag_row] if 0 <= self._drag_row < len(proj.tracks) else src
            delta = self._drag_delta
            self._drag = None
            self._drag_delta = 0
            self.unsetCursor()
            found = proj.find_clip(clip_id)
            if found is not None:
                clip = found[1]
                if delta or dst is not src:
                    if not proj.move_clip(clip_id, clip.start + delta, dst):
                        self.window().statusBar().showMessage("Туда нельзя: место на дорожке занято", 3000)
                else:
                    proj.set_frame(grab_frame)
            self.update()

    def _rename(self, r):
        name, ok = QInputDialog.getText(self, "Переименовать дорожку", "Название:", text=self.project.tracks[r].name)
        if ok:
            self.project.rename_track(r, name.strip())

    def mouseDoubleClickEvent(self, e):
        pos = e.position()
        if 60 < pos.x() < HEAD_W and pos.y() > HEADER_H:
            r = self.row_at(pos.y())
            if 0 <= r < len(self.project.tracks):
                self._rename(r)

    def wheelEvent(self, e):
        d = e.angleDelta()
        if e.modifiers() & Qt.ControlModifier:
            self.set_cell_width(self.cell_w + (2 if d.y() > 0 else -2))
        elif e.modifiers() & Qt.ShiftModifier or abs(d.x()) > abs(d.y()):
            self.hoff = max(0, self.hoff - (d.x() or d.y()) // 2)
        else:
            maxv = max(0, self.content_height() - (self.height() - HEADER_H))
            self.voff = max(0, min(maxv, self.voff - d.y() // 4))
        self.scrolled.emit()
        self.update()
        e.accept()

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self.scrolled.emit()

    def set_cell_width(self, w: int):
        self.cell_w = max(10, min(48, w))
        self.scrolled.emit()
        self.update()


class Timeline(QWidget):
    """Таймлайн с панелью управления воспроизведением."""

    def __init__(self, project: Project, state: EditorState, actions: dict, parent=None):
        super().__init__(parent)
        self.setObjectName("panel")
        self.project = project
        self.state = state

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        bar = QFrame()
        bar.setStyleSheet(f"QFrame {{ background:{theme.BG_PANEL}; border-bottom:1px solid {theme.BORDER}; }}"
                          "QLabel, QToolButton { border:none; }")
        bl = QHBoxLayout(bar)
        bl.setContentsMargins(8, 4, 8, 4)
        bl.setSpacing(2)

        def btn(key):
            b = QToolButton()
            b.setDefaultAction(actions[key])
            b.setIconSize(QSize(18, 18))
            b.setAutoRaise(True)
            bl.addWidget(b)
            return b

        def sep():
            line = QFrame()
            line.setFixedSize(1, 18)
            line.setStyleSheet(f"background:{theme.BORDER};")
            bl.addSpacing(6)
            bl.addWidget(line)
            bl.addSpacing(6)

        for k in ("track_add_video", "track_add_audio", "track_delete"):
            btn(k)
        sep()
        for k in ("key", "key_blank", "frame_insert", "frame_remove"):
            btn(k)
        sep()
        for k in ("first", "prev", "play", "next", "last", "loop"):
            btn(k)
        sep()
        btn("onion")
        sep()
        btn("record_audio")
        btn("import_audio")
        bl.addStretch()

        self.counter = QLabel()
        self.counter.setObjectName("frameCounter")
        bl.addWidget(self.counter)
        sep()
        bl.addWidget(QLabel("FPS"))
        self.fps = QSpinBox()
        self.fps.setRange(1, 60)
        self.fps.setValue(project.fps)
        self.fps.setFixedWidth(48)
        self.fps.setAlignment(Qt.AlignCenter)
        bl.addWidget(self.fps)
        bl.addSpacing(10)
        bl.addWidget(QLabel("Кадров"))
        self.length = QSpinBox()
        self.length.setRange(1, 9999)
        self.length.setFixedWidth(58)
        self.length.setAlignment(Qt.AlignCenter)
        bl.addWidget(self.length)
        sep()
        zoom_icon = QLabel()
        zoom_icon.setPixmap(icons.pixmap("zoom", theme.TEXT_MUTED, 16))
        bl.addWidget(zoom_icon)
        self.zoom = QSlider(Qt.Horizontal)
        self.zoom.setRange(10, 48)
        self.zoom.setFixedWidth(90)
        bl.addWidget(self.zoom)
        root.addWidget(bar)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)
        self.canvas = TimelineCanvas(project, state, actions)
        self.vbar = QScrollBar(Qt.Vertical)
        body.addWidget(self.canvas, 1)
        body.addWidget(self.vbar)
        root.addLayout(body, 1)
        self.hbar = QScrollBar(Qt.Horizontal)
        root.addWidget(self.hbar)

        self.zoom.setValue(self.canvas.cell_w)
        self.zoom.valueChanged.connect(self.canvas.set_cell_width)
        self.hbar.valueChanged.connect(self._on_hbar)
        self.vbar.valueChanged.connect(self._on_vbar)
        self.canvas.scrolled.connect(self._sync_bars)
        self.fps.valueChanged.connect(self._on_fps)
        self.length.editingFinished.connect(lambda: project.set_frame_count(self.length.value()))
        project.frameChanged.connect(self._on_frame)
        project.structureChanged.connect(self._on_structure)
        self._on_structure()

    def _on_fps(self, v):
        if v != self.project.fps:
            self.project.fps = v
            self.project.mark_dirty()

    def _on_hbar(self, v):
        self.canvas.hoff = v
        self.canvas.update()

    def _on_vbar(self, v):
        self.canvas.voff = v
        self.canvas.update()

    def _sync_bars(self):
        c = self.canvas
        self.hbar.blockSignals(True)
        self.hbar.setRange(0, max(0, c.content_width() - c.grid_width()))
        self.hbar.setPageStep(max(1, c.grid_width()))
        self.hbar.setSingleStep(c.cell_w)
        self.hbar.setValue(c.hoff)
        self.hbar.blockSignals(False)
        vis = max(0, c.height() - HEADER_H)
        self.vbar.blockSignals(True)
        self.vbar.setRange(0, max(0, c.content_height() - vis))
        self.vbar.setPageStep(max(1, vis))
        self.vbar.setSingleStep(ROW_H)
        self.vbar.setValue(c.voff)
        self.vbar.blockSignals(False)
        self.vbar.setVisible(c.content_height() > vis)
        if self.zoom.value() != c.cell_w:
            self.zoom.blockSignals(True)
            self.zoom.setValue(c.cell_w)
            self.zoom.blockSignals(False)

    def _on_frame(self, f):
        self.counter.setText(f"{f + 1:>3} / {self.project.frame_count}")
        self.canvas.ensure_frame_visible(f)

    def _on_structure(self):
        for sb, v in ((self.length, self.project.frame_count), (self.fps, self.project.fps)):
            sb.blockSignals(True)
            sb.setValue(v)
            sb.blockSignals(False)
        self._on_frame(self.project.current_frame)
        self._sync_bars()

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self._sync_bars()
