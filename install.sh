#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

echo "Installing dependencies..."
apt-get update -y >/dev/null
apt-get install -y cups ghostscript >/dev/null

echo "Installing CUPS filter..."
install -Dm755 cups/filter/ups_4x6_autofit \
  /usr/local/lib/cups/filter/ups_4x6_autofit

echo "Installing config (won't overwrite existing)..."
install -Dm644 -n cups/config/upslabel-autofit.conf \
  /etc/upslabel-autofit.conf || true

echo "Detecting label printer..."
PRINTER="$(scripts/find_printer.sh || true)"
[[ -n "$PRINTER" ]] || { echo "No Bixolon/Zebra printer found."; exit 2; }

echo "Using printer: $PRINTER"

PPD_SRC="/etc/cups/ppd/${PRINTER}.ppd"
PPD_DST="/etc/cups/ppd/UPS_4x6_Autofit.ppd"

cp -f "$PPD_SRC" "$PPD_DST"

if ! grep -q ups_4x6_autofit "$PPD_DST"; then
  echo '*cupsFilter: "application/pdf 0 ups_4x6_autofit"' >> "$PPD_DST"
fi

URI="$(lpstat -v "$PRINTER" | sed -n 's/^device for .*: //p')"

lpadmin -x UPS_4x6_Autofit >/dev/null 2>&1 || true
lpadmin -p UPS_4x6_Autofit -E -v "$URI" -P "$PPD_DST"

lpoptions -p UPS_4x6_Autofit \
  -o PageSize=w288h432 \
  -o Resolution=203dpi >/dev/null 2>&1 || true

systemctl restart cups || service cups restart

echo
echo "✔ Installed printer: UPS_4x6_Autofit"
echo "✔ Available to ALL users"
