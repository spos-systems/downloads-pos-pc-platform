# SPOS PC Downloads
حزم تحديث منظومة صولة للكمبيوتر — SPOS Solah PC application packages.

## التثبيت — الطريقة الموصى بها 🌟

### لينكس (سطر واحد)
```bash
curl -fsSL https://raw.githubusercontent.com/spos-systems/downloads-pos-pc-platform/main/SPOS-Solah-PC-Linux-Install.sh | sudo bash
```
ينزّل أحدث إصدار رسمي، يتحقق من بصمته SHA256، ويثبّته عبر apt.

> 💡 **ظهرت لديك رسالة «Snap version of curl» أو فشل التنزيل؟** لا مشكلة —
> المثبّت الحديث يتجاوزها تلقائياً (يستخدم wget الأصلي أولاً، أو يمرر تنزيل
> curl عبر stdout بدل الكتابة في /tmp الذي تحجبه Snap). وإن أحببت بديلاً صريحاً:
> ```bash
> wget -qO- https://raw.githubusercontent.com/spos-systems/downloads-pos-pc-platform/main/SPOS-Solah-PC-Linux-Install.sh | sudo bash
> ```

### ويندوز
حمّل المثبّت الجميل الصغير وشغّله — ينزّل أحدث إصدار ويثبّته تلقائياً على جهازك
(نفس مثبّت السحابية: واجهة عربية متحركة، تنزيل قابل للاستئناف، تحقق بصمة،
وتثبيت RustDesk للدعم عن بعد دائماً مع المنظومة):

```
https://github.com/spos-systems/downloads-pos-pc-platform/releases/latest/download/SPOS-Solah-PC-Setup.exe
```

## تنزيل مباشر للحزم
| الجهاز | الرابط الثابت (أحدث دائماً) |
| --- | --- |
| ويندوز — حزمة كاملة | `releases/latest/download/SPOS-Solah-PC-Windows-x64.zip` |
| ويندوز — مثبّت كامل تقليدي | `releases/latest/download/SPOS-Solah-PC-Windows-Setup-x64.exe` |
| لينكس — المثبّت ⭐ (أوبونتو/ديبيان/منت/زورين) | `releases/latest/download/SPOS-Solah-PC-Linux-x64.deb` |
| لينكس — محمول بلا تثبيت (أي توزيعة) | `releases/latest/download/SPOS-Solah-PC-Linux-x64.AppImage` |
| لينكس — حزمة كاملة (zip) | `releases/latest/download/SPOS-Solah-PC-Linux-x64.zip` |

(أضف `https://github.com/spos-systems/downloads-pos-pc-platform/` قبل كل مسار)

### 🐧 تثبيت لينكس عبر حزمة .deb (أوبونتو/ديبيان/منت/زورين)
نزّل الحزمة من الجدول أعلاه، ثم من الطرفية داخل مجلد التنزيلات:
```bash
sudo apt install ./SPOS-Solah-PC-Linux-x64.deb
```

> ⚠️ **مركز تطبيقات أوبونتو (الواجهة الرسومية) لا يثبّت ملفات .deb المحلية**
> في الإصدارات الحديثة (22.04 وأحدث): النقر المزدوج على الحزمة قد لا يفعل
> شيئاً أو يعرض خطأ «غير مدعوم / not supported». هذا قصور معروف في أوبونتو
> نفسها وليس في حزمتنا. الحلول: سطر الأوامر أعلاه، أو المثبّت بسطر واحد في
> أعلى الصفحة (الأسهل)، أو ثبّت `gdebi` بـ `sudo apt install gdebi` ثم افتح
> به ملف الحزمة.

بعد التثبيت ستجد «SPOS Solah PC» في قائمة التطبيقات. للإزالة: `sudo apt remove spos-solah-pc`
(AppImage يعمل مباشرة بدون تثبيت: `chmod +x SPOS-Solah-PC-Linux-x64.AppImage && ./SPOS-Solah-PC-Linux-x64.AppImage`)

الدعم الفني: 0935535606 • واتساب: +218 93 553 5606 • spos.ly
