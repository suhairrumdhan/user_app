# اختبارات تطبيق المستخدم غير الوظيفية — الفصل الثالث

هذه الحزمة تخص تطبيق المستخدم فقط، ولا تشمل لوحة الإدارة أو تطبيق الصيدلية. لكل حالة خطة منفصلة هنا وملف نتيجة مستقل في `test_results/non_functional_user/`.

## أوامر التشغيل

اختبارات Flutter الموجودة:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application'
flutter test
```

قواعد Firestore وStorage على Emulator معزول:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application\functions'
npm run test:emulator
```

عقود انتقال الحالة والمهلة:

```powershell
Set-Location 'C:\Users\hp\StudioProjects\user_application\functions'
node --test test/f03/decision-and-timing.test.js test/f03/order-lifecycle.test.js
```

الأوامر الآلية لا تستبدل اختبار المشاركين أو Android أو الحمل الفعلي. لا تسجل الحالة ناجحة حتى تُنفذ جميع خطوات القبول ويُحفظ دليلها. الحالات اليدوية موضحة صراحة.

## الحالات

- `NFR-TC-01.md` قابلية الاستخدام.
- `NFR-TC-02.md` أداء البحث تحت التزامن.
- `NFR-TC-03.md` زمن ودقة معالجة الوصفات.
- `NFR-TC-04.md` منع الوصول غير المصرح.
- `NFR-TC-05.md` خصوصية البيانات وعزل الملكية.
- `NFR-TC-06.md` الاعتمادية وإعادة المحاولة.
- `NFR-TC-07.md` التذكيرات دون اتصال.
- `NFR-TC-08.md` توافق Android.
- `NFR-TC-09.md` التكامل واتساق الخدمات.
- `NFR-TC-10.md` شفافية التقدير ومهلة الاستلام.
