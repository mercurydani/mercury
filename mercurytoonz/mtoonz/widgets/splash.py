"""Заставка при запуске: планета прыгает со «сплющиванием», под звук; затем логотип и название.

Щелчок или любая клавиша — пропустить. Включается/выключается в настройках.
"""

from __future__ import annotations

import math
import random

from PySide6.QtCore import QElapsedTimer, QPointF, QRectF, Qt, QTimer, QUrl, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPainterPath, QRadialGradient
from PySide6.QtWidgets import QWidget

from .. import APP_VERSION, brand, theme

W, H = 620, 400
PLANET_R = 50
GROUND_Y = 214           # где нижний край планеты касается «земли»
DURATION = 2.9           # сколько длится заставка, секунды
FADE_OUT = 0.3


def _ease_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


class SplashScreen(QWidget):
    finished = Signal()

    def __init__(self, play_sound: bool = True):
        super().__init__(None, Qt.SplashScreen | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setFixedSize(W, H)
        self.setCursor(Qt.PointingHandCursor)
        rnd = random.Random(7)
        self.stars = [(rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(0.4, 1.6), rnd.uniform(0, 6.28))
                      for _ in range(110)]
        self.hits = brand.bounce_schedule()
        self.status = "Загрузка…"
        self._clock = QElapsedTimer()
        self._timer = QTimer(self)
        self._timer.setInterval(16)
        self._timer.timeout.connect(self._tick)
        self._done = False
        self._sound = None
        if play_sound:
            self._prepare_sound()

    # ---------- звук ----------
    def _prepare_sound(self):
        try:
            from PySide6.QtMultimedia import QSoundEffect
            effect = QSoundEffect(self)
            effect.setSource(QUrl.fromLocalFile(brand.startup_sound_path()))
            effect.setVolume(0.7)
            self._sound = effect
        except Exception:  # нет звуковой подсистемы — просто без звука
            self._sound = None

    # ---------- жизненный цикл ----------
    def start(self):
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen is not None:
            self.move(screen.center().x() - W // 2, screen.center().y() - H // 2)
        self.show()
        self._clock.start()
        self._timer.start()
        if self._sound is not None:
            self._sound.play()

    def elapsed(self) -> float:
        return self._clock.elapsed() / 1000 if self._clock.isValid() else 0.0

    def set_status(self, text: str):
        self.status = text
        self.update()

    def skip(self):
        self._finish()

    def _finish(self):
        if self._done:
            return
        self._done = True
        self._timer.stop()
        if self._sound is not None:
            self._sound.stop()
        self.hide()
        self.finished.emit()

    def _tick(self):
        if self.elapsed() >= DURATION:
            self._finish()
        else:
            self.update()

    def mousePressEvent(self, _):
        self.skip()

    def keyPressEvent(self, _):
        self.skip()

    # ---------- кадр анимации ----------
    def planet_state(self, t: float):
        """Центр планеты, сплющивание sx/sy, прорисовка кольца — для момента t."""
        h, v = brand.planet_height(t)
        cx = W / 2
        sx = sy = 1.0
        v0 = self.hits[0][1]
        # сплющивание в момент касания и чуть после
        for th, vh in self.hits:
            dt = t - th
            if -0.025 < dt < 0.09:
                k = 0.32 * (vh / v0) * math.cos(max(0.0, dt) / 0.09 * math.pi / 2)
                sx, sy = 1 + k, 1 - k
                break
        else:
            if abs(v) > 1:  # в полёте — вытягиваемся по скорости
                k = 0.14 * min(1.0, abs(v) / v0)
                sx, sy = 1 - k * 0.6, 1 + k
        cy = GROUND_Y - h - PLANET_R * sy
        last = self.hits[-1][0]
        ring = _ease_out((t - last - 0.05) / 0.45)
        return QPointF(cx, cy), sx, sy, ring

    def paintEvent(self, _):
        t = self.elapsed()
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        alpha = 1.0
        if t > DURATION - FADE_OUT:
            alpha = max(0.0, (DURATION - t) / FADE_OUT)
        p.setOpacity(alpha)

        # фон: чёрный космос со звёздами, как на сайте студии
        frame = QPainterPath()
        frame.addRoundedRect(QRectF(0.5, 0.5, W - 1, H - 1), 18, 18)
        p.setClipPath(frame)
        p.fillRect(self.rect(), QColor(theme.SPACE_NIGHT))
        glow = QRadialGradient(QPointF(W / 2, GROUND_Y - 30), 330)
        glow.setColorAt(0, QColor(47, 98, 240, 46))
        glow.setColorAt(1, QColor(47, 98, 240, 0))
        p.fillRect(self.rect(), glow)
        p.setPen(Qt.NoPen)
        for x, y, r, ph in self.stars:
            a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2.2 + ph))
            p.setBrush(QColor(255, 255, 255, int(170 * a)))
            p.drawEllipse(QPointF(x, y), r * 0.6, r * 0.6)

        c, sx, sy, ring = self.planet_state(t)
        # тень на «земле»
        h = GROUND_Y - (c.y() + PLANET_R * sy)
        k = max(0.25, 1 - h / 200)
        shadow = QRadialGradient(QPointF(c.x(), GROUND_Y + 4), PLANET_R * 1.1 * k)
        shadow.setColorAt(0, QColor(74, 108, 255, int(120 * k)))
        shadow.setColorAt(1, QColor(74, 108, 255, 0))
        p.setBrush(shadow)
        p.save()
        p.translate(c.x(), GROUND_Y + 4)
        p.scale(1, 0.22)
        p.drawEllipse(QPointF(0, 0), PLANET_R * 1.1 * k * sx, PLANET_R * 1.1 * k * sx)
        p.restore()

        brand.draw_planet(p, c, PLANET_R, sx, sy, ring)
        if ring > 0.6:
            sp = _ease_out((ring - 0.6) / 0.4)
            brand.draw_sparkle(p, QPointF(c.x() + PLANET_R * 1.25, c.y() - PLANET_R * 1.0), 13 * sp,
                               QColor(255, 255, 255))

        # название
        last = self.hits[-1][0]
        a_text = _ease_out((t - last - 0.15) / 0.5)
        if a_text > 0:
            p.save()
            p.setOpacity(alpha * a_text)
            p.translate(0, 14 * (1 - a_text))
            brand.draw_wordmark(p, QRectF(0, GROUND_Y + 34, W, 60), 46)
            p.restore()

        # подпись внизу
        p.setOpacity(alpha * 0.85)
        f = QFont()
        f.setPixelSize(11)
        p.setFont(f)
        p.setPen(QColor(theme.TEXT_MUTED))
        p.drawText(QRectF(22, H - 34, W / 2, 20), Qt.AlignLeft | Qt.AlignVCenter, self.status)
        p.drawText(QRectF(W / 2, H - 34, W / 2 - 22, 20), Qt.AlignRight | Qt.AlignVCenter,
                   f"версия {APP_VERSION} · mercurystudio.pro")
        # полоска загрузки
        prog = min(1.0, t / (DURATION - FADE_OUT))
        p.setOpacity(alpha)
        p.setBrush(QColor(255, 255, 255, 20))
        p.drawRoundedRect(QRectF(22, H - 12, W - 44, 3), 1.5, 1.5)
        p.setBrush(QColor(theme.MERCURY_BLUE))
        p.drawRoundedRect(QRectF(22, H - 12, (W - 44) * prog, 3), 1.5, 1.5)

        # рамка
        p.setClipping(False)
        p.setOpacity(alpha)
        p.setBrush(Qt.NoBrush)
        p.setPen(QColor(255, 255, 255, 22))
        p.drawPath(frame)
        p.end()
