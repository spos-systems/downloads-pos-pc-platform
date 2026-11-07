#!/usr/bin/env bash
# =====================================================================
# SPOS Solah PC — مثبّت لينكس الصغير (المثبّت الجميل للينكس)
# ---------------------------------------------------------------------
# مكافئ SPOS-Solah-PC-Setup.exe في ويندوز: ملف صغير (هذا السكربت ~6KB)
# ينزّل أحدث حزمة .deb رسمية ويتحقق من بصمتها SHA256 ثم يثبّتها عبر apt.
#
# الاستخدام (سطر واحد يُنصح به الزبائن):
#   curl -fsSL <رابط-هذا-الملف> | sudo bash
# أو:
#   chmod +x SPOS-Solah-PC-Linux-Install.sh && sudo ./SPOS-Solah-PC-Linux-Install.sh
#
# مصادر مظهر التحديث (بترتيب المحاولة): raw.githubusercontent ثم jsDelivr.
# قراءة JSON على ثلاث طبقات: python3 (الأدق) ثم awk (كتلة متعددة الأسطر)
# ثم grep (سطر واحد) — وأي فشل في التحليل لا يوقف السكربت أبداً: يسقط
# إلى الرابط الدائم لأحدث حزمة في ريليز GitHub.
#
# دروس v1.9.10: grep وحده لا يقرأ JSON متعدد الأسطر (كتلة "deb" تمتد
# على عدة أسطر) — لهذا كان المثبّت يتوقف بعد السطر الترحيبي بصمت.
# =====================================================================
set -euo pipefail

MANIFEST_URLS=(
  "https://raw.githubusercontent.com/spos-systems/downloads-pos-pc-platform/main/pc-latest.json"
  "https://cdn.jsdelivr.net/gh/spos-systems/downloads-pos-pc-platform@main/pc-latest.json"
)
FALLBACK_DEB_URL="https://github.com/spos-systems/downloads-pos-pc-platform/releases/latest/download/SPOS-Solah-PC-Linux-x64.deb"
PKG_NAME="spos-solah-pc"

say()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

[ "$(id -u)" -eq 0 ] || { err "شغّل السكربت بصلاحية الجذر (sudo)"; exit 1; }
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { err "مطلوب curl أو wget للتثبيت"; exit 1; }

fetch() { # <url> <output-file>
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 3 --retry-delay 2 --connect-timeout 15 -C - "$1" -o "$2"
  else
    wget -q --tries=3 --timeout=15 -O "$2" "$1"
  fi
}

say "=== منظومة صولة للكمبيوتر — مثبّت لينكس ==="

# ---------- 1) أحدث إصدار من مظهر التحديث ----------
MANIFEST=""
for u in "${MANIFEST_URLS[@]}"; do
  if fetch "$u" /tmp/spos-pc-latest.json 2>/dev/null; then MANIFEST=/tmp/spos-pc-latest.json; break; fi
done

VERSION=""
DEB_URL=""
DEB_SHA=""
if [ -n "$MANIFEST" ] && [ -s "$MANIFEST" ]; then
  # الطبقة 1: تحليل JSON حقيقي بـ python3 (مضمون على أوبونتو/ديبيان الحديثة
  # ويتعامل مع أي تنسيق: متعدد الأسطر أو مضغوط في سطر واحد)
  if command -v python3 >/dev/null 2>&1; then
    if PYV=$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    d = {}
deb = d.get("deb") if isinstance(d.get("deb"), dict) else {}
print(d.get("latest_version") or "")
print(deb.get("url") or "")
print(deb.get("sha256") or "")' "$MANIFEST" 2>/dev/null); then
      VERSION=$(printf '%s\n' "$PYV" | sed -n '1p')
      DEB_URL=$(printf '%s\n' "$PYV" | sed -n '2p')
      DEB_SHA=$(printf '%s\n' "$PYV" | sed -n '3p')
    fi
  fi
  # الطبقة 2: awk — اقتطاع كتلة «deb» متعددة الأسطر (من "deb": { حتى أول })
  if [ -z "$DEB_URL" ]; then
    DEB_BLOCK=$(awk '/"deb"[[:space:]]*:[[:space:]]*\{/{f=1} f{print; if (/\}/) exit}' "$MANIFEST" 2>/dev/null || true)
    if [ -n "$DEB_BLOCK" ]; then
      DEB_URL=$(printf '%s\n' "$DEB_BLOCK" | grep -o '"url"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
      DEB_SHA=$(printf '%s\n' "$DEB_BLOCK" | grep -o '"sha256"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    fi
    if [ -z "$VERSION" ]; then
      VERSION=$(grep -o '"latest_version"[^,]*' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    fi
  fi
  # الطبقة 3: grep لسطر واحد مضغوط — "deb": { … } كاملة في سطر واحد
  if [ -z "$DEB_URL" ]; then
    DEB_URL=$(grep -o '"deb"[[:space:]]*:[[:space:]]*{[^}]*}' "$MANIFEST" 2>/dev/null | grep -o '"url"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    if [ -n "$DEB_URL" ]; then
      DEB_SHA=$(grep -o '"deb"[[:space:]]*:[[:space:]]*{[^}]*}' "$MANIFEST" 2>/dev/null | grep -o '"sha256"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    fi
  fi
fi
# تحقق صحة ما استُخرج: الرابط ينتهي بـ .deb والبصمة ست عشرية 64 خانة
case "$DEB_URL" in
  https://*.deb) : ;;
  *) DEB_URL="" ;;
esac
if [ -z "$DEB_SHA" ] || ! printf '%s' "$DEB_SHA" | grep -Eq '^[0-9a-fA-F]{64}$'; then DEB_SHA=""; fi
if [ -z "$DEB_URL" ]; then
  DEB_URL="$FALLBACK_DEB_URL"
  warn "تعذر قراءة مظهر التحديث — سنستخدم الرابط الدائم لأحدث إصدار (بلا تحقق بصمة)"
fi
say "أحدث إصدار: ${VERSION:-غير معروف — الرابط الدائم}"
say "الحزمة: $DEB_URL"

# ---------- 2) التنزيل مع استئناف ----------
TMPDEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMPDEB" /tmp/spos-pc-latest.json 2>/dev/null || true' EXIT
say "جارٍ تنزيل الحزمة (نحو 107 ميغابايت)…"
if ! fetch "$DEB_URL" "$TMPDEB"; then
  err "تعذر تنزيل الحزمة — تحقق من الاتصال بالإنترنت وأعد المحاولة"
  err "الرابط: $DEB_URL"
  exit 1
fi
say "تم التنزيل: $(du -h "$TMPDEB" | cut -f1)"

# ---------- 3) فحص الحزمة والتحقق من البصمة ----------
if command -v dpkg-deb >/dev/null 2>&1; then
  if ! dpkg-deb -I "$TMPDEB" >/dev/null 2>&1; then
    err "الملف المنزّل ليس حزمة .deb صالحة — أعد المحاولة (قد يكون التنزيل مقطوعاً)"
    exit 1
  fi
fi
if [ -n "$DEB_SHA" ]; then
  say "التحقق من بصمة SHA256…"
  ACTUAL=$(sha256sum "$TMPDEB" | cut -d' ' -f1)
  if [ "$ACTUAL" != "$DEB_SHA" ]; then
    err "البصمة غير مطابقة! المتوقعة: $DEB_SHA"
    err "الفعليـة:  $ACTUAL"
    err "لا يُثبَّت شيء — أعد المحاولة"
    exit 1
  fi
  say "البصمة مطابقة ✓"
else
  warn "التثبيت بلا تحقق بصمة (تعذر جلبها) — الحزمة من المصدر الرسمي"
fi

# ---------- 4) التثبيت ----------
# ملاحظة: قد يُشغَّل السكربت عبر أنبوب (curl | sudo bash) لذا كل أمر قد
# يقرأ stdin يُعطى </dev/null كي لا يبتلع باقي أسطر السكربت من الأنبوب.
export DEBIAN_FRONTEND=noninteractive
say "جارٍ التثبيت…"
APT_OK=0
if command -v apt-get >/dev/null 2>&1; then
  if apt-get install -y "$TMPDEB" </dev/null; then APT_OK=1; fi
elif command -v apt >/dev/null 2>&1; then
  if apt install -y "$TMPDEB" </dev/null; then APT_OK=1; fi
else
  err "هذا المثبّت لتوزيعات ديبيان/أوبونتو (apt). للتوزيعات الأخرى استخدم ملف AppImage من صفحة التنزيل."
  exit 1
fi
if [ "$APT_OK" != 1 ]; then
  warn "تعذر التثبيت مباشرة — تحديث فهارس الحزم وإعادة المحاولة…"
  if command -v apt-get >/dev/null 2>&1; then
    if apt-get update </dev/null; then :; fi
    if apt-get install -y "$TMPDEB" </dev/null; then APT_OK=1; fi
  elif command -v apt >/dev/null 2>&1; then
    if apt update </dev/null; then :; fi
    if apt install -y "$TMPDEB" </dev/null; then APT_OK=1; fi
  fi
fi
if [ "$APT_OK" != 1 ]; then
  warn "محاولة أخيرة: dpkg ثم إصلاح التبعيات…"
  if ! dpkg -i "$TMPDEB" </dev/null; then
    if command -v apt-get >/dev/null 2>&1; then
      if apt-get -f install -y </dev/null; then :; fi
    fi
  fi
  if ! dpkg -s "$PKG_NAME" >/dev/null 2>&1; then
    err "فشل التثبيت — أعد تشغيل الأمر، وإن تكرر نفّذ يدوياً:"
    err "  sudo apt update && sudo apt install $DEB_URL"
    exit 1
  fi
fi

INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$PKG_NAME" 2>/dev/null || true)
say ""
say "=== تم التثبيت بنجاح ✓ (النسخة ${INSTALLED_VERSION:-مجهولة}) ==="
say "افتح «SPOS Solah PC» من قائمة التطبيقات (تصنيف Office)"
say "أو من الطرفية: spos-solah-pc"
say "للإزالة لاحقاً: sudo apt remove $PKG_NAME"
