"""Планшет, заставка, логотип и звук запуска: python -m unittest discover -s tests"""

import math
import os
import sys
import tempfile
import unittest
import wave

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtCore import QEvent, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QInputDevice, QPointingDevice, QTabletEvent  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from mtoonz import brand  # noqa: E402
from mtoonz.prefs import apply_curve, prefs  # noqa: E402

app = QApplication.instance() or QApplication(sys.argv)


def pen_device(eraser=False):
    kind = QPointingDevice.PointerType.Eraser if eraser else QPointingDevice.PointerType.Pen
    caps = QInputDevice.Capability.Position | QInputDevice.Capability.Pressure
    return QPointingDevice("Тестовое перо", 1, QInputDevice.DeviceType.Stylus, kind, caps, 1, 2)


def tablet(widget, kind, pos, pressure, device, button=Qt.LeftButton):
    buttons = Qt.NoButton if kind == QEvent.TabletRelease else Qt.LeftButton
    ev = QTabletEvent(kind, device, QPointF(pos), widget.mapToGlobal(QPointF(pos)), pressure, 10, -5,
                      0, 0, 0, Qt.NoModifier, button, buttons)
    QApplication.sendEvent(widget, ev)
    return ev


class TabletTest(unittest.TestCase):
    def setUp(self):
        prefs().reset()
        from mtoonz.app import MainWindow
        self.w = MainWindow()
        self.w.resize(1200, 800)
        self.w.show()
        self.c, self.p = self.w.canvas, self.w.project

    def tearDown(self):
        self.p.undo_stack.setClean()
        self.w.close()

    def draw(self, device, pressures):
        x0 = 400
        tablet(self.c, QEvent.TabletPress, QPointF(x0, 300), pressures[0], device)
        for i, pr in enumerate(pressures[1:], 1):
            tablet(self.c, QEvent.TabletMove, QPointF(x0 + i * 12, 300), pr, device)
        tablet(self.c, QEvent.TabletRelease, QPointF(x0 + len(pressures) * 12, 300), 0, device)
        return self.p.layers[0].keys[0].strokes[-1]

    def test_pen_pressure_reaches_stroke(self):
        s = self.draw(pen_device(), [0.2, 0.4, 0.6, 0.8, 1.0, 1.0, 0.5])
        self.assertFalse(s.erase)
        prs = [pt[2] for pt in s.points]
        self.assertLess(min(prs), 0.5)
        self.assertGreater(max(prs), 0.9)
        self.assertIsNone(self.c._stroke_tool)
        self.assertEqual(self.c.pen_info[3], "перо")

    def test_pressure_curve(self):
        self.assertAlmostEqual(apply_curve(0.5, 1.0, 0.0), 0.5)
        self.assertGreater(apply_curve(0.5, 0.5, 0.0), 0.7)   # мягкая — толще при лёгком нажиме
        self.assertLess(apply_curve(0.5, 2.0, 0.0), 0.3)      # жёсткая — тоньше
        self.assertEqual(apply_curve(0.05, 1.0, 0.1), 0.05)   # ниже порога

    def test_eraser_end_of_pen(self):
        self.draw(pen_device(), [1, 1, 1])
        s = self.draw(pen_device(eraser=True), [1, 1, 1])
        self.assertTrue(s.erase)
        self.assertEqual(self.w.state.tool, "brush")  # инструмент не переключился насовсем
        prefs().set("tablet/pen_eraser", False)
        s = self.draw(pen_device(eraser=True), [1, 1, 1])
        self.assertFalse(s.erase)

    def test_pen_ignored_for_navigation_tools(self):
        self.w.state.set_tool("hand")
        ev = tablet(self.c, QEvent.TabletPress, QPointF(300, 300), 1, pen_device())
        self.assertFalse(ev.isAccepted())  # пусть обработает как мышь (панорама)


class BrandTest(unittest.TestCase):
    def test_startup_sound_matches_bounces(self):
        samples = brand.synth_startup_sound()
        hits = brand.bounce_schedule()
        self.assertGreater(len(samples) / brand.RATE, hits[-1][0] + 1)
        self.assertLessEqual(max(abs(x) for x in samples), 0.81)
        # перед первым ударом тишина, сразу после — звук
        t0 = int(hits[0][0] * brand.RATE)
        before = max(abs(x) for x in samples[t0 - 2000:t0 - 10])
        after = max(abs(x) for x in samples[t0 + 100:t0 + 2000])
        self.assertLess(before, 0.01)
        self.assertGreater(after, 0.2)
        path = brand.startup_sound_path()
        with wave.open(path) as w:
            self.assertEqual(w.getframerate(), brand.RATE)

    def test_bounce_physics(self):
        hits = brand.bounce_schedule()
        self.assertEqual(len(hits), 4)
        self.assertTrue(all(b[0] > a[0] and b[1] < a[1] for a, b in zip(hits, hits[1:])))
        h, _v = brand.planet_height(hits[0][0] + 0.01)
        self.assertLess(h, 5)
        self.assertEqual(brand.planet_height(10)[0], 0)

    def test_splash_runs_and_can_be_skipped(self):
        from mtoonz.widgets.splash import DURATION, SplashScreen
        sp = SplashScreen(play_sound=False)
        done = []
        sp.finished.connect(lambda: done.append(1))
        sp.start()
        for t in (0.2, 0.7, 1.5, DURATION - 0.1):
            sp.elapsed = lambda t=t: t
            self.assertFalse(sp.grab().isNull())
        sp.skip()
        self.assertEqual(done, [1])
        self.assertFalse(sp.isVisible())

    def test_brand_files(self):
        d = tempfile.mkdtemp()
        brand.save_brand_files(d)
        self.assertEqual(sorted(os.listdir(d)), ["logo-wide.png", "logo.png", "logo.svg"])
        with open(os.path.join(d, "logo.svg"), "rb") as f:
            self.assertIn(b"<svg", f.read(400))
        self.assertGreaterEqual(len(brand.app_icon().availableSizes()), 5)

    def test_preferences_dialog(self):
        from mtoonz.widgets.preferences import CURVES, PreferencesDialog
        prefs().reset()
        d = PreferencesDialog(tab="tablet")
        d.curve.setValue(0)
        self.assertEqual(prefs().get("tablet/curve"), CURVES[0][0])
        d.splash.setChecked(False)
        self.assertFalse(prefs().get("general/splash"))
        d._reset()
        self.assertTrue(prefs().get("general/splash"))
        self.assertTrue(math.isclose(prefs().get("tablet/curve"), 1.0))


class AllWindowsTest(unittest.TestCase):
    def test_every_window_opens(self):
        """Каждое окно программы создаётся и рисуется без ошибок."""
        from mtoonz.app import SHORTCUTS_HELP, MainWindow
        from mtoonz.audio import RecordDialog
        from mtoonz.widgets.export_dialog import ExportDialog
        from mtoonz.widgets.help_dialog import SECTIONS, HelpDialog
        from mtoonz.widgets.preferences import PreferencesDialog
        from mtoonz.widgets.project_browser import NewProjectDialog, ProjectBrowser
        w = MainWindow()
        windows = [w, ProjectBrowser(w, startup=True), NewProjectDialog("Тест", w), RecordDialog(w),
                   PreferencesDialog(w, "tablet")]
        windows += [ExportDialog(w.project, f.key, w) for f in __import__("mtoonz.export").export.FORMATS]
        windows += [HelpDialog(SHORTCUTS_HELP, key, w) for key, *_ in SECTIONS]
        for win in windows:
            win.show()
            self.assertFalse(win.grab().isNull(), type(win).__name__)
            win.close()


if __name__ == "__main__":
    unittest.main()
