#!/bin/zsh

set -euo pipefail
setopt NULL_GLOB

repository="${CODEX_WIDGET_REPOSITORY:-appleforever11/codex-usage-dockdoor-widget}"
release_api="${CODEX_WIDGET_RELEASE_API:-https://api.github.com/repos/$repository/releases/latest}"
manage_dockdoor="${CODEX_WIDGET_MANAGE_DOCKDOOR:-1}"
support_dir="$HOME/Library/Application Support/CodexUsageWidget"
widgets_dir="$HOME/Library/Application Support/DockDoorPro/Widgets"
backup_root="$HOME/Library/Application Support/DockDoorPro/WidgetUpdaterBackups"
state_file="$support_dir/installed-version"
work_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-widget-update.XXXXXX")"
metadata_file="$work_dir/release.json"
archive_file="$work_dir/CodexProjectTracker.bundle.zip"
extract_dir="$work_dir/extracted"
staged_bundle="$widgets_dir/.CodexProjectTracker.update.bundle"

cleanup() {
    /bin/rm -rf "$work_dir" "$staged_bundle"
}
trap cleanup EXIT

log() {
    print "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*"
}

version_is_newer() {
    local candidate="$1"
    local installed="$2"
    local -a candidate_parts installed_parts
    candidate_parts=("${(@s:.:)candidate}")
    installed_parts=("${(@s:.:)installed}")

    for index in 1 2 3; do
        local candidate_part="${candidate_parts[$index]:-0}"
        local installed_part="${installed_parts[$index]:-0}"
        (( 10#$candidate_part > 10#$installed_part )) && return 0
        (( 10#$candidate_part < 10#$installed_part )) && return 1
    done
    return 1
}

/bin/mkdir -p "$support_dir" "$widgets_dir" "$backup_root" "$extract_dir"

log "Checking GitHub for a Codex Usage update."
/usr/bin/curl -fsSL --retry 3 --connect-timeout 10 \
    "$release_api" \
    -o "$metadata_file"

latest_tag="$(/usr/bin/jq -er '.tag_name' "$metadata_file")"
latest_version="${latest_tag#v}"
asset_url="$(/usr/bin/jq -er '.assets[] | select(.name == "CodexProjectTracker.bundle.zip") | .browser_download_url' "$metadata_file")"
asset_digest="$(/usr/bin/jq -er '.assets[] | select(.name == "CodexProjectTracker.bundle.zip") | .digest' "$metadata_file")"
expected_sha="${asset_digest#sha256:}"

installed_bundles=("$widgets_dir"/CodexProjectTracker*.bundle(N))
installed_version=""
if (( ${#installed_bundles[@]} > 0 )); then
    installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${installed_bundles[1]}/Contents/Info.plist" 2>/dev/null || true)"
fi
if [[ -z "$installed_version" && -s "$state_file" ]]; then
    installed_version="$(<"$state_file")"
fi

if [[ -n "$installed_version" ]] && ! version_is_newer "$latest_version" "$installed_version"; then
    log "Codex Usage $installed_version is current; latest release is $latest_version."
    exit 0
fi

log "Downloading Codex Usage $latest_version."
/usr/bin/curl -fsSL --retry 3 --connect-timeout 10 "$asset_url" -o "$archive_file"
actual_sha="$(/usr/bin/shasum -a 256 "$archive_file" | /usr/bin/awk '{print $1}')"
if [[ -z "$expected_sha" || "$actual_sha" != "$expected_sha" ]]; then
    print -u2 "Update rejected: GitHub digest verification failed."
    exit 1
fi

/usr/bin/ditto -x -k "$archive_file" "$extract_dir"
source_bundle="$extract_dir/CodexProjectTracker.bundle"
if [[ ! -d "$source_bundle" ]]; then
    print -u2 "Update rejected: the release archive contains no Codex widget bundle."
    exit 1
fi

/usr/bin/ditto "$source_bundle" "$staged_bundle"
/usr/bin/xattr -dr com.apple.quarantine "$staged_bundle" 2>/dev/null || true
/usr/bin/plutil -lint "$staged_bundle/Contents/Info.plist" >/dev/null
binary="$staged_bundle/Contents/MacOS/CodexProjectTracker"
/usr/bin/lipo "$binary" -verify_arch arm64
/usr/bin/lipo "$binary" -verify_arch x86_64

target_name="CodexProjectTracker.bundle"
if (( ${#installed_bundles[@]} > 0 )); then
    target_name="${installed_bundles[1]:t}"
fi
target_bundle="$widgets_dir/$target_name"
backup_dir="$backup_root/$(/bin/date '+%Y%m%d-%H%M%S')"
was_running=false
if [[ "$manage_dockdoor" == "1" ]]; then
    /usr/bin/pgrep -x "DockDoor Pro" >/dev/null 2>&1 && was_running=true
fi

if $was_running; then
    /usr/bin/osascript -e 'tell application "DockDoor Pro" to quit' >/dev/null 2>&1 || true
    for _ in {1..20}; do
        /usr/bin/pgrep -x "DockDoor Pro" >/dev/null 2>&1 || break
        sleep 0.25
    done
fi

/bin/mkdir -p "$backup_dir"
for installed_bundle in "${installed_bundles[@]}"; do
    /bin/mv "$installed_bundle" "$backup_dir/"
done

if ! /bin/mv "$staged_bundle" "$target_bundle"; then
    for backup_bundle in "$backup_dir"/CodexProjectTracker*.bundle(N); do
        /bin/mv "$backup_bundle" "$widgets_dir/"
    done
    print -u2 "Update installation failed; the previous widget was restored."
    exit 1
fi

temporary_state="$work_dir/installed-version"
printf '%s\n' "$latest_version" >"$temporary_state"
/bin/mv -f "$temporary_state" "$state_file"

if $was_running; then
    /usr/bin/open -a "DockDoor Pro"
fi

log "Updated Codex Usage from ${installed_version:-unknown} to $latest_version."
log "Previous bundle backup: $backup_dir"
