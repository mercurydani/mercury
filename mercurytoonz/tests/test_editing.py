"""Монтаж: связь видео и звука, обрезка, сжатие/растяжение, кадрирование, громкость, свойства.
python -m unittest discover -s tests"""

import array
import math
import os
import subprocess
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from mtoonz import export, fileformat  # noqa: E402
from mtoonz.model import AudioClip, Project, VisualClip  # noqa: E402
from mtoonz.prefs import prefs  # noqa: E402
from mtoonz.render import render_frame  # noqa: E402

app = QApplication.instance() or QApplication(sys.argv)
FFMPEG = export.find_ffmpeg()


def clips(p, cls):
    return sorted((c for t in p.tracks for c in t.clips if isinstance(c, cls)), key=lambda c: c.start)


def rms_windows(path, win=0.1):
    """Громкость (RMS) по окнам 0.1 с из любого звукового файла."""
    raw = subprocess.run([FFMPEG, "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", "8000", "-"],
                         capture_output=True).stdout
    a = array.array("h")
    a.frombytes(raw[: len(raw) // 2 * 2])
    n = int(8000 * win)
    return [math.sqrt(sum(x * x for x in a[i:i + n]) / max(1, len(a[i:i + n]))) / 32768 for i in range(0, len(a), n)]


@unittest.skipIf(FFMPEG is None, "нет FFmpeg")
class LinkedEditingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.TemporaryDirectory()
        cls.video = os.path.join(cls.dir.name, "клип.mp4")
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=red:s=320x240:r=25:d=2",
                        "-f", "lavfi", "-i", "sine=frequency=440:duration=2", "-c:v", "libx264", "-pix_fmt",
                        "yuv420p", "-c:a", "aac", "-shortest", cls.video], check=True)

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
        self.w.import_files([self.video], frame=0)
        (self.v,), (self.a,) = clips(self.p, VisualClip), clips(self.p, AudioClip)

    def tearDown(self):
        self.p.undo_stack.setClean()
        self.p._extra_dirty = False
        self.w._reset_media()
        self.w.close()

    def pair(self):
        (v,), (a,) = clips(self.p, VisualClip), clips(self.p, AudioClip)
        return v, a

    def test_import_links_video_and_sound(self):
        self.assertEqual((self.v.link, self.a.link), (self.a.id, self.v.id))
        self.assertAlmostEqual(self.a.duration, 2.0, delta=0.05)

    def test_move_trim_split_delete_together(self):
        p = self.p
        self.assertTrue(p.move_clip(self.v.id, 10))
        v, a = self.pair()
        self.assertEqual((v.start, a.start), (10, 10))
        self.assertTrue(p.move_clip(a.id, 5))           # тянем звук — едет и видео
        v, a = self.pair()
        self.assertEqual(v.start, 5)
        # обрезка слева: начало в исходнике у обоих
        self.assertTrue(p.trim_clip(v.id, 15, 40, 0.4))
        v, a = self.pair()
        self.assertEqual((a.start, a.offset), (15, 0.4))
        self.assertAlmostEqual(a.duration, 40 / 25)
        # разрезание: обе половины связаны между собой
        p.set_frame(30)
        self.assertTrue(p.split_clip(v.id))
        vs, aus = clips(p, VisualClip), clips(p, AudioClip)
        self.assertEqual([c.start for c in vs], [15, 30])
        self.assertEqual([c.start for c in aus], [15, 30])
        self.assertEqual(vs[1].link, aus[1].id)
        self.assertAlmostEqual(aus[1].offset, 0.4 + 15 / 25)
        # удаление видео удаляет и звук; отмена — всё возвращает
        p.delete_clip(vs[1].id)
        self.assertEqual((len(clips(p, VisualClip)), len(clips(p, AudioClip))), (1, 1))
        p.undo_stack.undo()
        self.assertEqual((len(clips(p, VisualClip)), len(clips(p, AudioClip))), (2, 2))

    def test_unlink(self):
        self.p.unlink(self.v.id)
        self.p.move_clip(self.v.id, 20)
        v, a = self.pair()
        self.assertEqual((v.start, a.start, v.link, a.link), (20, 0, "", ""))

    def test_speed_squeezes_and_stretches(self):
        self.assertTrue(self.p.set_speed(self.v.id, 2.0))
        v, a = self.pair()
        self.assertEqual((v.length, v.speed, a.speed), (25, 2.0, 2.0))
        self.assertAlmostEqual(a.duration, 1.0)
        self.assertTrue(self.p.set_speed(v.id, 0.5))       # растянуть: тот же кусок, вчетверо дольше
        v, a = self.pair()
        self.assertEqual(v.length, 100)
        self.assertAlmostEqual(a.duration, 4.0)

    def test_alt_drag_edge_stretches(self):
        tl = self.w.timeline.canvas
        row = next(i for i, t in enumerate(self.p.tracks) if self.v in t.clips)
        y = int(tl.row_y(row) + 15)
        x_end = int(tl.frame_x(self.v.end_frame()))
        QTest.mousePress(tl, Qt.LeftButton, Qt.AltModifier, QPoint(x_end, y))
        QTest.mouseMove(tl, QPoint(x_end + 25 * tl.cell_w, y))
        QTest.mouseRelease(tl, Qt.LeftButton, Qt.AltModifier, QPoint(x_end + 25 * tl.cell_w, y))
        v, a = self.pair()
        self.assertEqual(v.length, 75)
        self.assertAlmostEqual(v.speed, 50 / 75, places=3)
        self.assertAlmostEqual(a.duration, 3.0, places=2)

    def test_plain_drag_edge_trims(self):
        tl = self.w.timeline.canvas
        row = next(i for i, t in enumerate(self.p.tracks) if self.v in t.clips)
        y = int(tl.row_y(row) + 15)
        x0 = int(tl.frame_x(0)) + 1
        QTest.mousePress(tl, Qt.LeftButton, Qt.NoModifier, QPoint(x0, y))
        QTest.mouseMove(tl, QPoint(x0 + 10 * tl.cell_w, y))
        QTest.mouseRelease(tl, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + 10 * tl.cell_w, y))
        v, a = self.pair()
        self.assertEqual((v.start, v.length, a.start), (10, 40, 10))
        self.assertAlmostEqual(v.offset, 0.4)
        self.assertAlmostEqual(a.offset, 0.4)

    def test_save_load_keeps_edits(self):
        p = self.p
        p.trim_clip(self.a.id, 5, 30, 0.2)
        p.set_clip_attrs(self.a.id, fade_in=0.3, fade_out=0.4, volume=0.5)
        p.set_clip_attrs(self.v.id, crop=(0.1, 0.0, 0.2, 0.0), name="Красный")
        path = os.path.join(self.dir.name, "p.mtoonz")
        fileformat.save_project(p, path)
        q = Project()
        fileformat.load_project(path, q)
        (v,), (a,) = clips(q, VisualClip), clips(q, AudioClip)
        self.assertEqual((v.name, v.crop, v.link), ("Красный", (0.1, 0.0, 0.2, 0.0), a.id))
        self.assertEqual((a.start, a.offset, a.fade_in, a.fade_out, a.volume), (5, 0.2, 0.3, 0.4, 0.5))
        self.assertAlmostEqual(a.duration, 30 / 25)
        self.assertAlmostEqual(a.source_duration, 2.0, delta=0.05)

    def test_export_audio_fades_and_speed(self):
        p = self.p
        p.unlink(self.v.id)
        p.set_clip_attrs(self.a.id, fade_in=0.5, fade_out=0.5)
        out = os.path.join(self.dir.name, "fade.mp3")
        export.export(p, export.ExportSettings("mp3", out, 0, 49, 2, 2, 25))
        r = rms_windows(out)
        self.assertLess(r[1], r[9] * 0.5)       # в начале тихо — нарастание
        self.assertLess(r[18], r[9] * 0.5)      # в конце тихо — затухание
        self.assertGreater(r[9], 0.03)
        # скорость ×2: звук длится 1 с
        p.set_clip_attrs(self.a.id, fade_in=0.0, fade_out=0.0)
        p.set_speed(self.a.id, 2.0)
        out2 = os.path.join(self.dir.name, "fast.mp3")
        export.export(p, export.ExportSettings("mp3", out2, 0, 49, 2, 2, 25))
        r2 = rms_windows(out2)
        loud = [i for i, x in enumerate(r2) if x > 0.02]
        self.assertAlmostEqual(len(loud) * 0.1, 1.0, delta=0.15)

    def test_crop_render(self):
        self.p.set_clip_attrs(self.v.id, crop=(0.5, 0.0, 0.0, 0.0))
        img = render_frame(self.p, 5)
        # видео вписано по высоте: 480×360 по центру; левая половина видео скрыта — там белый фон
        self.assertGreater(img.pixelColor(150, 180).green(), 240)
        self.assertLess(img.pixelColor(450, 180).green(), 60)

    def test_inspector_for_everything(self):
        insp = self.w.inspector
        p = self.p
        p.select(("clip", self.a.id))
        self.assertTrue(insp.audio_box.isVisibleTo(insp))
        self.assertTrue(insp.link_box.isVisibleTo(insp))
        insp.a_volume.setValue(150)
        self.assertAlmostEqual(self.pair()[1].volume, 1.5)
        insp.name.setText("Голос")
        insp._rename()
        self.assertEqual(self.pair()[1].name, "Голос")
        # дорожка
        track = p.tracks[-1]
        p.select(("track", track.id))
        self.assertTrue(insp.track_box.isVisibleTo(insp))
        insp.t_enabled.setChecked(False)
        self.assertFalse(track.enabled)
        insp.name.setText("Музыка")
        insp._rename()
        self.assertEqual(p.tracks[-1].name, "Музыка")
        # слой
        layer = p.layers[0]
        p.select(("layer", layer.id))
        self.assertTrue(insp.layer_box.isVisibleTo(insp))
        self.assertTrue(insp.body.isVisibleTo(insp))   # слой тоже можно анимировать
        insp.l_opacity.setValue(40)
        self.assertAlmostEqual(layer.opacity, 0.4)
        # видео: кадрирование из панели
        p.select(("clip", self.v.id))
        insp.crops[0].setValue(20)
        self.assertAlmostEqual(self.pair()[0].crop[0], 0.2)
        self.assertFalse(insp.audio_box.isVisibleTo(insp))


if __name__ == "__main__":
    unittest.main()
