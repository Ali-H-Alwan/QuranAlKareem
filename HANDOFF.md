# HANDOFF — ملخّص حالة مشروع «القرآن الكريم»

> ملف تسليم لبدء محادثة جديدة دون فقدان السياق. آخر تحديث: نهاية محادثة سابقة.
> تطوير: **شركة الرائد للحلول البرمجية**.

## نبذة
تطبيق سطح مكتب **WPF / .NET 9** لعرض القرآن الكريم، مع بحث متقدّم وإعراب وتفسير وتلاوة.
- **GitHub:** https://github.com/Ali-H-Alwan/QuranAlKareem (الفرع `main`، متزامن).
- **الإصدار الحالي:** `1.0.3` (في `QuranAlKareem.App.csproj`).

## البنية
| المشروع | الدور |
|---------|------|
| `QuranAlKareem.App` | واجهة WPF (MVVM، CommunityToolkit.Mvvm)، تبويبات |
| `QuranAlKareem.Core` | النماذج، الخدمات، `ArabicText` (تطبيع عربي) |
| `QuranAlKareem.Data` | SQLite، استيراد البيانات، `QuranDatabase`، `Grammar` (إعراب) |

الواجهة **تبويبات مثل المتصفّح** (MainWindow = TabControl): تبويب «البحث»، تبويب «نتائج البحث»،
تبويبات صفحات المصحف (قابلة للإغلاق)، وتبويب «الإعدادات» (واحد فقط). المحتوى UserControls في `Views/`.

## المزايا المنجزة
- عرض المصحف بتبرير متّصل مثل المصحف الحقيقي؛ صفحة واحدة (مع شريط معلومات/إحصائيات) أو صفحتين.
- بحث نصّي + بالجذر، يتجاهل التشكيل، يوحّد الحروف (ة/ه، الألفات، الياء)، يطابق الرسمين الإملائي والعثماني
  (أعمدة `NormText/NormUthmani/LightText/LightUthmani`؛ البحث بالجذر عبر `Root/NormLemma/NormForm`).
- الإعراب لكل كلمة (نوعها/حالتها/علامتها) من Quranic Arabic Corpus.
- التفسير الميسَّر لكل آية (جدول `Tafsir`، 6236)، يعمل أوفلاين.
- التلاوة (4 قُرّاء: الحصري/المنشاوي/عبد الباسط/السديس) من everyayah.com، **تحميل مسبق ثم تشغيل أوفلاين**،
  تمييز الآية الجارية، والنقر على آية أثناء التلاوة ينقل الصوت إليها.
- إعدادات (صفحة كاملة): خيارات البحث، شكل النسخ (مع/بدون معلومات، مع/بدون تشكيل)، صفحتين، الخط/الحجم،
  **إدارة تحميل الصوت** (حالة كل قارئ، تحميل كامل المصحف أول مرة، حذف)، التحديث، ومعلومات البرنامج.
- إحصائيات البحث (شريط جانبي، اسم السورة كامل + شريط نسبي).
- نظام تحديث (AutoUpdater.NET)، ونشر **self-contained** لا يحتاج تنصيب .NET.

## مصادر البيانات (في `QuranAlKareem.App/Data/`)
- `quran-uthmani.json` (عثماني + صفحات/أجزاء/أحزاب/سجدات) — AlQuran Cloud.
- `quran-simple.json` (إملائي مبسّط، لفهرسة البحث) — AlQuran Cloud.
- `morphology.txt` (الصرف/الجذور/الإعراب) — Quranic Arabic Corpus (مرآة `mustafa0x/quran-morphology`).
- `tafsir-muyassar.json` (التفسير الميسَّر، `ar.muyassar`) — AlQuran Cloud.
- قاعدة البيانات `quran.db` تُبنى محلياً أول تشغيل من هذه الملفات (مستثناة من git، مرفقة جاهزة في النُسخ المنشورة).

## الإصدار والتحديث
- سكربت الإصدار: `build-release.ps1` — مثال: `powershell -ExecutionPolicy Bypass -File build-release.ps1 -Version 1.0.4`
  (يرفع الإصدار، ينشر self-contained single-file، يضمّن `quran.db` و`Data/`، يضغط في `release/`، يولّد `deploy/VersionInfo.xml`).
- فولدر التحديث على السيرفر: `https://update.alraed-iq.com/quran_alihasan/` (يُرفع إليه ملف الـ zip و`VersionInfo.xml`).
- تعليمات: `deploy/README-تعليمات-الرفع.md`.

## مفاتيح/تنبيهات تقنية
- `UseWindowsForms=true` يسبّب تعارض أسماء (Application/Button/UserControl/Brush/Orientation) — تُحلّ بـ `using` aliases.
- WPF `LineHeight` بالبكسل لا بالنسبة — يُضبط في كود MushafView = `FontSize*1.9` مع `BlockLineHeight`.
- لمنع قفز قائمة النتائج عند النقر: `RequestBringIntoView` يُعالَج ويُلغى.
- الإعدادات في `%AppData%/QuranAlKareem/settings.json`؛ ذاكرة الصوت في `%AppData%/QuranAlKareem/audio/<folder>/`.

## مهامّ مطروحة / التالي
- **خطة نظام «فلتر» للأندرويد و iOS** بنفس مزايا هذا التطبيق — طلب المستخدم بدأ بها ولم تكتمل. (المقصود غالباً تطبيق موبايل مماثل.)
- لم يُنجز بعد: عرض الآية كصورة من مصحف مطبوع حقيقي (يحتاج صور صفحات).

## تفضيلات المستخدم
- الردّ بالعربية (لهجة عراقية).
- قاعدة عامة: عند طلب «نبدأ من جديد»، احفظ ملخّص المحادثة في ملف md أولاً (هذا الملف نتيجتها).
