"""Кисти, звуковые слои и новые диалоги: python -m unittest discover -s tests"""

import math
import os
import struct
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtGui import QColor, QImage, QPainter  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from mtoonz import audio, fileformat  # noqa: E402
from mtoonz.brushes import ERASER_PRESETS, PRESETS, BrushParams, draw_brush_stroke, preview_points  # noqa: E402
from mtoonz.model import AudioLayer, Project, Stroke  # noqa: E402

app = QApplication.instance() or QApplication(sys.argv)


def sine_wav(path, seconds=1.5, rate=8000):
    n = int(seconds * rate)
    pcm = b"".join(struct.pack("<h", int(12000 * math.sin(i * 440 * 2 * math.pi / rate))) for i in range(n))
    audio.write_wav(path, pcm, rate, 1)


class BrushTest(unittest.TestCase):
    def test_every_preset_draws_something(self):
        for preset in PRESETS + ERASER_PRESETS:
            img = QImage(200, 60, QImage.Format_ARGB32_Premultiplied)
            img.fill(0)
            p = QPainter(img)
            p.setRenderHint(QPainter.Antialiasing)
            draw_brush_stroke(p, preview_points(200, 60), QColor("#000000"), max(4, preset.size),
                              preset.params, True, False)
            p.end()
            painted = sum(1 for x in range(0, 200, 2) for y in range(0, 60, 2) if img.pixelColor(x, y).alpha())
            self.assertGreater(painted, 20, preset.key)

    def test_params_roundtrip(self):
        b = BrushParams("calligraphy", angle=30, flat=0.1, taper_end=0.4)
        self.assertEqual(BrushParams.from_dict(b.to_dict()), b)
        self.assertEqual(BrushParams().to_dict(), {})
        self.assertEqual(BrushParams.from_dict({"kind": "spray", "unknown": 1}).kind, "spray")


class AudioTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.dir.cleanup()

    def test_analyze(self):
        path = os.path.join(self.dir.name, "a.wav")
        sine_wav(path, 1.5)
        dur, peaks = audio.analyze_wav(path)
        self.assertAlmostEqual(dur, 1.5, places=3)
        self.assertEqual(len(peaks), 150)
        self.assertAlmostEqual(max(peaks), 12000 / 32768, places=2)

    def test_audio_layer_saved_inside_project(self):
        wav = os.path.join(self.dir.name, "voice.wav")
        sine_wav(wav, 2.0)
        p = Project()
        p.reset(name="Звук", fps=24, frame_count=24)
        dur, peaks = audio.analyze_wav(wav)
        p.add_audio_layer("Голос", "m1", wav, 10, dur, peaks)
        self.assertEqual(p.frame_count, 10 + 48)  # сцена удлинилась под звук
        layer = p.layers[-1]
        self.assertIsInstance(layer, AudioLayer)
        p.move_audio(layer, 4)
        self.assertEqual(layer.start, 4)
        p.undo_stack.undo()
        self.assertEqual(layer.start, 10)
        # на звуковом слое нельзя ставить ключи и рисовать
        p.set_layer(len(p.layers) - 1)
        p.insert_keyframe()
        p.add_stroke(Stroke(((0, 0, 1), (5, 5, 1)), QColor("red"), 3))
        self.assertEqual(layer.keys, {})

        path = os.path.join(self.dir.name, "p.mtoonz")
        fileformat.save_project(p, path)
        os.remove(wav)  # исходник удалён — звук должен быть внутри проекта
        q = Project()
        fileformat.load_project(path, q)
        a = q.layers[-1]
        self.assertIsInstance(a, AudioLayer)
        self.assertEqual((a.name, a.start, a.media_id), ("Голос", 10, "m1"))
        self.assertAlmostEqual(a.duration, 2.0, places=3)
        self.assertTrue(os.path.exists(q.media["m1"]))
        self.assertEqual(len(a.peaks), 200)

    def test_brush_saved(self):
        p = Project()
        p.add_stroke(Stroke(((0, 0, 1), (9, 9, 0.5)), QColor("red"), 3, brush=BrushParams("stamp", texture="chalk")))
        path = os.path.join(self.dir.name, "b.mtoonz")
        fileformat.save_project(p, path)
        q = Project()
        fileformat.load_project(path, q)
        self.assertEqual(q.layers[0].keys[0].strokes[0].brush.texture, "chalk")


class UiTest(unittest.TestCase):
    def test_new_project_aspects(self):
        from mtoonz.widgets.project_browser import NewProjectDialog
        d = NewProjectDialog("X")
        self.assertEqual((d.w.value(), d.h.value()), (1920, 1080))
        d.cards["9:16"].click()
        self.assertEqual((d.w.value(), d.h.value()), (1080, 1920))
        d.cards["1:1"].click()
        self.assertEqual(d.w.value(), d.h.value())
        d._swap()
        d.cards["16:9"].click()
        d.swap.click()
        self.assertEqual((d.w.value(), d.h.value()), (1080, 1920))
        self.assertEqual(d._aspect, "9:16")
        d.w.setValue(1000)
        self.assertEqual(d._aspect, "custom")

    def test_mouse_drawing_and_curve(self):
        from mtoonz.app import MainWindow
        w = MainWindow()
        w.resize(1200, 800)
        w.show()
        QTest.qWait(50)
        c, p = w.canvas, w.project
        QTest.mousePress(c, Qt.LeftButton, Qt.NoModifier, QPoint(300, 300))
        for i in range(30):
            QTest.mouseMove(c, QPoint(300 + i * 8, 300 + int(20 * math.sin(i / 3))))
        QTest.mouseRelease(c, Qt.LeftButton, Qt.NoModifier, QPoint(540, 300))
        s = p.layers[0].keys[0].strokes[-1]
        self.assertEqual(s.brush, PRESETS[0].params)  # «Тушь» по умолчанию
        # стабилизатор дотягивает линию до курсора
        end = c.to_scene(QPoint(540, 300).toPointF())
        self.assertLess(abs(s.points[-1][0] - end.x()), 2)
        # кривая: протянуть, изогнуть, щёлкнуть
        w.state.set_tool("shapes")
        w.state.tool_settings().shape = "curve"
        QTest.mousePress(c, Qt.LeftButton, Qt.NoModifier, QPoint(300, 500))
        QTest.mouseMove(c, QPoint(600, 500))
        QTest.mouseRelease(c, Qt.LeftButton, Qt.NoModifier, QPoint(600, 500))
        QTest.mouseMove(c, QPoint(450, 380))
        QTest.mouseClick(c, Qt.LeftButton, Qt.NoModifier, QPoint(450, 380))
        curve = p.layers[0].keys[0].strokes[-1]
        top = min(pt[1] for pt in curve.points)
        self.assertLess(abs(top - c.to_scene(QPoint(450, 380).toPointF()).y()), 2)
        p.undo_stack.setClean()

    def test_timeline_paints_audio_layer(self):
        from mtoonz.app import MainWindow
        w = MainWindow()
        w.resize(1200, 800)
        w.show()
        d = tempfile.mkdtemp()
        wav = os.path.join(d, "a.wav")
        sine_wav(wav, 1.0)
        dur, peaks = audio.analyze_wav(wav)
        w.project.add_audio_layer("Звук", "m", wav, 2, dur, peaks)
        for cur in (0, 1):  # звуковой слой выбран и не выбран
            w.project.set_layer(cur)
            self.assertFalse(w.timeline.canvas.grab().isNull())
        w.project.undo_stack.setClean()


if __name__ == "__main__":
    unittest.main()
