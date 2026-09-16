#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
version="$(tr -d '[:space:]' < "$root_dir/VERSION")"
archive="$root_dir/Dist/CodexUsage-v$version.zip"
signer="$root_dir/build/sparkle/bin/sign_update"
[[ -f "$archive" ]] || { print -u2 "Missing notarized application archive"; exit 1; }
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    signature="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$signer" --ed-key-file - -p "$archive")"
else
    signature="$("$signer" --account codex-usage-widget -p "$archive")"
fi
/usr/bin/python3 - "$archive" "$version" "$signature" "$root_dir/Dist/appcast.xml" <<'PY'
import datetime
import email.utils
import pathlib
import sys
import xml.etree.ElementTree as ET

archive, version, signature, output = sys.argv[1:]
namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", namespace)
root = ET.Element("rss", version="2.0")
channel = ET.SubElement(root, "channel")
ET.SubElement(channel, "title").text = "Codex Usage for DockDoor Pro"
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = f"Codex Usage {version}"
ET.SubElement(item, "pubDate").text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(item, f"{{{namespace}}}version").text = version
ET.SubElement(item, f"{{{namespace}}}shortVersionString").text = version
ET.SubElement(item, f"{{{namespace}}}minimumSystemVersion").text = "14.0"
ET.SubElement(item, "description").text = (
    f"🚀 Codex Usage {version} beta brings the personal build's living dashboard to the dock. "
    "🧭 Four swipeable pages cover Overview, Activity, Models, and Health, with reorderable cards and focused detail views. "
    "🎨 Astra, Luna, Sol, Terra, and Rainbow themes now carry through rings, bars, charts, surfaces, breathing atmosphere, and floating sparkles. "
    "🖱️ Two-finger trackpad swipes and keyboard navigation move between pages, while 🧲 model and page actions can provide haptic feedback. "
    "🫧 Transparent compact, extended horizontal, and extended vertical previews are ready for DockDoor Pro's optional Reflective Shelf beta. "
    "🔒 This is the personal companion edition; the marketplace variant keeps its separate read-only update path."
)
ET.SubElement(item, "enclosure", {
    "url": f"https://github.com/appleforever11/codex-usage-dockdoor-widget/releases/download/v{version}/CodexUsage-v{version}.zip",
    "length": str(pathlib.Path(archive).stat().st_size),
    "type": "application/octet-stream",
    f"{{{namespace}}}edSignature": signature,
})
ET.indent(root)
ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)
print(f"Signed appcast for {version}: {output}")
PY
