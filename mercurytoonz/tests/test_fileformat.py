"""Тесты формата .mtoonz: python -m unittest discover -s tests"""

import json
import os
import sys
import tempfile
import unittest
import zipfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtGui import QColor, QGuiApplication  # noqa: E402

from mtoonz import fileformat  # noqa: E402
from mtoonz.model import Project, Stroke  # noqa: E402
from mtoonz.render import render_frame  # noqa: E402

app = QGuiApplication.instance() or QGuiApplication(sys.argv)


def sample_project() -> Project:
    p = Project()
    p.reset(name="Тест", width=1280, height=720, fps=12, frame_count=30)
    p.add_stroke(Stroke(((10, 10, 1), (100, 50.1234, 0.5)), QColor("#ff0000"), 5, 0.5, use_pressure=True))
    p.add_layer()
    p.set_frame(5)
    p.insert_keyframe(blank=True)
    p.add_stroke(Stroke(((1, 2, 1), (3, 4, 1)), QColor(0, 0, 255, 128), 20, erase=True))
    p.layers[1].visible = False
    return p


class FileFormatTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.folder = self.dir.name

    def tearDown(self):
        self.dir.cleanup()

    def test_roundtrip(self):
        p = sample_project()
        path = os.path.join(self.folder, "a.mtoonz")
        fileformat.save_project(p, path, render_frame(p, 0, 200))
        self.assertFalse([f for f in os.listdir(self.folder) if f.endswith(".tmp")])

        q = Project()
        fileformat.load_project(path, q)
        self.assertEqual((q.name, q.width, q.height, q.fps, q.frame_count), ("Тест", 1280, 720, 12, 30))
        self.assertEqual(len(q.layers), 2)
        self.assertEqual([l.id for l in q.layers], [l.id for l in p.layers])
        self.assertEqual(q.layers[0].sorted_keys(), [0, 5])
        s = q.layers[0].keys[5].strokes[0]
        self.assertTrue(s.erase)
        self.assertEqual(s.color.alpha(), 128)
        s = q.layers[1].keys[0].strokes[0]
        self.assertEqual(s.points[1][1], 50.12)
        self.assertEqual(s.points[1][2], 0.5)
        self.assertTrue(s.use_pressure)
        self.assertEqual(s.opacity, 0.5)
        self.assertFalse(q.layers[1].visible)
        self.assertFalse(q.is_dirty())
        self.assertEqual(q.undo_stack.count(), 0)

        info = fileformat.read_meta(path, with_thumbnail=True)
        self.assertEqual((info.name, info.frames, info.layers), ("Тест", 30, 2))
        self.assertFalse(info.thumbnail.isNull())

    def test_created_preserved_on_resave(self):
        p = sample_project()
        path = os.path.join(self.folder, "a.mtoonz")
        fileformat.save_project(p, path)
        created = fileformat.read_meta(path).created
        fileformat.save_project(p, path)
        self.assertEqual(fileformat.read_meta(path).created, created)

    def test_unknown_layer_type_preserved(self):
        p = sample_project()
        path = os.path.join(self.folder, "a.mtoonz")
        fileformat.save_project(p, path)
        with zipfile.ZipFile(path) as z:
            meta, data = z.read("meta.json"), json.loads(z.read("project.json"))
        future = {"id": "vid1", "type": "video", "name": "Клип", "source": "media/clip.mp4"}
        data["layers"].append(future)
        with zipfile.ZipFile(path, "w") as z:
            z.writestr("meta.json", meta)
            z.writestr("project.json", json.dumps(data))
        q = Project()
        fileformat.load_project(path, q)
        self.assertEqual(len(q.layers), 3)
        fileformat.save_project(q, path)
        with zipfile.ZipFile(path) as z:
            self.assertIn(future, json.loads(z.read("project.json"))["layers"])

    def test_rejects_garbage_and_newer_version(self):
        bad = os.path.join(self.folder, "bad.mtoonz")
        with open(bad, "wb") as f:
            f.write(b"not a zip")
        with self.assertRaises(fileformat.ProjectFileError):
            fileformat.load_project(bad, Project())
        newer = os.path.join(self.folder, "new.mtoonz")
        with zipfile.ZipFile(newer, "w") as z:
            z.writestr("project.json", json.dumps({"format": "mercurytoonz", "version": 999}))
        with self.assertRaises(fileformat.ProjectFileError):
            fileformat.load_project(newer, Project())

    def test_library_operations(self):
        p = sample_project()
        path = fileformat.unique_path(self.folder, p.name)
        fileformat.save_project(p, path)
        self.assertEqual(fileformat.unique_name(self.folder, "Тест"), "Тест 2")
        self.assertTrue(fileformat.unique_path(self.folder, "Тест").endswith("Тест (2).mtoonz"))

        dup = fileformat.duplicate_project(path)
        self.assertEqual(fileformat.read_meta(dup).name, "Тест копия")

        renamed = fileformat.rename_project(path, "Новое: имя?")
        self.assertFalse(os.path.exists(path))
        self.assertTrue(renamed.endswith("Новое_ имя_.mtoonz"))
        q = Project()
        fileformat.load_project(renamed, q)
        self.assertEqual(q.name, "Новое: имя?")

        names = sorted(i.name for i in fileformat.list_projects(self.folder))
        self.assertEqual(names, ["Новое: имя?", "Тест копия"])

        fileformat.delete_project(dup)
        self.assertFalse(os.path.exists(dup))
        self.assertEqual(len(fileformat.list_projects(self.folder)), 1)


if __name__ == "__main__":
    unittest.main()
