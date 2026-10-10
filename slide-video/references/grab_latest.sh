#!/bin/bash
T="$1"; DEST="$HOME/projects/mercari-course/videos/photo-tips/img"
NAME=$(osascript - "$DEST" <<'AS'
on run argv
  set destPosix to item 1 of argv
  tell application "Finder"
    set dl to (path to downloads folder)
    set s to (sort (every file of dl whose name extension is "png") by modification date)
    set f to item (count of s) of s
    set destFolder to POSIX file destPosix as alias
    duplicate f to destFolder with replacing
    return name of f
  end tell
end run
AS
)
[ -n "$NAME" ] && mv -f "$DEST/$NAME" "$DEST/$T.png" && echo "$NAME -> $T.png $(stat -f %z "$DEST/$T.png")"
