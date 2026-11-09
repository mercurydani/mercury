"""Экспорт во все форматы: python -m unittest discover -s tests"""

import math
import os
import re
import struct
import subprocess
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtGui import QColor, QGuiApplication, QImage  # noqa: E402

from mtoonz import audio, export  # noqa: E402
from mtoonz.export import ExportSettings  # noqa: E402
from mtoonz.model import Project, Stroke  # noqa: E402

app = QGuiApplication.instance() or QGuiApplication(sys.argv)
FFMPEG = export.find_ffmpeg()


def probe(path):
    """Длительность и описание потоков по выводу ffmpeg -i."""
    r = subprocess.run([FFMPEG, "-hide_banner", "-i", path], capture_output=True, text=True)
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr)
    dur = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3)) if m else None
    return dur, r.stderr


def video_frames(path) -> int:
    r = subprocess.run([FFMPEG, "-i", path, "-map", "0:v", "-f", "null", "-"], capture_output=True, text=True)
    return int(re.findall(r"frame=\s*(\d+)", r.stderr)[-1])


def make_project(folder):
    p = Project()
    p.reset(name="Экспорт", width=321, height=181, fps=12, frame_count=24)
    for f in (0, 12):
        p.set_frame(f)
        if f:
            p.insert_keyframe(blank=True)
        p.add_stroke(Stroke(((20 + f * 10, 90, 1), (200, 90 + f, 1)), QColor("#e8404a"), 12))
    wav = os.path.join(folder, "beep.wav")
    rate = 8000
    pcm = b"".join(struct.pack("<h", int(9000 * math.sin(i * 440 * 2 * math.pi / rate))) for i in range(rate))
    audio.write_wav(wav, pcm, rate, 1)
    d, pk = audio.analyze_wav(wav)
    p.add_audio_clip("Бип", "m1", wav, 6, d, pk)  # с 0.5 с, длится 1 с
    p.set_frame(0)
    return p


@unittest.skipIf(FFMPEG is None, "нет FFmpeg")
class ExportTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.p = make_project(self.dir.name)

    def tearDown(self):
        self.dir.cleanup()

    def settings(self, fmt, **kw):
        f = export.FORMATS_BY_KEY[fmt]
        transparent = kw.get("transparent", False)
        w, h = export.output_size(self.p, 1.0, export.needs_even(fmt, transparent))
        name = "out" + (f.ext or "_frames")
        base = dict(fmt=fmt, path=os.path.join(self.dir.name, name), first=0, last=23, width=w, height=h, fps=12)
        base.update(kw)
        return ExportSettings(**base)

    def test_video_formats(self):
        for fmt, vcodec, acodec in (("mp4", "h264", "aac"), ("mov", "h264", "aac"), ("avi", "mpeg4", "mp3")):
            with self.subTest(fmt=fmt):
                s = self.settings(fmt)
                calls = []
                export.export(self.p, s, lambda d, t: calls.append(d) or True)
                dur, info = probe(s.path)
                self.assertEqual(video_frames(s.path), 24)
                if fmt != "avi":  # AVI указывает длительность неточно (MP3-кадры)
                    self.assertAlmostEqual(dur, 2.0, delta=0.1)
                self.assertIn(f"Video: {vcodec}", info)
                self.assertIn("320x180", info)  # подогнано до чётного размера
                self.assertIn(f"Audio: {acodec}", info)
                self.assertEqual(calls[-1], 24)

    def test_mov_transparent_prores(self):
        s = self.settings("mov", transparent=True, with_audio=False)
        export.export(self.p, s)
        _dur, info = probe(s.path)
        self.assertIn("prores", info)
        self.assertIn("yuva444p", info)
        self.assertIn("321x181", info)
        self.assertNotIn("Audio:", info)

    def test_gif(self):
        s = self.settings("gif", transparent=True)
        export.export(self.p, s)
        _dur, info = probe(s.path)
        self.assertIn("Video: gif", info)
        self.assertNotIn("Audio:", info)

    def test_png_sequence_range_and_scale(self):
        s = self.settings("png", first=10, last=13, width=160, height=90, transparent=True)
        export.export(self.p, s)
        files = sorted(os.listdir(s.path))
        self.assertEqual(files, [f"out_frames_{i:04d}.png" for i in (11, 12, 13, 14)])
        img = QImage(os.path.join(s.path, files[0]))
        self.assertEqual((img.width(), img.height()), (160, 90))
        self.assertEqual(img.pixelColor(0, 0).alpha(), 0)  # прозрачный фон

    def test_mp3(self):
        s = self.settings("mp3")
        export.export(self.p, s)
        dur, info = probe(s.path)
        self.assertIn("Audio: mp3", info)
        self.assertAlmostEqual(dur, 1.5, delta=0.15)  # звук кончается на 1.5 с

    def test_mp3_without_audio_fails_clearly(self):
        self.p.tracks[1].enabled = False
        with self.assertRaises(export.ExportError):
            export.export(self.p, self.settings("mp3"))

    def test_range_trims_audio_start(self):
        # диапазон с 9-го кадра: клип начался раньше — его начало обрезается, а не сдвигается
        s = self.settings("mp4", first=9, last=23)
        (part,) = export.audio_inputs(self.p, s)
        self.assertEqual(part.delay, 0)
        self.assertAlmostEqual(part.src_start, 0.25)

    def test_cancel_removes_file(self):
        s = self.settings("mp4")
        with self.assertRaises(export.ExportCancelled):
            export.export(self.p, s, lambda d, t: d < 5)
        self.assertFalse(os.path.exists(s.path))


if __name__ == "__main__":
    unittest.main()
