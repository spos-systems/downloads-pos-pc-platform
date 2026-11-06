#!/usr/bin/env bash
# =====================================================================
# SPOS Solah PC — مثبّت لينكس الصغير (المثبّت الجميل للينكس)
# ---------------------------------------------------------------------
# مكافئ SPOS-Solah-PC-Setup.exe في ويندوز: ملف صغير (هذا السكربت)
# ينزّل أحدث حزمة .deb رسمية ويتحقق من بصمتها SHA256 ثم يثبّتها عبر apt.
#
# الاستخدام (سطر واحد ينصح به الزبائن):
#   curl -fsSL <رابط-هذا-الملف> | sudo bash
# أو:
#   chmod +x SPOS-Solah-PC-Linux-Install.sh && sudo ./SPOS-Solah-PC-Linux-Install.sh
#
# المصادر (بترتيب المحاولة): jsDelivr ثم raw.githubusercontent — كلاهما
# يقدّم pc-latest.json بأحدث بصمة وحزمة.
# =====================================================================
set -euo pipefail

MANIFEST_URLS=(
  "https://cdn.jsdelivr.net/gh/spos-systems/downloads-pos-pc-platform@main/pc-latest.json"
  "https://raw.githubusercontent.com/spos-systems/downloads-pos-pc-platform/main/pc-latest.json"
)
FALLBACK_DEB_URL="https://github.com/spos-systems/downloads-pos-pc-platform/releases/latest/download/SPOS-Solah-PC-Linux-x64.deb"

say() { printf '\033[1;34m%s\033[0m\n' "$*"; }
err() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] || { err "شغّل السكربت بصلاحية الجذر: sudo bash $0"; exit 1; }
command -v curl >/dev/null || command -v wget >/dev/null || { err "مطلوب curl أو wget للتثبيت"; exit 1; }

fetch() { # <url> <output-file>
  if command -v curl >/dev/null; then curl -fSL --retry 3 --connect-timeout 15 "$1" -o "$2"
  else wget -q --tries=3 --timeout=15 "$1" -O "$2"; fi
}

say "=== منظومة صولة للكمبيوتر — مثبّت لينكس ==="

# ---------- 1) أحدث إصدار من مظهر التحديث ----------
MANIFEST=""
for u in "${MANIFEST_URLS[@]}"; do
  if fetch "$u" /tmp/spos-pc-latest.json 2>/dev/null; then MANIFEST=/tmp/spos-pc-latest.json; break; fi
done

DEB_URL="$FALLBACK_DEB_URL"
DEB_SHA=""
VERSION=""
if [ -n "$MANIFEST" ]; then
  # jq غير مضمون توفره — استخراج بسيط بـ grep/sed (الملف JSON بسيط)
  VERSION=$(grep -o '"latest_version"[^,]*' "$MANIFEST" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  DEB_URL=$(grep -o '"deb"[^}]*}' "$MANIFEST" | grep -o '"url"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  DEB_SHA=$(grep -o '"deb"[^}]*}' "$MANIFEST" | grep -o '"sha256"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi
[ -n "$DEB_URL" ] || DEB_URL="$FALLBACK_DEB_URL"
say "أحدث إصدار: ${VERSION:-غير معروف — الرابط الدائم}"
say "الحزمة: $DEB_URL"

# ---------- 2) التنزيل مع استئناف ----------
TMPDEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMPDEB" /tmp/spos-pc-latest.json 2>/dev/null || true' EXIT
say "جارٍ تنزيل الحزمة (107MB تقريباً)…"
fetch "$DEB_URL" "$TMPDEB"
say "تم التنزيل: $(du -h "$TMPDEB" | cut -f1)"

# ---------- 3) التحقق من البصمة ----------
if [ -n "$DEB_SHA" ]; then
  say "التحقق من بصمة SHA256…"
  ACTUAL=$(sha256sum "$TMPDEB" | cut -d' ' -f1)
  if [ "$ACTUAL" != "$DEB_SHA" ]; then
    err "البصمة غير مطابقة! المتوقعة: $DEB_SHA"
    err "الفعليـة:  $ACTUAL"
    err "لا يُثبَّت شيء — أعد المحاولة (قد يكون التنزيل مقطوعاً أو الاتصال منصتاً)"
    exit 1
  fi
  say "البصمة مطابقة ✓"
else
  say "تحذير: تعذر جلب البصمة من مظهر التحديث — التثبيت بلا تحقق"
fi

# ---------- 4) التثبيت ----------
say "جارٍ التثبيت…"
if command -v apt >/dev/null; then
  apt install -y "$TMPDEB"
else
  err "هذا المثبّت لتوزيعات ديبيان/أوبونتو (apt). للتوزيعات الأخرى استخدم ملف AppImage من صفحة التنزيل."
  exit 1
fi

say ""
say "=== تم التثبيت بنجاح ✓ ==="
say "افتح «SPOS Solah PC» من قائمة التطبيقات (تصنيف Office)"
say "للإزالة لاحقاً: sudo apt remove spos-solah-pc"
