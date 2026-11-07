#!/usr/bin/env bash
# =====================================================================
# SPOS Solah PC — مثبّت لينكس الصغير (المثبّت الجميل للينكس)
# ---------------------------------------------------------------------
# مكافئ SPOS-Solah-PC-Setup.exe في ويندوز: ملف صغير (هذا السكربت ~7KB)
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
# دروس v1.9.11 (خطأ الزبون: «تم التنزيل: 0» ثم «ليس حزمة .deb صالحة»):
#   نسخة Snap من curl محصورة داخل /tmp خاص بها — فأي كتابة عبر
#   `curl -o /tmp/...` "تنجح" من وجهة نظر curl لكن الملف لا يظهر أبداً
#   في /tmp الحقيقي (يبقى 0 بايت). الحل الجذري هنا:
#     1) نفضّل wget (حزمة apt أصلية — غير محصورة إطلاقاً).
#     2) مع curl نكتب عبر stdout فقط: bash نفسه (غير محصور) هو من
#        يفتح الملف الهدف: curl ... > "$out" — فتصل البايتات أياً كان
#        حصر curl، تماماً كما يعمل أنبوب `curl | bash` نفسه.
#     3) المظهر يُقرأ في متغير عبر stdout — بلا ملفات مؤقتة نهائياً.
# دروس v1.9.10: grep وحده لا يقرأ JSON متعدد الأسطر (كتلة "deb" تمتد
#   على عدة أسطر) — لهذا كان المثبّت يتوقف بعد السطر الترحيبي بصمت.
# دروس ما بعد v1.9.10 (طلب الزبون): المثبّت يجب أن يضع اختصار سطح
#   المكتب بنفسه مثل مثبّت ويندوز — لا أن يُترك الزبون لأوامر يدوية.
#   (قسم 5 أسفل: SUDO_USER + xdg-user-dir + gio trusted).
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

# ---------- أدوات التنزيل — آمنة ضد إصدار Snap من curl ----------
# wget (من apt) غير محصور: نفضّله إن وُجد. وإن اضطررنا لـ curl (قد يكون
# نسخة Snap لا ترى /tmp الحقيقي) فالكتابة عبر stdout فقط — الملف الهدف
# يفتحه bash الحقيقي فتصل البايتات مهما كان حصر curl.
download() { # <url> <output-file>
  if command -v wget >/dev/null 2>&1; then
    if wget --tries=3 --timeout=30 -O "$2" "$1"; then return 0; fi
    command -v curl >/dev/null 2>&1 || return 1
    warn "تعذر wget — إعادة المحاولة عبر curl…"
  fi
  curl -fSL --retry 3 --retry-delay 2 --connect-timeout 15 "$1" > "$2"
}
read_url() { # <url> — يطبع المحتوى على stdout
  if command -v wget >/dev/null 2>&1; then
    if wget -q --tries=2 --timeout=20 -O - "$1"; then return 0; fi
  fi
  curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 15 "$1"
}

say "=== منظومة صولة للكمبيوتر — مثبّت لينكس ==="

# ---------- 1) أحدث إصدار من مظهر التحديث (في متغير — بلا ملفات مؤقتة) ----------
MANIFEST_JSON=""
for u in "${MANIFEST_URLS[@]}"; do
  if t=$(read_url "$u" 2>/dev/null); then MANIFEST_JSON="$t"; fi
  if [ -n "$MANIFEST_JSON" ]; then break; fi
done

VERSION=""
DEB_URL=""
DEB_SHA=""
if [ -n "$MANIFEST_JSON" ]; then
  # الطبقة 1: تحليل JSON حقيقي بـ python3 (مضمون على أوبونتو/ديبيان الحديثة
  # ويتعامل مع أي تنسيق: متعدد الأسطر أو مضغوط في سطر واحد) — عبر stdin
  if command -v python3 >/dev/null 2>&1; then
    if PYV=$(printf '%s' "$MANIFEST_JSON" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
deb = d.get("deb") if isinstance(d.get("deb"), dict) else {}
print(d.get("latest_version") or "")
print(deb.get("url") or "")
print(deb.get("sha256") or "")' 2>/dev/null); then
      VERSION=$(printf '%s\n' "$PYV" | sed -n '1p')
      DEB_URL=$(printf '%s\n' "$PYV" | sed -n '2p')
      DEB_SHA=$(printf '%s\n' "$PYV" | sed -n '3p')
    fi
  fi
  # الطبقة 2: awk — اقتطاع كتلة «deb» متعددة الأسطر (من "deb": { حتى أول })
  if [ -z "$DEB_URL" ]; then
    DEB_BLOCK=$(printf '%s\n' "$MANIFEST_JSON" | awk '/"deb"[[:space:]]*:[[:space:]]*\{/{f=1} f{print; if (/\}/) exit}' 2>/dev/null || true)
    if [ -n "$DEB_BLOCK" ]; then
      DEB_URL=$(printf '%s\n' "$DEB_BLOCK" | grep -o '"url"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
      DEB_SHA=$(printf '%s\n' "$DEB_BLOCK" | grep -o '"sha256"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    fi
    if [ -z "$VERSION" ]; then
      VERSION=$(printf '%s\n' "$MANIFEST_JSON" | grep -o '"latest_version"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    fi
  fi
  # الطبقة 3: grep لسطر واحد مضغوط — "deb": { … } كاملة في سطر واحد
  if [ -z "$DEB_URL" ]; then
    DEB_URL=$(printf '%s\n' "$MANIFEST_JSON" | grep -o '"deb"[[:space:]]*:[[:space:]]*{[^}]*}' | grep -o '"url"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
    if [ -n "$DEB_URL" ]; then
      DEB_SHA=$(printf '%s\n' "$MANIFEST_JSON" | grep -o '"deb"[[:space:]]*:[[:space:]]*{[^}]*}' | grep -o '"sha256"[^,}]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || true)
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

# ---------- 2) التنزيل ----------
TMPDEB="$(mktemp --suffix=.deb)"
trap 'rm -f "$TMPDEB" 2>/dev/null || true' EXIT
say "جارٍ تنزيل الحزمة (نحو 107 ميغابايت)…"
if ! download "$DEB_URL" "$TMPDEB"; then
  err "تعذر تنزيل الحزمة — تحقق من الاتصال بالإنترنت وأعد المحاولة"
  err "الرابط: $DEB_URL"
  err "أو ثبّت يدوياً:  wget -O /tmp/spos.deb $DEB_URL && sudo apt install /tmp/spos.deb"
  exit 1
fi
say "تم التنزيل: $(du -h "$TMPDEB" | cut -f1)"

# ---------- 3) فحص الحزمة والتحقق من البصمة ----------
if [ ! -s "$TMPDEB" ]; then
  err "الملف المنزّل فارغ (0 بايت) رغم غياب رسالة خطأ — فشل خفي في التنزيل"
  err "إن كان curl لديك نسخة Snap فهذا سببه المعروف؛ ثبّت wget: sudo apt install wget ثم أعد المحاولة"
  err "أو يدوياً:  wget -O /tmp/spos.deb $DEB_URL && sudo apt install /tmp/spos.deb"
  exit 1
fi
if command -v dpkg-deb >/dev/null 2>&1; then
  if ! dpkg-deb -I "$TMPDEB" >/dev/null 2>&1; then
    err "الملف المنزّل ليس حزمة .deb صالحة — أعد المحاولة (قد يكون التنزيل مقطوعاً)"
    err "أو ثبّت يدوياً:  wget -O /tmp/spos.deb $DEB_URL && sudo apt install /tmp/spos.deb"
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
# mktemp ينشئ الملف بصلاحية 600 — مستخدم sandbox الـ _apt لا يستطيع قراءته
# فتظهر ملاحظة apt الشهيرة «Download is performed unsandboxed as root».
# صلاحية 644 كافية تماماً: ملف في /tmp يُقرأ للتثبيت فقط ثم يُحذف فوراً.
chmod 644 "$TMPDEB" 2>/dev/null || true
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
    err "  wget -O /tmp/spos.deb $DEB_URL"
    err "  sudo apt install /tmp/spos.deb"
    exit 1
  fi
fi

# ---------- 5) التكامل مع سطح المكتب تلقائياً (مثل مثبّت ويندوز) ----------
# السكربت يعمل بصلاحية الجذر، لكن المستخدم الفعلي في متغير SUDO_USER:
#   أ) نسخة مستوى المستخدم في ~/.local/share/applications — تظهر في
#      قائمة التطبيقات والبحث فوراً بلا خروج/دخول حتى لو تأخرت
#      فهرسة جنوم للمسار العام /usr/share/applications (بلاغ المالك:
#      «لا تظهر في القائمة الرئيسية») — وبما أن حزمة v1.9.11+ تحمل
#      اسماً عربياً (Name[ar]) وكلمات مفتاحية عربية فيعمل البحث بـ
#      «صولة» أيضاً، فإن النسخ هنا تحمل هذه الإدخالات تلقائياً.
#   ب) اختصار على سطح مكتب المستخدم نفسه موثّق فوراً (يعادل كليك
#      يمين ← Allow Launching في جنوم) — لا حاجة لأي خطوة يدوية.
SHORTCUT=""
MENU_COPIED=""
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] && [ -f /usr/share/applications/spos-solah-pc.desktop ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  # (أ) نسخة مستوى المستخدم للقائمة — تُقرأ فوراً بلا إعادة دخول
  LOCAL_APPS="$USER_HOME/.local/share/applications"
  if mkdir -p "$LOCAL_APPS" 2>/dev/null && cp /usr/share/applications/spos-solah-pc.desktop "$LOCAL_APPS/" 2>/dev/null; then
    chown -R "$SUDO_USER:" "$LOCAL_APPS/spos-solah-pc.desktop" 2>/dev/null || true
    chmod 644 "$LOCAL_APPS/spos-solah-pc.desktop" 2>/dev/null || true
    MENU_COPIED="1"
  fi
  update-desktop-database "$LOCAL_APPS" 2>/dev/null || true
  # (ب) اختصار سطح المكتب الموثّق
  DESK_DIR=""
  if command -v xdg-user-dir >/dev/null 2>&1; then
    DESK_DIR=$(sudo -u "$SUDO_USER" xdg-user-dir DESKTOP 2>/dev/null || true)
  fi
  if [ -z "$DESK_DIR" ] || [ ! -d "$DESK_DIR" ]; then DESK_DIR="$USER_HOME/Desktop"; fi
  if [ ! -d "$DESK_DIR" ] && [ -d "$USER_HOME/سطح المكتب" ]; then DESK_DIR="$USER_HOME/سطح المكتب"; fi
  if [ -d "$DESK_DIR" ]; then
    if cp /usr/share/applications/spos-solah-pc.desktop "$DESK_DIR/" 2>/dev/null; then
      chown "$SUDO_USER:" "$DESK_DIR/spos-solah-pc.desktop" 2>/dev/null || true
      chmod 755 "$DESK_DIR/spos-solah-pc.desktop" 2>/dev/null || true
      sudo -u "$SUDO_USER" gio set "$DESK_DIR/spos-solah-pc.desktop" metadata::trusted true 2>/dev/null || true
      SHORTCUT="$DESK_DIR"
    fi
  fi
fi

INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$PKG_NAME" 2>/dev/null || true)
say ""
say "=== تم التثبيت بنجاح ✓ (النسخة ${INSTALLED_VERSION:-مجهولة}) ==="
if [ -n "$MENU_COPIED" ]; then
  say "التطبيق في قائمة التطبيقات ✓ — ابحث بـ spos أو «صولة» (يظهر أيضاً داخل تصنيف Office)"
fi
if [ -n "$SHORTCUT" ]; then
  say "وضعنا لك اختصاراً على سطح المكتب ✓ (جاهز للنقر فوراً)"
fi
say "أو من الطرفية: spos-solah-pc"
say "للتحديث مستقبلاً: أعد تشغيل نفس أمر التثبيت"
say "للإزالة لاحقاً: sudo apt remove $PKG_NAME"
