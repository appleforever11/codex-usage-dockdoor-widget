#!/usr/bin/env python3
"""Compile every plasmoid QML file with the real QML engine (QQmlComponent).

Reproduces the compile-stage errors plasmashell reports ("X is not a type",
"Property value set multiple times", unresolved imports) for the whole package
in one pass, without instantiating objects (no runtime side effects).
"""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtGui import QGuiApplication
from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlEngine, QQmlComponent

app = QGuiApplication([])

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
engine = QQmlEngine()
for p in ["/usr/lib/qt6/qml", str(root / "contents/ui"),
          str(root / "contents/ui/components"), str(root / "contents/ui/cards"),
          str(root / "contents/config")]:
    engine.addImportPath(p)

failures = 0
for path in sorted(root.rglob("*.qml")):
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(path)))
    messages = []
    for error in component.errors():
        text = error.toString().strip()
        # Drop unresolvable-context noise we cannot stub (attached Plasmoid in
        # standalone files); keep everything else.
        messages.append(text)
    if component.status() == QQmlComponent.Status.Error or messages:
        failures += 1
        print(f"=== {path}")
        for m in messages:
            print(f"    {m}")

print(f"FILES WITH COMPILE ERRORS: {failures}")
sys.exit(1 if failures else 0)
