# إصدار وتحديث نظام القرآن الكريم

تطوير: **شركة الرائد للحلول البرمجية**

## فولدر التحديث على السيرفر
```
https://update.alraed-iq.com/quran_alihasan/
```

## النسخة الأولى (1.0.0) — جاهزة الآن
- النسخة المنشورة (self-contained، **لا تحتاج تنصيب .NET**):
  `release/QuranAlKareem_v1.0.0.zip`
- ملف معلومات التحديث: `deploy/VersionInfo.xml`

### للتوزيع على المستخدمين
أعطِهم `QuranAlKareem_v1.0.0.zip` → يفكّونه ويشغّلون `QuranAlKareem.App.exe` مباشرةً.
(النسخة تتضمّن قاعدة البيانات `quran.db` فتعمل فوراً بدون استيراد.)

## آلية التحديث (تلقائية)
عند فتح المستخدم للبرنامج، يفحص `VersionInfo.xml` على السيرفر. إذا كان
`<version>` فيه أحدث من النسخة المثبَّتة، تظهر له رسالة تحديث، وعند الموافقة
يُنزّل ملف الـ zip ويُحدّث البرنامج نفسه تلقائياً.

## إصدار تحديث جديد (مستقبلاً) — خطوة واحدة
شغّل سكربت الإصدار مع رقم النسخة الجديدة:
```powershell
powershell -ExecutionPolicy Bypass -File build-release.ps1 -Version 1.0.1
```
السكربت:
1. يرفع رقم الإصدار في المشروع.
2. ينشر نسخة self-contained مضغوطة في `release/QuranAlKareem_v1.0.1.zip`.
3. يولّد `deploy/VersionInfo.xml` محدّثاً.

ثم **ارفع ملفين** إلى `quran_alihasan/`:
1. `release/QuranAlKareem_v1.0.1.zip`
2. `deploy/VersionInfo.xml`

وبمجرّد رفعهما، سيصل التحديث لكل المستخدمين عند فتحهم البرنامج.

## النسخة الحالية
`1.0.0.0`
