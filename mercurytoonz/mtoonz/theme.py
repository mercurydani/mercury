"""Цветовая тема и стили интерфейса — фирменный стиль Mercury Studio (mercurystudio.pro).

Как на сайте студии: чёрный космос со звёздами, серебристая планета Меркурий с синим свечением,
насыщенный синий для главных кнопок, белый жирный шрифт, тёмные «таблетки».
"""

# --- фирменные цвета ---
MERCURY_BLUE = "#2f62f0"      # главный цвет (кнопки, выделение)
MERCURY_BLUE_LIGHT = "#6f8fff"
MERCURY_GLOW = "#4a6cff"      # свечение по краю планеты
PLANET_LIGHT = "#e6e8ee"      # освещённая сторона планеты
PLANET_MID = "#9a9ca6"
PLANET_DARK = "#34363f"
SPACE_NIGHT = "#050609"       # фон заставки — как на сайте

# --- интерфейс ---
BG_DEEP = "#0a0b10"      # фон вокруг холста
BG_PANEL = "#121319"     # панели
BG_RAISED = "#1b1d24"    # кнопки, поля, «таблетки»
BG_HOVER = "#252832"
BORDER = "#2a2d37"
TEXT = "#eceef3"
TEXT_MUTED = "#8e919c"
ACCENT = MERCURY_BLUE
ACCENT_DIM = "#1f3477"
ON_ACCENT = "#ffffff"    # текст и значки на синем
PLAYHEAD = "#ff4f5e"

STYLESHEET = f"""
* {{
    color: {TEXT};
    font-size: 13px;
}}
QMainWindow, QDialog {{
    background: {BG_DEEP};
}}
QMainWindow::separator {{
    background: {BG_DEEP};
    width: 4px;
    height: 4px;
}}
QMainWindow::separator:hover {{
    background: {ACCENT_DIM};
}}
QWidget#panel, QDockWidget > QWidget {{
    background: {BG_PANEL};
}}
QDockWidget {{
    titlebar-close-icon: none;
    font-weight: 600;
}}
QDockWidget::title {{
    background: {BG_PANEL};
    padding: 6px 10px;
    border-bottom: 1px solid {BORDER};
    color: {TEXT_MUTED};
    text-transform: uppercase;
}}
QMenuBar {{
    background: {BG_PANEL};
    border-bottom: 1px solid {BORDER};
    padding: 2px 4px;
}}
QMenuBar::item {{
    padding: 5px 10px;
    border-radius: 4px;
    background: transparent;
}}
QMenuBar::item:selected {{
    background: {BG_HOVER};
}}
QMenu {{
    background: {BG_RAISED};
    border: 1px solid {BORDER};
    padding: 4px;
}}
QMenu::item {{
    padding: 6px 28px 6px 24px;
    border-radius: 4px;
}}
QMenu::item:selected {{
    background: {ACCENT};
    color: {ON_ACCENT};
}}
QMenu::item:disabled {{
    color: {TEXT_MUTED};
}}
QMenu::separator {{
    height: 1px;
    background: {BORDER};
    margin: 4px 8px;
}}
QToolBar {{
    background: {BG_PANEL};
    border: none;
    spacing: 2px;
    padding: 4px;
}}
QToolBar#toolbox {{
    border-right: 1px solid {BORDER};
    padding: 6px 5px;
    spacing: 4px;
}}
QToolBar#topbar {{
    border-bottom: 1px solid {BORDER};
}}
QToolBar::separator {{
    background: {BORDER};
    width: 1px;
    height: 1px;
    margin: 4px 6px;
}}
QToolButton {{
    background: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    padding: 4px;
}}
QToolButton:hover {{
    background: {BG_HOVER};
}}
QToolButton:pressed {{
    background: {BORDER};
}}
QToolButton:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}
QToolBar#toolbox QToolButton {{
    padding: 6px;
}}
QPushButton {{
    background: {BG_RAISED};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 5px 12px;
}}
QPushButton:hover {{
    background: {BG_HOVER};
}}
QPushButton:default {{
    background: {ACCENT};
    color: {ON_ACCENT};
    border-color: {ACCENT};
}}
QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {{
    background: {BG_DEEP};
    border: 1px solid {BORDER};
    border-radius: 5px;
    padding: 3px 6px;
    selection-background-color: {ACCENT};
    selection-color: {ON_ACCENT};
}}
QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {{
    border-color: {ACCENT};
}}
QSpinBox::up-button, QSpinBox::down-button,
QDoubleSpinBox::up-button, QDoubleSpinBox::down-button {{
    width: 0px;
    border: none;
}}
QComboBox::drop-down {{
    border: none;
    width: 18px;
}}
QComboBox QAbstractItemView {{
    background: {BG_RAISED};
    border: 1px solid {BORDER};
    selection-background-color: {ACCENT};
    selection-color: {ON_ACCENT};
}}
QSlider::groove:horizontal {{
    height: 4px;
    background: {BG_DEEP};
    border-radius: 2px;
}}
QSlider::sub-page:horizontal {{
    background: {ACCENT};
    border-radius: 2px;
}}
QSlider::handle:horizontal {{
    background: {TEXT};
    width: 12px;
    height: 12px;
    margin: -4px 0;
    border-radius: 6px;
}}
QSlider::handle:horizontal:hover {{
    background: #ffffff;
}}
QCheckBox::indicator {{
    width: 14px;
    height: 14px;
    border: 1px solid {BORDER};
    border-radius: 3px;
    background: {BG_DEEP};
}}
QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}
QScrollBar:horizontal {{
    height: 10px;
    background: {BG_PANEL};
    margin: 0;
}}
QScrollBar:vertical {{
    width: 10px;
    background: {BG_PANEL};
    margin: 0;
}}
QScrollBar::handle {{
    background: {BORDER};
    border-radius: 4px;
    min-width: 24px;
    min-height: 24px;
    margin: 2px;
}}
QScrollBar::handle:hover {{
    background: {TEXT_MUTED};
}}
QScrollBar::add-line, QScrollBar::sub-line {{
    width: 0;
    height: 0;
}}
QScrollBar::add-page, QScrollBar::sub-page {{
    background: none;
}}
QStatusBar {{
    background: {BG_PANEL};
    border-top: 1px solid {BORDER};
    color: {TEXT_MUTED};
}}
QStatusBar QLabel {{
    color: {TEXT_MUTED};
    padding: 0 8px;
}}
QTabWidget::pane {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: 8px;
    top: -1px;
    padding: 10px;
}}
QTabBar::tab {{
    background: transparent;
    color: {TEXT_MUTED};
    padding: 7px 16px;
    margin-right: 4px;
    border-radius: 6px;
}}
QTabBar::tab:selected {{
    background: {BG_RAISED};
    color: {TEXT};
}}
QTabBar::tab:hover {{
    color: {TEXT};
}}
QToolTip {{
    background: {BG_RAISED};
    color: {TEXT};
    border: 1px solid {BORDER};
    padding: 4px 6px;
}}
QLabel#sectionTitle {{
    color: {TEXT_MUTED};
    font-size: 11px;
    font-weight: 600;
}}
QLabel#frameCounter {{
    font-family: monospace;
    font-size: 13px;
    padding: 0 8px;
}}
"""


def palette():
    """Тёмная палитра для всех виджетов (в том числе тех, что не описаны в STYLESHEET)."""
    from PySide6.QtGui import QColor, QPalette
    pal = QPalette()
    roles = {
        QPalette.Window: BG_PANEL, QPalette.WindowText: TEXT, QPalette.Base: BG_DEEP,
        QPalette.AlternateBase: BG_RAISED, QPalette.ToolTipBase: BG_RAISED, QPalette.ToolTipText: TEXT,
        QPalette.Text: TEXT, QPalette.Button: BG_RAISED, QPalette.ButtonText: TEXT, QPalette.BrightText: "#ffffff",
        QPalette.Highlight: ACCENT, QPalette.HighlightedText: ON_ACCENT, QPalette.Link: MERCURY_BLUE_LIGHT,
        QPalette.PlaceholderText: TEXT_MUTED, QPalette.Mid: BORDER, QPalette.Dark: BG_DEEP, QPalette.Light: BG_HOVER,
    }
    for role, color in roles.items():
        pal.setColor(role, QColor(color))
    for role in (QPalette.WindowText, QPalette.Text, QPalette.ButtonText):
        pal.setColor(QPalette.Disabled, role, QColor(TEXT_MUTED))
    return pal
