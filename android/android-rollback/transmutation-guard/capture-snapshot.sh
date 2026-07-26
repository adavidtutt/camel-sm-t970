#!/system/bin/sh

STATE=/data/adb/transmutation-guard
OUTPUT=$STATE/enabled-packages.txt
TEMP=$STATE/enabled-packages.new

mkdir -p "$STATE"
chmod 700 "$STATE"

pm list packages -e --user 0 |
    sed 's/^package://' |
    sort -u > "$TEMP"

if [ ! -s "$TEMP" ]; then
    echo "Refusing empty snapshot" >&2
    exit 1
fi

mv "$TEMP" "$OUTPUT"
chmod 600 "$OUTPUT"
echo "Captured $(wc -l < "$OUTPUT") enabled packages"
