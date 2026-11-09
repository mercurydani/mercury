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
from mtoonz.model import Project, Stroke  # noqa: E402

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

    def test_audio_clip_saved_inside_project(self):
        wav = os.path.join(self.dir.name, "voice.wav")
        sine_wav(wav, 2.0)
        p = Project()
        p.reset(name="Звук", fps=24, frame_count=24)
        self.assertEqual([t.kind for t in p.tracks], ["video", "audio"])
        dur, peaks = audio.analyze_wav(wav)
        clip = p.add_audio_clip("Голос", "m1", wav, 10, dur, peaks)
        self.assertEqual(p.frame_count, 10 + 48)  # сцена удлинилась под звук
        self.assertIs(p.tracks[1].clips[0], clip)
        self.assertTrue(p.move_clip(clip.id, 4))
        self.assertEqual(p.tracks[1].clips[0].start, 4)
        p.undo_stack.undo()
        self.assertEqual(p.tracks[1].clips[0].start, 10)
        # второй клип в то же место уходит на новую дорожку, а не поверх первого
        p.add_audio_clip("Музыка", "m2", wav, 12, dur, peaks)
        self.assertEqual([len(t.clips) for t in p.tracks if t.kind == "audio"], [1, 1])
        # перенос между дорожками и запрет наложения
        a1, a2 = [t for t in p.tracks if t.kind == "audio"]
        self.assertFalse(p.move_clip(a2.clips[0].id, 12, a1))
        self.assertTrue(p.move_clip(a2.clips[0].id, 60, a1))
        self.assertEqual((len(a1.clips), len(a2.clips)), (2, 0))
        # видеодорожки добавляются над звуком; «Анимацию» удалить нельзя
        p.add_track("video")
        self.assertEqual([t.kind for t in p.tracks], ["video", "video", "audio", "audio"])
        p.set_track(0)
        p.delete_track()
        self.assertTrue(p.tracks[0].animation)

        path = os.path.join(self.dir.name, "p.mtoonz")
        fileformat.save_project(p, path)
        os.remove(wav)  # исходник удалён — звук должен быть внутри проекта
        q = Project()
        fileformat.load_project(path, q)
        self.assertEqual([t.kind for t in q.tracks], ["video", "video", "audio", "audio"])
        clips = q.tracks[2].clips
        self.assertEqual(sorted((c.name, c.start) for c in clips), [("Голос", 10), ("Музыка", 60)])
        self.assertAlmostEqual(clips[0].duration, 2.0, places=3)
        self.assertTrue(os.path.exists(q.media["m1"]))
        self.assertEqual(len(clips[0].peaks), 200)

    def test_v1_audio_layers_become_tracks(self):
        import json
        import zipfile
        wav = os.path.join(self.dir.name, "v.wav")
        sine_wav(wav, 1.0)
        path = os.path.join(self.dir.name, "old.mtoonz")
        data = {"format": "mercurytoonz", "version": 1, "name": "Старый",
                "scene": {"width": 640, "height": 360, "fps": 12, "frames": 24},
                "layers": [{"id": "a", "type": "drawing", "name": "Слой 1", "keys": {"0": {"strokes": []}}},
                           {"id": "b", "type": "audio", "name": "Запись 1", "media": "m1", "start": 3}],
                "media": [{"id": "m1", "file": "media/m1.wav"}]}
        with zipfile.ZipFile(path, "w") as z:
            z.writestr("project.json", json.dumps(data))
            z.write(wav, "media/m1.wav")
        q = Project()
        fileformat.load_project(path, q)
        self.assertEqual([l.name for l in q.layers], ["Слой 1"])
        self.assertEqual([t.kind for t in q.tracks], ["video", "audio"])
        self.assertEqual((q.tracks[1].clips[0].name, q.tracks[1].clips[0].start), ("Запись 1", 3))

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

    def test_timeline_and_layers_panel_paint(self):
        from mtoonz.app import MainWindow
        w = MainWindow()
        w.resize(1200, 800)
        w.show()
        d = tempfile.mkdtemp()
        wav = os.path.join(d, "a.wav")
        sine_wav(wav, 1.0)
        dur, peaks = audio.analyze_wav(wav)
        w.project.add_audio_clip("Звук", "m", wav, 2, dur, peaks)
        w.project.add_track("video")
        w.project.add_layer()
        for cur in range(len(w.project.tracks)):  # звуковая дорожка выбрана и не выбрана
            w.project.set_track(cur)
            self.assertFalse(w.timeline.canvas.grab().isNull())
        self.assertFalse(w.layers_panel.grab().isNull())
        # перетаскивание слоя в панели меняет порядок
        names = [l.name for l in w.project.layers]
        w.project.move_layer_to(0, 1)
        self.assertEqual([l.name for l in w.project.layers], names[::-1])
        w.project.undo_stack.setClean()

if __name__ == "__main__":
    unittest.main()
