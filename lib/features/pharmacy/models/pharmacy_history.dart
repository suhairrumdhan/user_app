class PharmacyHistory {
  final String name;        // اسم الصيدلية
  final String address;     // عنوان الصيدلية
  final String date;        // تاريخ الطلب أو آخر بحث
  final int searchCount;    // عدد مرات البحث أو عدد الأصناف المطلوبة

  PharmacyHistory({
    required this.name,
    required this.address,
    required this.date,
    required this.searchCount,
  });
}
