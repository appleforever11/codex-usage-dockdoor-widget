#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
sparkle_dir="$root_dir/build/sparkle"
archive="$sparkle_dir/Sparkle-2.9.6.tar.xz"
expected="52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192"
mkdir -p "$sparkle_dir"
if [[ ! -f "$archive" ]]; then
    curl -fsSL --retry 3 https://github.com/sparkle-project/Sparkle/releases/download/2.9.6/Sparkle-2.9.6.tar.xz -o "$archive"
fi
actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { print -u2 'Sparkle archive checksum mismatch'; exit 1; }
tar -xf "$archive" -C "$sparkle_dir"
