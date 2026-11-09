"""Векторные иконки интерфейса (встроенные SVG, без внешних файлов)."""

from functools import lru_cache

from PySide6.QtCore import QByteArray, QRectF, Qt
from PySide6.QtGui import QIcon, QPainter, QPixmap
from PySide6.QtSvg import QSvgRenderer

from . import theme

# Содержимое <svg viewBox="0 0 24 24"> для каждой иконки.
# Обводка берётся из атрибутов корневого элемента; fill="currentColor" — сплошная заливка.
_ICONS = {
    "brush": '<path d="M18.5 2.5l3 3L12 15l-3-3z"/>'
             '<path d="M8.5 12.5c-2.2 0-4 1.6-4 4 0 1.6-1 2.6-2.2 3.2 3.4 1 7.4 0 8.6-2.6.6-1.4.2-2.8-2.4-4.6z"/>',
    "pencil": '<path d="M16.5 3.5l4 4L8 20H4v-4z"/><path d="M14 6l4 4"/>',
    "eraser": '<path d="M8 19l-4.3-4.3a1.5 1.5 0 0 1 0-2.1l9-9a1.5 1.5 0 0 1 2.1 0l4.3 4.3a1.5 1.5 0 0 1 0 2.1L12 19z"/>'
              '<path d="M9 8.5l6.5 6.5"/><path d="M12 19h8"/>',
    "fill": '<path d="M4 12l7-7 8 8-6.5 6.5a1.5 1.5 0 0 1-2 0L4 13.9a1.4 1.4 0 0 1 0-1.9z"/>'
            '<path d="M4.5 12.5h14"/><path d="M20.5 15.5s2 2.6 2 3.8a2 2 0 0 1-4 0c0-1.2 2-3.8 2-3.8z"/>',
    "select": '<path d="M5 3l13 7.5-5.6 1.6L9.8 18z"/><path d="M12.6 12.2l4.4 6"/>',
    "lasso": '<path d="M7 17c-3-1.2-4.5-3.3-4.5-5.5C2.5 7.4 6.8 4 12 4s9.5 3.4 9.5 7.5S17.2 19 12 19c-1 0-2-.1-2.8-.3"/>'
             '<circle cx="7" cy="18" r="2"/><path d="M7 20c0 1.5-1 2-2 2"/>',
    "transform": '<rect x="6" y="6" width="12" height="12" stroke-dasharray="2 2"/>'
                 '<rect x="3.5" y="3.5" width="4" height="4" fill="currentColor"/>'
                 '<rect x="16.5" y="3.5" width="4" height="4" fill="currentColor"/>'
                 '<rect x="3.5" y="16.5" width="4" height="4" fill="currentColor"/>'
                 '<rect x="16.5" y="16.5" width="4" height="4" fill="currentColor"/>',
    "eyedropper": '<path d="M19.6 4.4a2.1 2.1 0 0 0-3 0l-2.1 2.1-1-1-1.5 1.5 5 5 1.5-1.5-1-1 2.1-2.1a2.1 2.1 0 0 0 0-3z"/>'
                  '<path d="M13 9l-8 8v2h2l8-8"/>',
    "hand": '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V11"/><path d="M11 10.5V4a1.5 1.5 0 0 1 3 0v6.5"/>'
            '<path d="M14 10.5V5.5a1.5 1.5 0 0 1 3 0V12"/>'
            '<path d="M17 9.5a1.5 1.5 0 0 1 3 0V15a6 6 0 0 1-6 6h-1.5a6 6 0 0 1-4.6-2.2L4.5 15a1.6 1.6 0 0 1 2.4-2.1L8 14"/>',
    "zoom": '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/><path d="M7.5 10.5h6M10.5 7.5v6"/>',
    "shapes": '<rect x="3" y="3" width="10" height="10" rx="1"/><circle cx="15.5" cy="15.5" r="5.5"/>',
    "text": '<path d="M5 6V4h14v2"/><path d="M12 4v16"/><path d="M9 20h6"/>',
    "play": '<path d="M7 4.5v15l12-7.5z" fill="currentColor"/>',
    "pause": '<rect x="6" y="4.5" width="4" height="15" rx="1" fill="currentColor"/>'
             '<rect x="14" y="4.5" width="4" height="15" rx="1" fill="currentColor"/>',
    "prev": '<path d="M15 6l-6 6 6 6"/>',
    "next": '<path d="M9 6l6 6-6 6"/>',
    "first": '<path d="M6 5v14"/><path d="M18 6l-7 6 7 6"/>',
    "last": '<path d="M18 5v14"/><path d="M6 6l7 6-7 6"/>',
    "loop": '<path d="M17 2l3 3-3 3"/><path d="M4 11V9a4 4 0 0 1 4-4h12"/>'
            '<path d="M7 22l-3-3 3-3"/><path d="M20 13v2a4 4 0 0 1-4 4H4"/>',
    "onion": '<circle cx="8.5" cy="12" r="5.5" stroke-opacity=".45"/><circle cx="15.5" cy="12" r="5.5"/>',
    "eye": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    "eye-off": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" stroke-opacity=".4"/>'
               '<path d="M3 3l18 18"/>',
    "lock": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    "unlock": '<rect x="5" y="11" width="14" height="10" rx="2" stroke-opacity=".4"/>'
              '<path d="M8 11V7a4 4 0 0 1 7.8-1.2" stroke-opacity=".4"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "minus": '<path d="M5 12h14"/>',
    "trash": '<path d="M4 7h16"/><path d="M10 11v6M14 11v6"/>'
             '<path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12"/><path d="M9 7V4h6v3"/>',
    "layers": '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
    "layer-add": '<path d="M11 3l8 4.5-8 4.5-8-4.5z"/><path d="M3 12l8 4.5 3-1.7"/><path d="M19 14v6M16 17h6"/>',
    "duplicate": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
    "new": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M12 11v6M9 14h6"/>',
    "open": '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    "save": '<path d="M5 3h11l5 5v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/>'
            '<path d="M7 3v5h8V3"/><rect x="7" y="13" width="10" height="8"/>',
    "export": '<path d="M12 3v12"/><path d="M7 8l5-5 5 5"/><path d="M5 15v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4"/>',
    "undo": '<path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
    "redo": '<path d="M15 14l5-5-5-5"/><path d="M20 9H9a5 5 0 0 0 0 10h3"/>',
    "keyframe": '<circle cx="12" cy="12" r="6" fill="currentColor"/>',
    "keyframe-empty": '<circle cx="12" cy="12" r="6"/>',
    "frame-add": '<rect x="3" y="5" width="12" height="14" rx="1.5"/><path d="M19 9v6M16 12h6"/>',
    "frame-remove": '<rect x="3" y="5" width="12" height="14" rx="1.5"/><path d="M16 12h6"/>',
    "tween": '<circle cx="5" cy="12" r="2.5" fill="currentColor"/><circle cx="19" cy="12" r="2.5" fill="currentColor"/>'
             '<path d="M8.5 12h7"/><path d="M13 9l3 3-3 3"/>',
    "swap": '<path d="M7 4L4 7l3 3"/><path d="M4 7h11a3 3 0 0 1 3 3v10"/>',
    "fit": '<path d="M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5"/>',
    "settings": '<circle cx="12" cy="12" r="3"/>'
                '<path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
    "record": '<circle cx="12" cy="12" r="6" fill="currentColor"/>',
    "stop": '<rect x="6.5" y="6.5" width="11" height="11" rx="1.5" fill="currentColor"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0"/><path d="M12 17.5V21"/>',
    "speaker": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6"/><path d="M18 6.5a7.5 7.5 0 0 1 0 11"/>',
    "speaker-off": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" stroke-opacity=".4"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
    "music": '<path d="M9 18V6l11-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
    "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6"/><path d="M12 7.5v.5"/>',
    "shield": '<path d="M12 3l7.5 3v5.5c0 4.5-3.2 8.2-7.5 9.5-4.3-1.3-7.5-5-7.5-9.5V6z"/><path d="M9 12l2 2 4-4"/>',
    "mail": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 6.5l8.5 6.5 8.5-6.5"/>',
    "history": '<path d="M3.5 12a8.5 8.5 0 1 0 2.5-6"/><path d="M3 4v4h4"/><path d="M12 8v4.5l3 2"/>',
    "keyboard": '<rect x="2.5" y="6" width="19" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10"/>',
    "film": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4"/>',
    "audio-track": '<path d="M3 12h2M7 8v8M11 5v14M15 9v6M19 7v10M21 12h0"/>',
    "up": '<path d="M12 19V5"/><path d="M6 11l6-6 6 6"/>',
    "down": '<path d="M12 5v14"/><path d="M6 13l6 6 6-6"/>',
    "logo": '<circle cx="12" cy="12" r="8" fill="currentColor" stroke="none"/>'
            '<path d="M7 12.5c1.5-3 3-3 5 0s3.5 3 5 0" stroke="#1a1208" stroke-width="2"/>',
}


def _svg(name: str, color: str) -> bytes:
    body = _ICONS[name].replace("currentColor", color)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        f'stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
        f"{body}</svg>"
    ).encode()


def pixmap(name: str, color: str = theme.TEXT, size: int = 20, dpr: float = 2.0) -> QPixmap:
    renderer = QSvgRenderer(QByteArray(_svg(name, color)))
    pm = QPixmap(int(size * dpr), int(size * dpr))
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    renderer.render(p, QRectF(0, 0, pm.width(), pm.height()))
    p.end()
    pm.setDevicePixelRatio(dpr)
    return pm


@lru_cache(maxsize=None)
def icon(name: str, color: str = theme.TEXT, checked_color: str = "#1a1208") -> QIcon:
    ic = QIcon()
    for size in (16, 20, 24, 32):
        ic.addPixmap(pixmap(name, color, size), QIcon.Normal, QIcon.Off)
        ic.addPixmap(pixmap(name, checked_color, size), QIcon.Normal, QIcon.On)
        ic.addPixmap(pixmap(name, theme.TEXT_MUTED, size), QIcon.Disabled, QIcon.Off)
    return ic
