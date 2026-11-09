"""Цветовая тема и стили интерфейса."""

BG_DEEP = "#14161a"      # фон вокруг холста
BG_PANEL = "#1d2026"     # панели
BG_RAISED = "#252930"    # кнопки, поля
BG_HOVER = "#2e333b"
BORDER = "#343943"
TEXT = "#d9dce2"
TEXT_MUTED = "#8a909b"
ACCENT = "#ff8a3d"       # «меркурианский» оранжевый
ACCENT_DIM = "#7a4524"
PLAYHEAD = "#ff5a4f"

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
    color: #1a1208;
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
    color: #1a1208;
    border-color: {ACCENT};
}}
QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {{
    background: {BG_DEEP};
    border: 1px solid {BORDER};
    border-radius: 5px;
    padding: 3px 6px;
    selection-background-color: {ACCENT};
    selection-color: #1a1208;
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
    selection-color: #1a1208;
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
