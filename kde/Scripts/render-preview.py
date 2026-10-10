#!/usr/bin/env python3
"""Render the plasmoid's Dashboard offscreen against the live helper daemon
and save a PNG, so visual regressions (blank popups, broken layouts) are
caught without a Plasma restart cycle.
"""
import faulthandler
import os
import shutil
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
faulthandler.dump_traceback_later(6, exit=True)
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "plasmoid"
STAGE = Path("/tmp/codex-render-pkg")

if STAGE.exists():
    shutil.rmtree(STAGE)
shutil.copytree(SRC, STAGE)

wrapper = Path("/tmp/codex-render-wrapper.qml")
wrapper.write_text(f"""
import QtQuick
import "file://{STAGE}/contents/ui" as UI
import "file://{STAGE}/contents/ui/components" as UIComponents

Rectangle {{
    width: 366
    height: 660
    color: "#20202a"

    UIComponents.AnimationClock {{ id: animClock; animationsEnabled: false; visibleToUser: true }}
    UI.CodexData {{ id: codexData; helperPort: 47631; pollIntervalMs: 1500 }}

    UI.Dashboard {{
        id: dash
        anchors.fill: parent
        dataSource: codexData
        clock: animClock
        configuration: ({{
            pageThemeOverview: "Astra",
            pageThemeActivity: "Luna",
            pageThemeModels: "Terra",
            pageThemeHealth: "Sol",
            cardDensity: "standard",
            animationsEnabled: false,
            showDataStatus: true,
            sparkleIntensity: 1,
            glowIntensity: 1,
            backgroundOpacity: 0.85,
            frostedGlass: true,
            cardLayout: "",
        }})
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
print("source ready, showing…", flush=True)
view.show()

def grab():
    root_item = view.rootObject()
    if root_item is None:
        print("no root object", flush=True)
        os._exit(2)

    # Synchronous window grab — grabToImage(callback) rejects Python callables
    # on current PySide6 and a callback-based grab never completes offscreen.
    image = view.grabWindow()
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/codex-dashboard.png"
    image.save(out)
    print("saved", out, flush=True)
    colors = set()
    samples = 0
    for y in range(0, image.height(), 8):
        for x in range(0, image.width(), 8):
            colors.add(image.pixel(x, y))
            samples += 1
    print(f"distinct sampled colors: {len(colors)} / {samples} samples", flush=True)
    os._exit(0 if len(colors) > 8 else 3)

# Let the first poll land and layouts settle, then grab once.
QTimer.singleShot(2500, grab)
QTimer.singleShot(15000, lambda: os._exit(4))  # timeout guard
sys.exit(app.exec())
