#!/usr/bin/env python3
"""Headless render of a QML probe using QQuickRenderControl — no windowing
platform involvement, so it works where QQuickView+offscreen deadlocks.

Usage: render-control.py <out.png> [width] [height] [probeTarget]
Renders a Dashboard probe wired to the live helper daemon by default.
"""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QEventLoop, QTimer, QUrl
from PySide6.QtGui import QGuiApplication, QImage
from PySide6.QtQuick import QQuickItem, QQuickRenderControl, QQuickWindow
from PySide6.QtQml import QQmlComponent, QQmlEngine

REPO = Path(__file__).resolve().parent.parent
STAGE = Path("/tmp/codex-rc-pkg")

out_png = sys.argv[1] if len(sys.argv) > 1 else "/tmp/codex-dashboard.png"
width = int(sys.argv[2]) if len(sys.argv) > 2 else 366
height = int(sys.argv[3]) if len(sys.argv) > 3 else 660
target = sys.argv[4] if len(sys.argv) > 4 else "UI.Dashboard"

app = QGuiApplication([])

import shutil
if STAGE.exists():
    shutil.rmtree(STAGE)
shutil.copytree(REPO / "plasmoid", STAGE)

wiring = "        dataSource: codexData\n        clock: animClock" if target != "Rectangle" else ""
wrapper = Path("/tmp/codex-rc-wrapper.qml")
wrapper.write_text(f"""
import QtQuick
import "file://{STAGE}/contents/ui" as UI
import "file://{STAGE}/contents/ui/cards" as Cards
import "file://{STAGE}/contents/ui/components" as Components

Rectangle {{
    width: {width}
    height: {height}
    color: "#141420"

    Components.AnimationClock {{ id: animClock; animationsEnabled: false; visibleToUser: true }}
    UI.CodexData {{ id: codexData; helperPort: 47631; pollIntervalMs: 1500 }}

    {target} {{
        id: probe
        anchors.fill: parent
{wiring}
    }}
}}
""")

control = QQuickRenderControl()
try:
    window = QQuickWindow(control)
except TypeError:
    window = QQuickWindow()
    window.setRenderControl(control)
window.setWidth(width)
window.setHeight(height)

engine = QQmlEngine()
engine.addImportPath(str(STAGE / "contents/ui"))
engine.addImportPath(str(STAGE / "contents/ui/components"))
engine.addImportPath(str(STAGE / "contents/ui/cards"))

component = QQmlComponent(engine, QUrl.fromLocalFile(str(wrapper)))
if component.status() != QQmlComponent.Status.Ready:
    print("COMPONENT ERRORS:", flush=True)
    for e in component.errors():
        print("   ", e.toString(), flush=True)
    os._exit(2)
item = component.create()
if item is None:
    print("creation failed", flush=True)
    os._exit(2)
item.setParentItem(window.contentItem())
item.setParent(window.contentItem())
window.contentItem().setWidth(width)
window.contentItem().setHeight(height)
control.initialize()

# Give async XHR + layout passes a chance to finish.
loop = QEventLoop()
QTimer.singleShot(2500, loop.quit)
loop.exec()

try:
    control.beginFrame()
except Exception:
    pass
control.polishItems()
control.sync()
control.render()
try:
    control.endFrame()
except Exception:
    pass

print(f"window {window.width()}x{window.height()} item {item.width()}x{item.height()} contentItem {window.contentItem().width()}x{window.contentItem().height()}", flush=True)
image = window.grabWindow()
if image.width() == 0:
    # Fall back: render to an explicit image target.
    target_image = QImage(width, height, QImage.Format_ARGB32_Premultiplied)
    from PySide6.QtGui import QPainter
    control.renderTarget = None  # placeholder to keep API discovery honest
image.save(out_png)

colors = set()
samples = 0
for y in range(0, image.height(), 4):
    for x in range(0, image.width(), 4):
        colors.add(image.pixel(x, y))
        samples += 1
print(f"saved {out_png} {image.width()}x{image.height()} distinct={len(colors)} / {samples}", flush=True)
os._exit(0 if len(colors) > 8 else 3)
