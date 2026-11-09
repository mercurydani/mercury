"""Создаёт brand/icon.ico (значок программы для Windows) из логотипа.
Запуск: python tools/make_icon.py   (нужен Pillow: pip install pillow)"""

import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from PIL import Image  # noqa: E402
from PySide6.QtCore import QRectF, Qt  # noqa: E402
from PySide6.QtGui import QImage, QPainter  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from mtoonz import brand  # noqa: E402

app = QApplication([])
img = QImage(256, 256, QImage.Format_ARGB32)
img.fill(Qt.transparent)
p = QPainter(img)
brand.draw_logo_mark(p, QRectF(-12, -8, 280, 280), motion=False)
p.end()
png = os.path.join(ROOT, "brand", "icon-256.png")
img.save(png)
ico = os.path.join(ROOT, "brand", "icon.ico")
Image.open(png).save(ico, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("готово:", ico)
