// lib/core/constants/app_strings.dart

class AppStrings {
  AppStrings._();

  // === رسائل عامة / حوارات ===
  static const String dialogUnableToCompleteOperation = 'تعذر إتمام العملية';
  static const String dialogOk = 'حسناً';
  static const String dialogConfirm = 'تأكيد';
  static const String dialogCancel = 'إلغاء';
  static const String dialogErrorTitle = 'خطأ';
  static const String dialogConfirmPayment = 'تأكيد السداد';
  static const String dialogInvoiceCreated = 'تم إنشاء الفاتورة بنجاح';
  static const String dialogDeferredSettled = 'تم تسوية العملية المؤجّلة';
  static const String dialogPaymentDone = 'تم الدفع';
  static const String dialogBlendAdded = 'تمت إضافة الخلطة إلى السلة';
  static const String dialogBlendAddFailed = 'تعذر إضافة الخلطة';
  static const String dialogCustomBlendRecorded =
      'تم تسجيل توليفة العميل وخصم المخزون';

  // ديناميك – تأكيد دفع فاتورة مؤجلة
  static String confirmSettleAmount(double amount) =>
      'سيتم تثبيت دفع ${amount.toStringAsFixed(2)} جم.\nهل تريد المتابعة؟';

  static String confirmDeleteCustomBlend(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return 'هل تريد حذف هذه الخلطة؟';
    return 'هل تريد حذف خلطة $clean؟';
  }

  static String deferredSettleFailed(Object error) => 'تعذر التسوية: $error';

  // === أزرار عامة بالإنجليزي (في بعض الشاشات) ===
  static const String btnSellEn = 'بيع';
  static const String btnCancelEn = 'إلغاء';
  static const String btnLoadMore = 'عرض المزيد';

  // === نصوص شاشة الكاشير / النقطة ===
  static const String titlePos = 'نقطة البيع';
  static const String titleCart = 'سلة المشتريات';
  static const String titleSections = 'الأقسام';
  static const String titleDrinksSection = 'المشروبات';
  static const String titleSinglesSection = 'أصناف منفردة';
  static const String titleBlendsSection = 'توليفات البن';
  static const String titleExtrasSection = 'الإضافات';
  static const String titleCookiesSection = 'بسكوت ومعمول';
  static const String titleCustomBlendSection = 'توليفات العميل';
  static const String titleReadyBlends = 'توليفات جاهزة';

  static const String labelDeferredInvoice = 'مؤجلة';
  static const String labelInvoiceTotal = 'الإجمالي';
  static const String labelQuantityGrams = 'الكمية (جم)';
  static const String labelAmountLep = 'المبلغ (جم)';
  static const String labelAmountEgp = 'المبلغ (ج.م)';
  static const String labelGrams = 'جرامات';
  static const String labelCupPrice = 'سعر الكوب';
  static const String labelPrice = 'سعر';
  static const String labelUnitPricePiece = 'سعر القطعة:';
  static const String labelPricePerKg = 'سعر/كجم';
  static const String labelPricePerGram = 'سعر/جرام';
  static const String labelStock = 'المخزون';
  static const String labelDeferredShort = 'أجل :';
  static const String labelNote = 'ملاحظة';
  static const String labelCalculatedGrams = 'الجرامات المحسوبة';

  static const String btnCheckoutInvoice = 'إتمام الفاتورة';
  static const String btnSellAr = 'بيع';
  static const String btnDone = 'تم';

  static const String cartEmptyAddProductsFirst =
      'السلة فارغة، أضف منتجات أولاً';
  static const String cartEmptyAddProductsToContinue =
      'السلة فارغة، أضف منتجات للمتابعة';
  static const String labelUnavailable = 'غير متاح';
  static const String labelNone = 'بدون';

  // ديناميك – تم إضافة صنف للسلة
  static String snackAddedLineToCart(String name) =>
      'تمت إضافة $name إلى السلة';

  // === نصوص البحث / الـ Hints ===
  static const String hintSearchProduct = 'ابحث عن منتج...';
  static const String hintCustomerNoteOptional = 'ملاحظات/اسم العميل (اختياري)';
  static const String hintDeferredNote =
      '...اكتب ملاحظة بخصوص البيع المؤجل هنا';
  static const String hintExample100 = 'مثال: 100';
  static const String hintExample120 = 'مثال: 120.00';
  static const String hintExample250 = 'مثال: 250';

  static const String noMatchingItems = 'لا توجد عناصر مطابقة';

  // === رسائل تحميل / أخطاء البيانات ===
  static const String errorReadingDrinks = 'تعذر قراءة بيانات المشروبات';
  static const String errorReadingSingles = 'تعذر قراءة بيانات الأصناف';
  static const String errorReadingExtras = 'تعذر قراءة بيانات الإضافات';
  static const String errorReadingItems = 'تعذر قراءة بيانات الأصناف';
  static const String errorLoadingDrinks = 'حدث خطأ أثناء تحميل المشروبات';
  static const String errorLoadingSingles =
      'حدث خطأ أثناء تحميل المحاصيل المفردة';
  static const String errorLoadingBlends = 'حدث خطأ أثناء تحميل خلطات البن';
  static const String errorLoadingReadyBlends = 'حدث خطأ أثناء تحميل التوليفات';
  static const String errorLoadingExtras = 'حدث خطأ أثناء تحميل الإضافات';
  static const String errorLoadingCookies = 'حدث خطأ أثناء تحميل الأصناف';
  static const String errorUnexpected = 'حدث خطأ غير متوقع.';
  static const String errorProductNameMissing = 'اسم المنتج غير موجود.';
  static const String errorItemNameMissing = 'اسم الصنف غير موجود.';
  static const String errorInvalidQuantity = 'الكمية غير صالحة.';
  static const String errorSelectRoast = 'اختر درجة التحميص/النوع أولاً.';
  static const String errorEnterValidGramsOrPrice =
      'من فضلك أدخل كمية صحيحة بالجرام أو السعر.';
  static const String errorEnterValidGrams = 'من فضلك أدخل كمية صحيحة بالجرام.';
  static const String errorEnterValidPrice = 'من فضلك أدخل سعرًا صحيحًا.';
  static const String errorProductNotFound = 'المنتج مش موجود';
  static const String errorQtyUnavailable = 'الكمية غير متاحة في المخزون';
  static const String errorCustomBlendTitleRequired =
      'من فضلك اكتب عنوان التوليفة قبل المتابعة.';

  static const String emptyDrinks = 'لا يوجد مشروبات متاحة';
  static const String emptySingles = 'لا توجد محاصيل مفردة متاحة';
  static const String emptySinglesShort = 'لا يوجد أصناف منفردة';
  static const String emptyBlends = 'لا توجد خلطات متاحة';
  static const String emptyReadyBlends = 'لا يوجد توليفات جاهزة';
  static const String emptyExtras = 'لا توجد إضافات متاحة';
  static const String emptyCookies = 'لا يوجد أصناف (بسكوت/معمول)';
  static const String emptyQuickExtrasEn =
      'No quick extras available right now.';
  static const String noDrinks = 'لا يوجد مشروبات';

  // ديناميك – أخطاء عامة بالإنجليزي
  static String errorLoadingGeneric(String title, Object error) =>
      'Error loading $title: $error';

  static String failedToSellItem(Object error) => 'Failed to sell item: $error';

  static String soldQtyEn(num qty, String itemName) => 'Sold $qty x $itemName';

  static String soldQtyAr(num qty, String itemName) =>
      'تم بيع $qty × $itemName';

  static String stockPiecesEn(num units) => 'المخزون: $units';

  static String stockPiecesAr(num units) => 'المخزون الحالي: $units قطعة';
  static String stockNotEnough(num available, String unitLabel) =>
      'المخزون غير كافٍ: المتاح $available $unitLabel';

  // === نصوص شاشة توليفات العميل / الداخلة في الحاسبة ===
  static const String titleCustomBlends = 'توليفات العميل';
  static const String labelBlendComponents = 'مكوّنات التوليفة';
  static const String labelAddComponent = 'إضافة مكوّن';
  static const String labelBlendComponentName = 'اسم المكوّن';
  static const String labelBlendPrefix = 'توليفة ';
  static const String labelInputByGrams = 'إدخال بالجرامات';
  static const String labelInputByPrice = 'إدخال بالسعر';
  static const String labelBasedOnWeight = 'حسب الوزن';
  static const String labelBasedOnAmount = 'حسب المبلغ';
  static const String labelSingles = 'سنجل';
  static const String labelDouble = 'دوبل';
  static const String labelMilk = 'لبن';
  static const String labelWater = 'مياه';
  static const String labelSpiced = 'محوّج';
  static const String labelPlain = 'سادة';
  static const String labelGinseng = 'جينسنج';
  static const String labelHospitality = 'ضيافة';
  static const String labelPaid = 'مدفوع';
  static const String labelDeferredPast = 'أجل من يوم سابق';
  static const String labelOperation = 'فاتورة';
  static const String labelCustomBlendSingle = 'توليفة العميل';
  static const String labelCustomBlendTitle = 'عنوان التوليفة';
  static const String hintCustomBlendTitle = 'اكتب عنوان التوليفة هنا';
  static const String labelTotalGrams = 'إجمالي الجرامات';
  static const String labelBeansAmount = 'سعر البن';
  static const String labelSpiceAmount = 'سعر التحويج';
  static const String labelGinsengAmount = 'سعر الجينسنغ';

  static const String labelGramsShort = 'جم';
  static const String labelPieceUnit = 'قطعة';

  static String approxCalculatedGrams(num grams) =>
      '≈ الجرامات المحسوبة: ${grams.toString()} جم';

  static String calculatedGramsLine(num grams) =>
      'الجرامات المحسوبة: $grams جم';

  // === Toasts / رسائل صغيرة في شاشة التوليفات ===
  static const String toastNoBlendComponents = '— لا توجد تفاصيل مكونات —';

  // === شاشة سجل البيع ===
  static const String titleSalesHistory = 'سجلّ المبيعات';
  static const String titleSalesHistorySimple = 'سجل المبيعات';
  static const String labelSales = 'مبيعات';
  static const String labelNoSales = 'لا يوجد عمليات بيع';
  static const String labelNoSalesInRange = 'لا يوجد عمليات في هذا النطاق';
  static const String titleCreditAccounts = 'حسابات مؤجلة';
  static const String labelNoCreditAccounts = 'لا توجد حسابات مؤجلة بعد.';
  static const String labelNoCreditSalesForCustomer =
      'لا توجد مبيعات مؤجلة لهذا العميل.';
  static const String labelTotalOwed = 'المبلغ المستحق';
  static const String labelUnpaid = 'غير مدفوع';
  static const String labelSaleDate = 'تاريخ البيع';
  static const String labelPaidAt = 'مدفوع في';
  static const String labelAmountDue = 'المبلغ المستحق';
  static const String btnPaySale = 'دفع المبلغ';
  static const String btnPayAmount = 'دفع جزء من المستحق';
  static const String dialogPayAmountTitle = 'دفع المبلغ';
  static const String errorEnterValidAmount = 'أدخل مبلغًا صحيحًا.';
  static const String creditPaymentExceedsTotal =
      'المبلغ أكبر من الإجمالي المستحق؛ سيتم خصم المتبقي فقط.';
  static const String labelPartialPayments = 'دفعات جزئية';
  static String partialPaymentLine(num amount, String when) =>
      'سداد جزئي: ${amount.toStringAsFixed(2)} - $when';
  static const String dialogDeleteCreditAccountTitle = 'حذف حساب الأجل';
  static String confirmDeleteCreditAccount(String name) =>
      'سيتم حذف حساب $name وكل عمليات الأجل الخاصة به. هل تريد المتابعة؟';
  static const String creditAccountDeleted = 'تم حذف حساب الأجل.';
  static String creditDeleteFailed(Object error) =>
      'تعذر حذف حساب الأجل: $error';

  static String salesAmount(num value) => 'مبيعات: ${value.toStringAsFixed(2)}';

  static String historyLoadError(Object error) => 'خطأ في تحميل السجل: $error';

  static String originalDateLabel(String text) => 'التاريخ الأصلي: $text';

  // === نصوص تفاصيل السجل / البند ===
  static const String labelInvoice = 'فاتورة';
  static const String labelInvoiceItemsCountSuffix = 'بند';
  static const String labelDrink = 'مشروب';
  static const String labelReadyBlend = 'توليفة جاهزة';
  static const String labelSingleItem = 'صنف منفرد';
  static const String labelExtra = 'سناكس';
  static const String labelGramsUnit = 'جم';
  static const String labelCupUnit = 'كوب';
  static const String labelPieceUnitEn = 'قطعة';

  static String priceLine(num value) => 'س:${value.toStringAsFixed(2)}';
  static String saleTitleDrink(String quantity, String name) =>
      '${AppStrings.labelDrink} - $quantity $name';
  static String saleTitleInvoice(int count, String amount) =>
      '${AppStrings.labelInvoice} - $count ${AppStrings.labelInvoiceItemsCountSuffix} - $amount';
  static String saleTitleInvoiceNumber(int number) =>
      '${AppStrings.labelOperation} $number';
  static String saleTitleSingle(String grams, String label) =>
      '${AppStrings.labelSingleItem} - $grams ${AppStrings.labelGramsUnit} ${label.isNotEmpty ? label : ''}'
          .trim();
  static String saleTitleReadyBlend(String grams, String label) =>
      '${AppStrings.labelReadyBlend} - $grams ${AppStrings.labelGramsUnit} ${label.isNotEmpty ? label : ''}'
          .trim();
  static String saleTitleCustomBlend() => AppStrings.labelCustomBlendSingle;
  static String saleTitleExtra(String quantity, String unit, String name) =>
      '${AppStrings.labelExtra} - $quantity $unit $name';

  // === Tooltips ===
  static const String tooltipBack = 'رجوع';
  static const String tooltipRefresh = 'تحديث';
  static const String tooltipDelete = 'حذف';
  static const String tooltipFilterByDate = 'تصفية بالتاريخ';
  static const String tooltipClearFilter = 'مسح الفلتر';

  static const String labelSellQuickEn = 'Sell';

  // === Misc / helpers ===
  static const String currencyEgpLetter = 'ج.م';

  // إضافات مطلوبة بعد refactor features

  static const String titlePrepareCustomBlend = 'تحضير خلطة مخصصة';
  static const String descMixCoffeeAsYouLike =
      'اخلط البن كما تحب من المكونات المتاحة';

  static String variantsCount(int count) => 'الأنواع: $count';

  static const String btnDefer = 'أجِّل';

  static const String roastDark = 'غامق';
  static const String roastLight = 'فاتح';
  static const String roastMedium = 'وسط';

  static const String errorStockNotEnoughSimple = 'المخزون غير كافٍ';

  static const String labelQuantityPieces = 'الكمية (قطع)';
  // ignore: unused_field
  static const List<String> _arabicKeys = [
    'ض',
    'ص',
    'ث',
    'ق',
    'ف',
    'غ',
    'ع',
    'ه',
    'خ',
    'ح',
    'ج',
    'د',
    'ش',
    'س',
    'ي',
    'ب',
    'ل',
    'ا',
    'ت',
    'ن',
    'م',
    'ك',
    'ط',
    'ئ',
    'ء',
    'ؤ',
    'ر',
    'لا',
    'ى',
    'ة',
    'و',
    'ز',
    'ظ',
    'أ',
    'إ',
    'آ',
    '،',
    '؟',
  ];
}
