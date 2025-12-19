// lib/Presentation/features/cashier_page/view/custom_blends_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/deferred_note_field.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

part 'custom_blends_widgets.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

/// مصدر الصنف (Singles أو Blends)
enum ItemSource { singles, blends }

/// ====== موديل صنف (منفرد أو توليفة جاهزة) موحد ======
class SingleVariantItem {
  final String id;
  final ItemSource source;
  final String name;
  final String variant; // قد تكون ""
  final String image;
  final double sellPricePerKg;
  final double costPricePerKg;
  final double stock; // جرام
  final String unit; // "g"

  // التحويج من الداتابيز
  final double spicesPricePerKg; // سعر التحويج/كجم
  final double spicesCostPerKg; // تكلفة التحويج/كجم
  final bool supportsSpice; // يدعم التحويج؟

  String get fullLabel => variant.isNotEmpty ? '$name - $variant' : name;
  double get sellPerG => sellPricePerKg / 1000.0;
  double get costPerG => costPricePerKg / 1000.0;

  SingleVariantItem({
    required this.id,
    required this.source,
    required this.name,
    required this.variant,
    required this.image,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.stock,
    required this.unit,
    required this.spicesPricePerKg,
    required this.spicesCostPerKg,
    required this.supportsSpice,
  });

  static double _readNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  static bool _readBool(dynamic v) => v == true;

  factory SingleVariantItem.fromSinglesDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? {};
    return SingleVariantItem(
      id: d.id,
      source: ItemSource.singles,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      image: (m['image'] ?? 'assets/singles.jpg').toString(),
      sellPricePerKg: _readNum(m['sellPricePerKg']),
      costPricePerKg: _readNum(m['costPricePerKg']),
      stock: _readNum(m['stock']),
      unit: (m['unit'] ?? 'g').toString(),
      spicesPricePerKg: _readNum(m['spicesPrice']),
      spicesCostPerKg: _readNum(m['spicesCost']),
      supportsSpice:
          _readBool(m['supportsSpice']) ||
          _readNum(m['spicesPrice']) > 0 ||
          _readNum(m['spicesCost']) > 0,
    );
  }

  factory SingleVariantItem.fromBlendsDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? {};
    return SingleVariantItem(
      id: d.id,
      source: ItemSource.blends,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      image: (m['image'] ?? 'assets/blends.jpg').toString(),
      sellPricePerKg: _readNum(m['sellPricePerKg']),
      costPricePerKg: _readNum(m['costPricePerKg']),
      stock: _readNum(m['stock']),
      unit: (m['unit'] ?? 'g').toString(),
      spicesPricePerKg: _readNum(m['spicesPrice']),
      spicesCostPerKg: _readNum(m['spicesCost']),
      supportsSpice:
          _readBool(m['supportsSpice']) ||
          _readNum(m['spicesPrice']) > 0 ||
          _readNum(m['spicesCost']) > 0,
    );
  }
}

enum LineInputMode { grams, price }

/// ====== سطر داخل توليفة العميل ======
class _BlendLine {
  SingleVariantItem? item;
  LineInputMode mode = LineInputMode.grams;

  int grams = 0; // إدخال بالجرامات
  double price = 0.0; // إدخال بالسعر (بن فقط)

  int get gramsEffective {
    if (item == null) return 0;
    if (mode == LineInputMode.grams) return grams;
    final perG = item!.sellPerG;
    if (perG <= 0) return 0;
    return (price / perG).floor().clamp(0, 1000000);
    // السعر هنا يعتبر "بن" فقط بدون تحويج إضافي
  }

  double get linePrice {
    if (item == null) return 0.0;
    return item!.sellPerG * gramsEffective;
  }

  double get lineCost {
    if (item == null) return 0.0;
    return item!.costPerG * gramsEffective;
  }
}

class CustomBlendsPage extends StatefulWidget {
  const CustomBlendsPage({
    super.key,
    this.cartMode = false,
    this.onAddToCart,
    this.initialBlend,
  });
  static const String route = '/custom-blends';

  final bool cartMode;
  final ValueChanged<CartLine>? onAddToCart;
  final Map<String, dynamic>? initialBlend;

  @override
  State<CustomBlendsPage> createState() => _CustomBlendsPageState();
}

enum _PadTargetType { none, lineGrams, linePrice }

class _CustomBlendsPageState extends State<CustomBlendsPage> {
  bool _busy = false;
  String? _fatal;
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  List<SingleVariantItem> _allItems = []; // Singles + Blends (محددة)
  final List<_BlendLine> _lines = [_BlendLine()];
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  bool _templateApplied = false;

  bool _isComplimentary = false; // ضيافة
  bool _isDeferred = false; // أجِّل
  bool _isSpiced = false; // التحويج على إجمالي التوليفة

  // جينسنج (على إجمالي الجرامات)
  int _ginsengGrams = 0;
  static const double _ginsengPricePerG = 5.0;
  static const double _ginsengCostPerG = 4.0;

  // إجماليات
  double get _sumPriceLines =>
      _lines.fold<double>(0, (s, l) => s + l.linePrice);
  int get _sumGrams => _lines.fold<int>(0, (s, l) => s + l.gramsEffective);

  // هل أي مكوّن يدعم التحويج؟
  bool get _canSpiceAny {
    for (final l in _lines) {
      final it = l.item;
      if (it != null && it.supportsSpice) return true;
    }
    return false;
  }

  // التحويج من الداتابيز — نجمع حسب كل مكوّن
  double get _spiceAmount {
    if (!_isSpiced) return 0.0;
    double sum = 0.0;
    for (final l in _lines) {
      final it = l.item;
      if (it == null || !it.supportsSpice) continue;
      sum += (l.gramsEffective / 1000.0) * it.spicesPricePerKg;
    }
    return sum;
  }

  double get _spiceCostAmount {
    if (!_isSpiced) return 0.0;
    double sum = 0.0;
    for (final l in _lines) {
      final it = l.item;
      if (it == null || !it.supportsSpice) continue;
      sum += (l.gramsEffective / 1000.0) * it.spicesCostPerKg;
    }
    return sum;
  }

  // متوسط سعر/كجم تحويج فعلي (للتخزين كملخص)
  double get _effectiveSpiceRatePerKg {
    final gKg = _sumGrams / 1000.0;
    if (!_isSpiced || gKg <= 0) return 0.0;
    return _spiceAmount / gKg;
  }

  double get _effectiveSpiceCostPerKg {
    final gKg = _sumGrams / 1000.0;
    if (!_isSpiced || gKg <= 0) return 0.0;
    return _spiceCostAmount / gKg;
  }

  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  double get _totalPriceWould =>
      _sumPriceLines + _spiceAmount + _ginsengPriceAmount;

  // قيمة واجهة المستخدم (العرض على الشاشة)
  // صفر فقط في حالة الضيافة
  double get _uiTotal => _isComplimentary ? 0.0 : _totalPriceWould;

  // ===== نومباد داخلي للصفحة كلها =====
  bool _showPad = false;
  _PadTargetType _padType = _PadTargetType.none;
  int _padLineIndex = -1;
  String _padBuffer = '';

  void _openPadForLine(int lineIndex, _PadTargetType type) {
    if (_busy) return;
    FocusScope.of(context).unfocus(); // اقفل كيبورد النظام
    _padLineIndex = lineIndex;
    _padType = type;

    final line = _lines[_padLineIndex];
    if (_padType == _PadTargetType.lineGrams) {
      _padBuffer = line.grams > 0 ? '${line.grams}' : '';
    } else if (_padType == _PadTargetType.linePrice) {
      _padBuffer = line.price > 0 ? line.price.toStringAsFixed(2) : '';
    } else {
      _padBuffer = '';
    }

    setState(() => _showPad = true);
  }

  void _closePad() {
    setState(() {
      _showPad = false;
      _padType = _PadTargetType.none;
      _padLineIndex = -1;
      _padBuffer = '';
    });
  }

  void _applyPadKey(String k) {
    if (_padLineIndex < 0 || _padLineIndex >= _lines.length) return;
    final line = _lines[_padLineIndex];

    if (k == 'back') {
      if (_padBuffer.isNotEmpty) {
        _padBuffer = _padBuffer.substring(0, _padBuffer.length - 1);
      }
    } else if (k == 'clear') {
      _padBuffer = '';
    } else if (k == 'dot') {
      // نقطة مسموحة في "السعر" فقط
      if (_padType == _PadTargetType.linePrice && !_padBuffer.contains('.')) {
        _padBuffer = _padBuffer.isEmpty ? '0.' : '$_padBuffer.';
      }
    } else if (k == 'done') {
      _closePad();
      return;
    } else {
      // أرقام
      _padBuffer += k;
    }

    // طبّق القيمة على السطر مباشرة (عرض حيّ)
    if (_padType == _PadTargetType.lineGrams) {
      final v = int.tryParse(_padBuffer.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      line.grams = v.clamp(0, 1000000);
    } else if (_padType == _PadTargetType.linePrice) {
      final cleaned = _padBuffer
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      final v = double.tryParse(cleaned) ?? 0.0;
      line.price = v.clamp(0, 1000000).toDouble();
    }

    setState(() {});
  }

  Widget _numPad({required bool allowDot}) {
    final keys = <String>[
      '3',
      '2',
      '1',
      '6',
      '5',
      '4',
      '9',
      '8',
      '7',
      allowDot ? 'dot' : 'clear',
      '0',
      'back',
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final btnW = (maxW - (3 * 8) - (2 * 12)) / 3;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.brown.shade100),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keys.map((k) {
                  IconData? icon;
                  String label = k;
                  VoidCallback onTap;

                  switch (k) {
                    case 'back':
                      icon = Icons.backspace_outlined;
                      label = '';
                      onTap = () => _applyPadKey('back');
                      break;
                    case 'clear':
                      icon = Icons.clear;
                      label = '';
                      onTap = () => _applyPadKey('clear');
                      break;
                    case 'dot':
                      label = '.';
                      onTap = () => _applyPadKey('dot');
                      break;
                    default:
                      onTap = () => _applyPadKey(k);
                  }

                  return SizedBox(
                    width: btnW,
                    height: 52,
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : onTap,
                      child: icon != null
                          ? Icon(icon)
                          : Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      const Color(0xFF543824),
                    ),
                  ),
                  onPressed: _busy ? null : () => _applyPadKey('done'),
                  child: const Text(
                    AppStrings.btnDone,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// تحميل العناصر المنفردة + بعض التوليفات الجاهزة بأسمائها المحددة
  Future<void> _loadItems() async {
    try {
      final db = FirebaseFirestore.instance;

      // singles
      final singlesSnap = await db.collection('singles').orderBy('name').get();
      final singles = singlesSnap.docs
          .map(SingleVariantItem.fromSinglesDoc)
          .toList();

      // blends (محددة بالأسماء + كل درجات التحميص)
      const allowedBlendNames = {
        'توليفة كلاسيك',
        'توليفة مخصوص',
        'توليفة اسبيشيال',
        'توليفة الفؤاد',
        'توليفة القهاوى',
      };

      final blendsSnap = await db
          .collection('blends')
          .where('name', whereIn: allowedBlendNames.toList())
          .get();
      final blends = blendsSnap.docs
          .map(SingleVariantItem.fromBlendsDoc)
          .toList();

      final all = <SingleVariantItem>[...singles, ...blends];

      // ترتيب: المتاح أولاً
      all.sort((a, b) {
        final az = a.stock <= 0 ? 1 : 0;
        final bz = b.stock <= 0 ? 1 : 0;
        if (az != bz) return az.compareTo(bz);
        return a.fullLabel.compareTo(b.fullLabel);
      });

      if (!mounted) return;
      setState(() {
        _allItems = all;
      });
      _applyInitialBlendIfPossible();
    } catch (e) {
      setState(() => _fatal = 'تعذر تحميل الأصناف.');
    }
  }

  double _readDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  int _readInt(dynamic v) {
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) return v.round().clamp(0, 1000000);
    final parsed = int.tryParse(v?.toString() ?? '');
    if (parsed == null) return 0;
    return parsed < 0 ? 0 : parsed;
  }

  bool _readBool(dynamic v) => v == true;

  SingleVariantItem? _findItem(String id, ItemSource source) {
    for (final it in _allItems) {
      if (it.id == id && it.source == source) return it;
    }
    return null;
  }

  bool _deriveSpicedFromComponents(dynamic components) {
    if (components is! List) return false;
    for (final raw in components) {
      if (raw is! Map) continue;
      final rate = _readDouble(raw['spice_rate_per_kg']);
      final cost = _readDouble(raw['spice_cost_per_kg']);
      if (rate > 0 || cost > 0) return true;
    }
    return false;
  }

  void _applyInitialBlendIfPossible() {
    if (_templateApplied || widget.initialBlend == null || _allItems.isEmpty) {
      return;
    }
    final data = widget.initialBlend!;
    final components = data['components'];

    final newLines = <_BlendLine>[];
    if (components is List) {
      for (final raw in components) {
        if (raw is! Map) continue;
        final id = (raw['item_id'] ?? '').toString();
        if (id.isEmpty) continue;
        final sourceRaw = (raw['source'] ?? '').toString();
        final source = sourceRaw == 'singles'
            ? ItemSource.singles
            : sourceRaw == 'blends'
                ? ItemSource.blends
                : null;
        if (source == null) continue;
        final item = _findItem(id, source);
        if (item == null) continue;
        final grams = _readInt(raw['grams']);
        if (grams <= 0) continue;
        final line = _BlendLine()
          ..item = item
          ..mode = LineInputMode.grams
          ..grams = grams;
        newLines.add(line);
      }
    }

    final title =
        (data['title'] ?? data['custom_title'] ?? '').toString().trim();
    final isComplimentary = _readBool(data['is_complimentary']);
    final isDeferred = _readBool(data['is_deferred']);
    final isSpiced = _readBool(data['spiced']) ||
        _deriveSpicedFromComponents(components);
    final ginsengGrams = _readInt(data['ginseng_grams']);
    final canSpice = newLines.any((l) => l.item?.supportsSpice == true);

    if (newLines.isEmpty) newLines.add(_BlendLine());

    setState(() {
      _lines
        ..clear()
        ..addAll(newLines);
      if (title.isNotEmpty) {
        _titleCtrl.text = title;
      }
      _isComplimentary = isComplimentary;
      _isDeferred = isComplimentary ? false : isDeferred;
      _isSpiced = isSpiced && canSpice;
      _ginsengGrams = ginsengGrams;
      if (_isComplimentary) {
        _noteCtrl.clear();
      }
      _templateApplied = true;
    });
  }

  bool get _hasInvalidLine {
    for (final l in _lines) {
      if (l.item == null) return true;
      if (l.gramsEffective <= 0) return true;
    }
    return false;
  }

  CartLine _buildCartLine() {
    if (_allItems.isEmpty) {
      throw UserFriendly('لم يتم تحميل الأصناف بعد.');
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      throw UserFriendly('من فضلك اختر الأصناف وأدخل الكميات.');
    }
    final customTitle = _titleCtrl.text.trim();
    if (customTitle.isEmpty) {
      throw UserFriendly(AppStrings.errorCustomBlendTitleRequired);
    }

    final Map<String, int> gramsBySinglesId = {};
    final Map<String, int> gramsByBlendsId = {};
    for (final l in _lines) {
      final it = l.item!;
      final g = l.gramsEffective;
      if (it.source == ItemSource.singles) {
        gramsBySinglesId[it.id] = (gramsBySinglesId[it.id] ?? 0) + g;
      } else {
        gramsByBlendsId[it.id] = (gramsByBlendsId[it.id] ?? 0) + g;
      }
    }

    final isComp = _isComplimentary;
    final isDef = _isDeferred && !isComp;
    final totalPriceWould = isComp ? 0.0 : _totalPriceWould;
    final totalBeansCost = _lines.fold<double>(
      0.0,
      (s, l) => s + (l.item!.costPerG * l.gramsEffective),
    );
    final totalSpiceCost = _spiceCostAmount;
    final totalCost = totalBeansCost + totalSpiceCost + _ginsengCostAmount;
    final gramsTotal = _sumGrams.toDouble();

    final components = _lines.map((l) {
      final it = l.item!;
      final g = l.gramsEffective.toDouble();
      final pricePerGOut = isComp ? 0.0 : it.sellPerG;
      final compSpiceRate = (isComp || !_isSpiced || !it.supportsSpice)
          ? 0.0
          : it.spicesPricePerKg;
      final compSpiceCostRate = (isComp || !_isSpiced || !it.supportsSpice)
          ? 0.0
          : it.spicesCostPerKg;

      return {
        'item_id': it.id,
        'source': it.source == ItemSource.singles ? 'singles' : 'blends',
        'name': it.name,
        'variant': it.variant,
        'unit': 'g',
        'grams': g,
        'price_per_kg': it.sellPricePerKg,
        'price_per_g': pricePerGOut,
        'line_total_price': pricePerGOut * g,
        'cost_per_kg': it.costPricePerKg,
        'cost_per_g': it.costPerG,
        'line_total_cost': it.costPerG * g,
        'spice_rate_per_kg': compSpiceRate,
        'spice_cost_per_kg': compSpiceCostRate,
      };
    }).toList();

    final impacts = <StockImpact>[
      for (final entry in gramsBySinglesId.entries)
        StockImpact(
          collection: 'singles',
          docId: entry.key,
          field: 'stock',
          amount: entry.value.toDouble(),
        ),
      for (final entry in gramsByBlendsId.entries)
        StockImpact(
          collection: 'blends',
          docId: entry.key,
          field: 'stock',
          amount: entry.value.toDouble(),
        ),
    ];

    final meta = <String, dynamic>{
      'components': components,
      'custom_title': customTitle,
      'spiced': _isSpiced && _canSpiceAny,
      'ginseng_grams': _ginsengGrams,
      'ginseng_price_per_g': _ginsengPricePerG,
      'ginseng_cost_per_g': _ginsengCostPerG,
      'spice_rate_per_kg': _effectiveSpiceRatePerKg,
      'spice_cost_per_kg': _effectiveSpiceCostPerKg,
      'spice_amount': isComp ? 0.0 : _spiceAmount,
      'ginseng_price_amount': isComp ? 0.0 : _ginsengPriceAmount,
      'ginseng_cost_amount': _ginsengCostAmount,
    };

    return CartLine(
      id: CartLine.newId(),
      productId: 'custom_blend',
      name: 'خلطة مخصصة',
      variant: customTitle,
      type: 'custom_blend',
      unit: 'g',
      image: 'assets/custom.jpg',
      quantity: 0,
      grams: gramsTotal,
      unitPrice: gramsTotal > 0 ? (totalPriceWould / gramsTotal) : 0.0,
      unitCost: gramsTotal > 0 ? (totalCost / gramsTotal) : 0.0,
      lineTotalPrice: totalPriceWould,
      lineTotalCost: totalCost,
      isComplimentary: isComp,
      isDeferred: isDef,
      note: isDef ? _noteCtrl.text.trim() : '',
      meta: meta,
      impacts: impacts,
    );
  }

  Future<void> _commitSale() async {
    if (_allItems.isEmpty) {
      setState(() => _fatal = 'لم يتم تحميل الأصناف بعد.');
      return;
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      setState(() => _fatal = 'من فضلك اختر الأصناف وأدخل الكميات.');
      return;
    }

    if (widget.cartMode || widget.onAddToCart != null) {
      setState(() {
        _busy = true;
        _fatal = null;
      });
      try {
        final line = _buildCartLine();
        widget.onAddToCart?.call(line);
        if (!mounted) return;
        Navigator.pop(context, line);
      } catch (e) {
        final msg = e is UserFriendly
            ? e.message
            : (e is FirebaseException
                  ? 'خطأ في البيانات (${e.code})'
                  : 'حدث خطأ غير متوقع.');
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(AppStrings.dialogBlendAddFailed),
            content: SingleChildScrollView(child: Text(msg)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.dialogOk),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final customTitle = _titleCtrl.text.trim();
    if (customTitle.isEmpty) {
      setState(() => _fatal = AppStrings.errorCustomBlendTitleRequired);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    final db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((txn) async {
        final Map<String, int> gramsBySinglesId = {};
        final Map<String, int> gramsByBlendsId = {};
        final Map<String, double> currentStockSingles = {};
        final Map<String, double> currentStockBlends = {};

        // تجميع احتياجات الجرامات حسب المصدر
        for (final l in _lines) {
          final it = l.item!;
          final g = l.gramsEffective;
          if (it.source == ItemSource.singles) {
            gramsBySinglesId[it.id] = (gramsBySinglesId[it.id] ?? 0) + g;
          } else {
            gramsByBlendsId[it.id] = (gramsByBlendsId[it.id] ?? 0) + g;
          }
        }

        // تحقق المخزون: singles
        for (final entry in gramsBySinglesId.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final ref = db.collection('singles').doc(id);
          final snap = await txn.get(ref);
          if (!snap.exists) {
            throw UserFriendly('صنف منفرد غير موجود (docId=$id).');
          }
          final data = snap.data() as Map<String, dynamic>;
          final cur = (data['stock'] is num)
              ? (data['stock'] as num).toDouble()
              : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;
          if (cur < need) {
            final nm = (data['name'] ?? '').toString();
            final vr = (data['variant'] ?? '').toString();
            final label = vr.isNotEmpty ? '$nm - $vr' : nm;
            throw UserFriendly(
              'AppStrings.stockNotEnough لـ "$label".\nالمتاح: ${cur.toStringAsFixed(0)} جم • المطلوب: ${need.toStringAsFixed(0)} جم',
            );
          }
          currentStockSingles[id] = cur;
        }

        // تحقق المخزون: blends
        for (final entry in gramsByBlendsId.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final ref = db.collection('blends').doc(id);
          final snap = await txn.get(ref);
          if (!snap.exists) {
            throw UserFriendly('توليفة غير موجودة (docId=$id).');
          }
          final data = snap.data() as Map<String, dynamic>;
          final cur = (data['stock'] is num)
              ? (data['stock'] as num).toDouble()
              : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;
          if (cur < need) {
            final nm = (data['name'] ?? '').toString();
            final vr = (data['variant'] ?? '').toString();
            final label = vr.isNotEmpty ? '$nm - $vr' : nm;
            throw UserFriendly(
              'AppStrings.stockNotEnough لـ "$label".\nالمتاح: ${cur.toStringAsFixed(0)} جم • المطلوب: ${need.toStringAsFixed(0)} جم',
            );
          }
          currentStockBlends[id] = cur;
        }

        // خصم المخزون
        for (final entry in gramsBySinglesId.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final cur = currentStockSingles[id]!;
          final ref = db.collection('singles').doc(id);
          txn.update(ref, {'stock': cur - need});
        }
        for (final entry in gramsByBlendsId.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final cur = currentStockBlends[id]!;
          final ref = db.collection('blends').doc(id);
          txn.update(ref, {'stock': cur - need});
        }

        final isComp = _isComplimentary;
        final isDef = _isDeferred && !isComp; // لا تؤجَّل الضيافة

        // السعر الحقيقي (دائمًا نحفظه كما هو — الأجل ما يصفّروش)
        final double totalPriceWould = isComp ? 0.0 : _totalPriceWould;

        // التكلفة (بن + تحويج + جينسنج)
        final double totalBeansCost = _lines.fold<double>(
          0.0,
          (s, l) => s + (l.item!.costPerG * l.gramsEffective),
        );
        final double totalSpiceCost = _spiceCostAmount; // من الداتابيز
        final double totalCost =
            totalBeansCost + totalSpiceCost + _ginsengCostAmount;

        // الربح الظاهر: صفر لو ضيافة أو أجل غير مدفوع
        final double profitOut = (isComp || isDef)
            ? 0.0
            : (totalPriceWould - totalCost);

        // مكونات الفاتورة
        final components = _lines.map((l) {
          final it = l.item!;
          final g = l.gramsEffective.toDouble();
          final pricePerGOut = isComp ? 0.0 : it.sellPerG;
          // معدلات التحويج الخاصة بالمكوّن
          final compSpiceRate = (isComp || !_isSpiced || !it.supportsSpice)
              ? 0.0
              : it.spicesPricePerKg;
          final compSpiceCostRate = (isComp || !_isSpiced || !it.supportsSpice)
              ? 0.0
              : it.spicesCostPerKg;

          return {
            'item_id': it.id,
            'source': it.source == ItemSource.singles ? 'singles' : 'blends',
            'name': it.name,
            'variant': it.variant,
            'unit': 'g',
            'grams': g,
            'price_per_kg': it.sellPricePerKg,
            'price_per_g': pricePerGOut,
            'line_total_price': pricePerGOut * g,
            'cost_per_kg': it.costPricePerKg,
            'cost_per_g': it.costPerG,
            'line_total_cost': it.costPerG * g,
            // معلومات تحويج لكل مكوّن (اختياري لكنها مفيدة)
            'spice_rate_per_kg': compSpiceRate,
            'spice_cost_per_kg': compSpiceCostRate,
          };
        }).toList();

        final note = isDef ? _noteCtrl.text.trim() : '';
        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': FieldValue.serverTimestamp(),
          'created_by': 'cashier_web',
          'type': 'custom_blend',
          'custom_title': customTitle,

          // حالات
          'is_complimentary': isComp,
          'is_deferred': isDef,
          'due_amount': isDef ? totalPriceWould : 0.0,
          'paid': !isDef,
          'note': note,

          // ملخص
          'lines_amount': _sumPriceLines,
          'is_spiced': _isSpiced && _canSpiceAny,
          // المتوسطات الفعلية على إجمالي الوزن
          'spice_rate_per_kg': _effectiveSpiceRatePerKg,
          'spice_amount': isComp ? 0.0 : _spiceAmount,
          'spice_cost_per_kg': _effectiveSpiceCostPerKg,
          'spice_cost_amount': _spiceCostAmount,

          // جينسنج
          'ginseng_grams': _ginsengGrams,
          'ginseng_price_per_g': _ginsengPricePerG,
          'ginseng_cost_per_g': _ginsengCostPerG,
          'ginseng_price_amount': isComp ? 0.0 : _ginsengPriceAmount,
          'ginseng_cost_amount': _ginsengCostAmount,

          'total_grams': _sumGrams.toDouble(),

          'total_price': totalPriceWould, // ✅ لا نصفر في الأجل
          'total_cost': totalCost,
          'profit_total': profitOut,
          'profit_expected': (totalPriceWould - totalCost),

          'components': components,
        });

        final blendRef = db.collection('custom_blends').doc();
        txn.set(blendRef, {
          'title': customTitle,
          'created_at': FieldValue.serverTimestamp(),
          'components': components,
          'total_grams': _sumGrams.toDouble(),
          'total_price': totalPriceWould,
          'spiced': _isSpiced && _canSpiceAny,
          'ginseng_grams': _ginsengGrams,
          'is_complimentary': isComp,
          'is_deferred': isDef,
          'sale_id': saleRef.id,
        });
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      final msg = e is UserFriendly
          ? e.message
          : (e is FirebaseException
                ? 'خطأ في قاعدة البيانات (${e.code})'
                : 'حدث خطأ غير متوقع.');
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(AppStrings.dialogUnableToCompleteOperation),
          content: SingleChildScrollView(child: Text(msg)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.dialogOk),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitInstantInvoice() async {
    if (!_canQuickConfirm || _busy) return;
    if (_allItems.isEmpty) {
      setState(() => _fatal = '?? ??? ????? ??????? ???.');
      return;
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      setState(() => _fatal = '?? ???? ???? ??????? ????? ???????.');
      return;
    }
    final customTitle = _titleCtrl.text.trim();
    if (customTitle.isEmpty) {
      setState(() => _fatal = AppStrings.errorCustomBlendTitleRequired);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });
    try {
      final line = _buildCartLine();
      final tempCart = CartState();
      tempCart.addLine(line);
      if (line.isComplimentary) {
        tempCart.setInvoiceComplimentary(true);
      }
      await CartCheckout.commitInvoice(cart: tempCart);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context, line);
      messenger?.showSnackBar(
        const SnackBar(content: Text(AppStrings.dialogInvoiceCreated)),
      );
    } catch (e, st) {
      logError(e, st);
      if (mounted) await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // تنافي ضيافة وأجِّل
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) {
        _isDeferred = false;
        _noteCtrl.clear();
      }
    });
  }

  void _setDeferred(bool v) {
    setState(() {
      _isDeferred = v;
      if (v) {
        _isComplimentary = false;
      } else {
        _noteCtrl.clear();
      }
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = ResponsiveValue<double>(
      context,
      defaultValue: 28,
      conditionalValues: const [
        Condition.smallerThan(name: TABLET, value: 22),
        Condition.between(
          start: AppBreakpoints.tabletStart,
          end: AppBreakpoints.tabletEnd,
          value: 26,
        ),
        Condition.largerThan(name: DESKTOP, value: 32),
      ],
    ).value;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.only(bottom: 12),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.maybePop(context),
                tooltip: AppStrings.tooltipBack,
              ),
              title: Text(
                AppStrings.titleCustomBlends,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: titleSize,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _allItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, c) {
                  final maxWidth = c.maxWidth;
                  final isWide = AppBreakpoints.isDesktop(maxWidth);
                  final horizontalPadding = maxWidth < 600 ? 12.0 : 16.0;
                  final composer = SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      90,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              AppStrings.labelBlendComponents,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFF543824),
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _lines.add(_BlendLine()),
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text(AppStrings.labelAddComponent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._lines.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final line = entry.value;
                          return Padding(
                            key: ValueKey('line_$idx'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LineCard(
                              items: _allItems,
                              line: line,
                              onChanged: () => setState(() {}),
                              onRemove: _lines.length == 1 || _busy
                                  ? null
                                  : () => setState(() {
                                      if (_showPad && _padLineIndex == idx) {
                                        _closePad();
                                      }
                                      _lines.removeAt(idx);
                                    }),
                              onTapGrams: () => _openPadForLine(
                                idx,
                                _PadTargetType.lineGrams,
                              ),
                              onTapPrice: () => _openPadForLine(
                                idx,
                                _PadTargetType.linePrice,
                              ),
                            ),
                          );
                        }),
                        if (_fatal != null) ...[
                          const SizedBox(height: 8),
                          _WarningBox(text: _fatal!),
                        ],
                        // نومباد داخلي أسفل القائمة
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: _showPad
                              ? _numPad(
                                  allowDot:
                                      _padType == _PadTargetType.linePrice,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );

                  final totals = Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      80,
                    ),
                    child: _TotalsCard(
                      isComplimentary: _isComplimentary,
                      onComplimentaryChanged: _busy
                          ? null
                          : (v) => _setComplimentary(v ?? false),
                      isDeferred: _isDeferred,
                      onDeferredChanged: _busy
                          ? null
                          : (v) => _setDeferred(v ?? false),
                      isSpiced: _isSpiced && _canSpiceAny,
                      onSpicedChanged: _busy || !_canSpiceAny
                          ? null
                          : (v) => setState(() => _isSpiced = v ?? false),
                      titleController: _titleCtrl,
                      titleEnabled: !_busy,
                      ginsengGrams: _ginsengGrams,
                      onGinsengMinus: _busy
                          ? null
                          : () => setState(() {
                              _ginsengGrams = (_ginsengGrams > 0)
                                  ? _ginsengGrams - 1
                                  : 0;
                            }),
                      onGinsengPlus: _busy
                          ? null
                          : () => setState(() => _ginsengGrams += 1),
                      totalGrams: _sumGrams,
                      beansAmount: _sumPriceLines,
                      spiceAmount: _isComplimentary ? 0.0 : _spiceAmount,
                      ginsengAmount: _isComplimentary
                          ? 0.0
                          : _ginsengPriceAmount,
                      totalPrice: _uiTotal,
                      noteController: _noteCtrl,
                      noteVisible: _isDeferred,
                      noteEnabled: !_busy,
                    ),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: composer),
                        SizedBox(width: 360, child: totals),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                      child: Column(
                        children: [
                          composer,
                          const SizedBox(height: 12),
                          totals,
                        ],
                      ),
                    );
                  }
                },
              ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black12),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    child: const Text(
                      AppStrings.dialogCancel,
                      style: TextStyle(color: Color(0xFF543824)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(0xFF543824),
                      ),
                    ),
                    onPressed: _busy ? null : _commitSale,
                    onLongPress:
                        _busy || !_canQuickConfirm ? null : _commitInstantInvoice,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text(AppStrings.dialogConfirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
