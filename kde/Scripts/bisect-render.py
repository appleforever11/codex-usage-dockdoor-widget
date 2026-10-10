#!/usr/bin/env python3
"""Render one card (or component) standalone to find which QML hangs/blank.

Usage: bisect-render.py <ComponentPath> <out.png> [w] [h] [bare]
  <ComponentPath>  e.g. "Cards.QuotaCard", "Components.ThemeBackground",
                   "Rectangle"
  bare=1           skip dataSource/clock wiring (for plain QtQuick tests)
"""
import faulthandler
import os
import shutil
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

target = sys.argv[1]
out_png = sys.argv[2]
width = int(sys.argv[3]) if len(sys.argv) > 3 else 330
height = int(sys.argv[4]) if len(sys.argv) > 4 else 200
bare = len(sys.argv) > 5 and sys.argv[5] == "bare"

faulthandler.dump_traceback_later(8, exit=True)

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

REPO = Path(__file__).resolve().parent.parent
STAGE = Path("/tmp/codex-bisect-pkg")
if STAGE.exists():
    shutil.rmtree(STAGE)
shutil.copytree(REPO / "plasmoid", STAGE)

wiring = "" if bare else """
        dataSource: codexData
        clock: animClock
"""

wrapper = Path("/tmp/codex-bisect-wrapper.qml")
wrapper.write_text(f"""
import QtQuick
import "file://{STAGE}/contents/ui" as UI
import "file://{STAGE}/contents/ui/cards" as Cards
import "file://{STAGE}/contents/ui/components" as Components

Rectangle {{
    width: {width}
    height: {height}
    color: "#141420"

{"" if bare else "Components.AnimationClock { id: animClock; animationsEnabled: false; visibleToUser: true }"}
{"" if bare else "UI.CodexData { id: codexData; helperPort: 47631; pollIntervalMs: 1500 }"}

    {target} {{
        id: probe
        anchors.fill: parent{wiring}
    }}
}}
""")

app = QGuiApplication([])
view = QQuickView()
view.setSource(QUrl.fromLocalFile(str(wrapper)))
if view.status() != QQuickView.Status.Ready:
    print("VIEW ERRORS:", flush=True)
    for e in view.errors():
        print("   ", e.toString(), flush=True)
    os._exit(2)
view.show()

def grab():
    root_item = view.rootObject()
    if root_item is None:
        print("no root object", flush=True)
        os._exit(2)

    # Synchronous window grab — grabToImage(callback) rejects Python callables
    # on current PySide6 and a callback-based grab never completes offscreen.
    image = view.grabWindow()
    image.save(out_png)
    colors = set()
    for y in range(0, image.height(), 4):
        for x in range(0, image.width(), 4):
            colors.add(image.pixel(x, y))
    print(f"saved {out_png} distinct={len(colors)}", flush=True)
    os._exit(0 if len(colors) > 4 else 3)

QTimer.singleShot(2000, grab)
QTimer.singleShot(12000, lambda: os._exit(4))
sys.exit(app.exec())
