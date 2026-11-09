"""Монтаж: импорт видео/картинок/GIF, ключевые кадры элементов, пресеты, кривая SAI, обучение.
python -m unittest discover -s tests"""

import os
import subprocess
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtCore import QPoint, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QImage  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from mtoonz import animation, export, fileformat, media  # noqa: E402
from mtoonz.animation import PRESETS, Transform  # noqa: E402
from mtoonz.model import Project  # noqa: E402
from mtoonz.prefs import prefs  # noqa: E402
from mtoonz.render import render_frame  # noqa: E402

app = QApplication.instance() or QApplication(sys.argv)
FFMPEG = export.find_ffmpeg()


def make_media(folder):
    """Тестовое видео 2 с со звуком (красный кадр), картинка (зелёная) и GIF из 3 кадров."""
    video = os.path.join(folder, "клип.mp4")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=red:s=320x240:r=25:d=2",
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=2", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-shortest", video], check=True)
    png = os.path.join(folder, "мем.png")
    img = QImage(200, 100, QImage.Format_ARGB32)
    img.fill(QColor("#00ff00"))
    img.save(png)
    gif = os.path.join(folder, "котик.gif")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=s=64x64:r=10:d=0.3", gif],
                   check=True)
    return video, png, gif


class AnimationTest(unittest.TestCase):
    def test_keys_and_easing(self):
        t = Transform()
        t.set("x", 0, 0.0, auto_key=True, easing="linear")
        t.set("x", 10, 100.0, auto_key=True)
        self.assertAlmostEqual(t.value("x", 5), 50)
        t.set_easing(["x"], 0, "in")
        self.assertLess(t.value("x", 5), 20)          # разгон: в середине ещё медленно
        t.set_easing(["x"], 0, "hold")
        self.assertEqual(t.value("x", 9), 0)          # скачком
        self.assertEqual(t.value("x", 99), 100)
        t.set("x", 5, 30.0)                            # анимировано — ставит ключ
        self.assertEqual(t.key_frames(), [0, 5, 10])
        t2 = Transform.from_dict(t.to_dict())
        self.assertEqual(t2.to_dict(), t.to_dict())
        t.set_animated(["x"], 5, False)
        self.assertFalse(t.animated("x"))
        self.assertEqual(t.value("x", 0), 30)

    def test_all_easings_end_at_target(self):
        for name in animation.EASINGS:
            if name != "hold":
                self.assertAlmostEqual(animation.ease(name, 1.0), 1.0, places=3, msg=name)
            self.assertAlmostEqual(animation.ease(name, 0.0), 0.0, places=3, msg=name)

    def test_every_preset(self):
        for pr in PRESETS:
            t = Transform()
            n = animation.apply_preset(t, pr, 0, 24, 400, 300)
            self.assertTrue(t.keys, pr.key)
            v = t.values(n)
            # к концу появления/анимации элемент возвращается на место; исчезновение — уходит
            if pr.kind != "out":
                self.assertAlmostEqual(v["x"], 0, delta=1e-6, msg=pr.key)
                self.assertAlmostEqual(v["sx"], 1, delta=1e-6, msg=pr.key)
                self.assertAlmostEqual(v["opacity"], 1, delta=1e-6, msg=pr.key)
            else:
                self.assertTrue(v["opacity"] < 0.01 or abs(v["x"]) > 100 or v["sx"] < 0.01, pr.key)

    def test_corner_pin_perspective(self):
        v = dict(animation.DEFAULTS)
        v["c1y"] = 50
        t = animation.element_transform(v, 100, 100, 50, 50)
        self.assertIsNotNone(t)
        p = t.map(QPointF(100, 0))
        self.assertAlmostEqual(p.y(), 50, places=3)


@unittest.skipIf(FFMPEG is None, "нет FFmpeg")
class MontageTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.TemporaryDirectory()
        cls.video, cls.png, cls.gif = make_media(cls.dir.name)

    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()

    def setUp(self):
        prefs().set("general/tutorial_done", True)
        from mtoonz.app import MainWindow
        self.w = MainWindow()
        self.w.resize(1300, 850)
        self.w.show()
        self.p = self.w.project
        self.p.reset(name="Монтаж", width=640, height=360, fps=25, frame_count=25)

    def tearDown(self):
        self.p.undo_stack.setClean()
        self.w._reset_media()
        self.w.close()

    def test_probe(self):
        info = media.probe(self.video)
        self.assertEqual((info.kind, info.width, info.height, info.has_audio), ("video", 320, 240, True))
        self.assertAlmostEqual(info.duration, 2.0, delta=0.1)
        self.assertEqual(media.probe(self.gif).kind, "gif")
        self.assertEqual(media.probe(self.png).width, 200)

    def test_import_render_save_export(self):
        n = self.w.import_files([self.video, self.png, self.gif], frame=0)
        self.assertEqual(n, 3)
        vclips = [c for t in self.p.tracks if t.kind == "video" for c in t.clips]
        self.assertEqual([c.kind for c in vclips], ["video", "image", "gif"])
        v, img, gif = vclips
        self.assertEqual((v.start, v.length), (0, 50))          # 2 с при 25 fps
        self.assertEqual(img.start, 50)                          # картинки встают друг за другом
        self.assertEqual(img.length, 75)                         # картинка — 3 с
        audio_clips = [c for t in self.p.tracks if t.kind == "audio" for c in t.clips]
        self.assertEqual(len(audio_clips), 1)                    # звук видео — на звуковой дорожке
        self.assertEqual(audio_clips[0].start, 0)
        self.assertGreaterEqual(self.p.frame_count, 50 + 75 + 25)

        # видео видно в кадре: красный по центру; картинка — зелёная
        frame = render_frame(self.p, 10)
        c = frame.pixelColor(320, 180)
        self.assertGreater(c.red(), 200)
        self.assertLess(c.green(), 60)
        self.assertGreater(render_frame(self.p, 60).pixelColor(320, 180).green(), 200)

        # ключи: картинка уезжает вправо — в центре остаётся белый фон
        self.p.select(("clip", img.id))
        self.p.set_frame(50)
        self.p.edit_element("x", lambda t, f: t.set("x", f, 0.0, auto_key=True))
        self.p.set_frame(74)
        self.p.edit_element("x", lambda t, f: t.set("x", f, 600.0))
        mid = render_frame(self.p, 74).pixelColor(320, 180)
        self.assertGreater(mid.red(), 240)                       # фон белый
        self.assertGreater(render_frame(self.p, 50).pixelColor(320, 180).green(), 200)

        # сохранение и открытие: клипы, ключи и медиа внутри файла
        path = os.path.join(self.dir.name, "монтаж.mtoonz")
        fileformat.save_project(self.p, path)
        q = Project()
        fileformat.load_project(path, q)
        qv = [c for t in q.tracks if t.kind == "video" for c in t.clips]
        self.assertEqual([c.kind for c in qv], ["video", "image", "gif"])
        self.assertEqual(qv[1].transform.key_frames(), [0, 24])
        self.assertTrue(all(os.path.exists(q.media[c.media_id]) for c in qv))
        self.assertGreater(render_frame(q, 10).pixelColor(320, 180).red(), 200)

        # экспорт MP4 из проекта с видео
        out = os.path.join(self.dir.name, "out.mp4")
        s = export.ExportSettings("mp4", out, 0, 59, 320, 180, 25)
        export.export(self.p, s)
        self.assertGreater(os.path.getsize(out), 1000)

    def test_split_trim_speed(self):
        self.w.import_files([self.video], frame=0)
        clip = next(c for t in self.p.tracks if t.kind == "video" for c in t.clips)
        self.p.select(("clip", clip.id))
        self.p.edit_element("rot", lambda t, f: (t.set("rot", 0, 0.0, auto_key=True),
                                                 t.set("rot", 40, 90.0, auto_key=True)))
        self.p.set_frame(20)
        self.assertTrue(self.p.split_clip())
        a, b = sorted((c for t in self.p.tracks if t.kind == "video" for c in t.clips), key=lambda c: c.start)
        self.assertEqual((a.start, a.length, b.start, b.length), (0, 20, 20, 30))
        self.assertAlmostEqual(b.offset, 0.8)
        # поворот непрерывен через разрез
        self.assertAlmostEqual(a.transform.value("rot", 19), b.transform.value("rot", -1 + 0), delta=5)
        self.assertAlmostEqual(b.transform.value("rot", 20), 90)
        self.p.undo_stack.undo()
        self.assertEqual(len([c for t in self.p.tracks if t.kind == "video" for c in t.clips]), 1)
        # обрезка слева сдвигает начало в исходнике
        clip = next(c for t in self.p.tracks if t.kind == "video" for c in t.clips)
        self.assertTrue(self.p.trim_clip(clip.id, 10, 40, 0.4))
        clip = next(c for t in self.p.tracks if t.kind == "video" for c in t.clips)
        self.assertEqual((clip.start, clip.length, clip.offset), (10, 40, 0.4))
        self.assertEqual(clip.max_length(25), 40)

    def test_transform_tool_and_inspector(self):
        self.w.import_files([self.png], frame=0)
        clip = next(c for t in self.p.tracks if t.kind == "video" for c in t.clips)
        self.w.state.set_tool("transform")
        c = self.w.canvas
        c.fit_to_view()
        center = c.transform().map(QPointF(320, 180)).toPoint()
        QTest.mousePress(c, Qt.LeftButton, Qt.NoModifier, center)
        QTest.mouseMove(c, center + QPoint(50, 0))
        QTest.mouseRelease(c, Qt.LeftButton, Qt.NoModifier, center + QPoint(50, 0))
        clip = next(cl for t in self.p.tracks if t.kind == "video" for cl in t.clips)
        self.assertEqual(self.p.selection, ("clip", clip.id))
        self.assertAlmostEqual(clip.transform.value("x", 0), 50 / c.zoom, delta=2)
        self.p.undo_stack.undo()
        clip = next(cl for t in self.p.tracks if t.kind == "video" for cl in t.clips)
        self.assertEqual(clip.transform.value("x", 0), 0)
        # панель «Элемент»: библиотека применяет пресет
        insp = self.w.inspector
        self.assertTrue(insp.body.isVisibleTo(insp))
        row = next(i for i in range(insp.library.count()) if insp.library.item(i).data(Qt.UserRole) == "pop")
        insp.library.setCurrentRow(row)
        insp.apply_preset()
        clip = next(cl for t in self.p.tracks if t.kind == "video" for cl in t.clips)
        self.assertTrue(clip.transform.animated("sx"))
        self.assertEqual(clip.transform.value("sx", 0), 0)
        # ◆ и скорость
        insp.spins["rot"].setValue(30)
        clip = next(cl for t in self.p.tracks if t.kind == "video" for cl in t.clips)
        self.assertEqual(clip.transform.value("rot", 0), 30)

    def test_layer_as_element(self):
        from mtoonz.model import Stroke
        layer = self.p.layers[0]
        self.p.add_stroke(Stroke(((300, 180, 1), (340, 180, 1)), QColor("black"), 20))
        self.p.select(("layer", layer.id))
        self.p.edit_element("сдвиг", lambda t, f: t.set("y", f, 100.0))
        img = render_frame(self.p, 0)
        self.assertGreater(img.pixelColor(320, 180).red(), 240)   # исходное место пустое
        self.assertLess(img.pixelColor(320, 280).red(), 60)       # рисунок съехал вниз


class CurveToolTest(unittest.TestCase):
    def test_sai_curve_passes_through_points(self):
        prefs().set("general/tutorial_done", True)
        from mtoonz.app import MainWindow
        w = MainWindow()
        w.resize(1200, 800)
        w.show()
        c, p = w.canvas, w.project
        w.state.set_tool("curve")
        pts = [QPoint(300, 400), QPoint(400, 250), QPoint(520, 420), QPoint(640, 300)]
        for pt in pts:
            QTest.mouseClick(c, Qt.LeftButton, Qt.NoModifier, pt)
        QTest.keyClick(c, Qt.Key_Backspace)          # убрать последнюю
        QTest.mouseClick(c, Qt.LeftButton, Qt.NoModifier, pts[-1])
        QTest.keyClick(c, Qt.Key_Return)
        s = p.layers[0].keys[0].strokes[-1]
        for pt in pts:
            sc = c.to_scene(QPointF(pt))
            d = min(abs(x - sc.x()) + abs(y - sc.y()) for x, y, _ in s.points)
            self.assertLess(d, 1.0)
        self.assertIsNone(c._sai)
        p.undo_stack.setClean()

    def test_tutorial_walkthrough(self):
        from mtoonz.app import MainWindow
        from mtoonz.widgets.tutorial import TutorialOverlay
        prefs().set("general/tutorial_done", False)
        w = MainWindow()
        w.resize(1300, 850)
        w.show()
        w.maybe_tutorial()
        tour = w._tutorial
        self.assertIsInstance(tour, TutorialOverlay)
        for i in range(len(tour.steps)):
            self.assertEqual(tour.index, i)
            self.assertFalse(tour.grab().isNull())
            b = tour.bubble.geometry()
            self.assertTrue(tour.rect().contains(b), f"облачко шага {i} за пределами окна")
            target = tour.target_rect()
            if target is not None and target.width() < tour.width() * 0.6 and target.height() < tour.height() * 0.6:
                self.assertFalse(b.intersects(target), f"облачко шага {i} закрывает подсвеченное")
            tour.go(i + 1)
        self.assertTrue(prefs().get("general/tutorial_done"))


if __name__ == "__main__":
    unittest.main()
