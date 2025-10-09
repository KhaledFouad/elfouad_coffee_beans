// lib/Presentation/features/cashier_page/view/custom_blends_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:flutter/material.dart';

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
  const CustomBlendsPage({super.key});
  static const String route = '/custom-blends';

  @override
  State<CustomBlendsPage> createState() => _CustomBlendsPageState();
}

enum _PadTargetType { none, lineGrams, linePrice }

class _CustomBlendsPageState extends State<CustomBlendsPage> {
  bool _busy = false;
  String? _fatal;

  List<SingleVariantItem> _allItems = []; // Singles + Blends (محددة)
  final List<_BlendLine> _lines = [_BlendLine()];

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
                    'تم',
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

      setState(() {
        _allItems = all;
      });
    } catch (e) {
      setState(() => _fatal = 'تعذر تحميل الأصناف.');
    }
  }

  bool get _hasInvalidLine {
    for (final l in _lines) {
      if (l.item == null) return true;
      if (l.gramsEffective <= 0) return true;
    }
    return false;
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
              'المخزون غير كافٍ لـ "$label".\nالمتاح: ${cur.toStringAsFixed(0)} جم • المطلوب: ${need.toStringAsFixed(0)} جم',
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
              'المخزون غير كافٍ لـ "$label".\nالمتاح: ${cur.toStringAsFixed(0)} جم • المطلوب: ${need.toStringAsFixed(0)} جم',
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

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': FieldValue.serverTimestamp(),
          'created_by': 'cashier_web',
          'type': 'custom_blend',

          // حالات
          'is_complimentary': isComp,
          'is_deferred': isDef,
          'due_amount': isDef ? totalPriceWould : 0.0,
          'paid': !isDef,

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
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل توليفة العميل وخصم المخزون')),
      );
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
          title: const Text('تعذر إتمام العملية'),
          content: SingleChildScrollView(child: Text(msg)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // تنافي ضيافة وأجِّل
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) _isDeferred = false;
    });
  }

  void _setDeferred(bool v) {
    setState(() {
      _isDeferred = v;
      if (v) _isComplimentary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

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
                tooltip: 'رجوع',
              ),
              title: const Text(
                'توليفات العميل',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
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
                  final composer = SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'مكوّنات التوليفة',
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
                              label: const Text('إضافة مكوّن'),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                      'إلغاء',
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
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('تأكيد'),
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

/// ====== كارت سطر ======
class _LineCard extends StatelessWidget {
  final List<SingleVariantItem> items; // Singles + Blends
  final _BlendLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  final VoidCallback onTapGrams;
  final VoidCallback onTapPrice;

  const _LineCard({
    required this.items,
    required this.line,
    required this.onChanged,
    required this.onTapGrams,
    required this.onTapPrice,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 840;

    final dropdown = DropdownButtonFormField<SingleVariantItem>(
      isExpanded: true,
      value: line.item,
      items: items.map((it) {
        final outOfStock = it.stock <= 0;
        final prefix = it.source == ItemSource.blends ? '' : '';
        return DropdownMenuItem<SingleVariantItem>(
          value: it,
          enabled: !outOfStock,
          child: Text(
            outOfStock
                ? '$prefix${it.fullLabel} (غير متاح)'
                : '$prefix${it.fullLabel}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: outOfStock ? Colors.grey : null,
              decoration: outOfStock
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationThickness: outOfStock ? 1 : 0,
            ),
          ),
        );
      }).toList(),
      selectedItemBuilder: (ctx) => items.map((it) {
        final outOfStock = it.stock <= 0;
        final prefix = it.source == ItemSource.blends ? '【توليفة】 ' : '';
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            outOfStock
                ? '$prefix${it.fullLabel} (غير متاح)'
                : '$prefix${it.fullLabel}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: outOfStock ? Colors.grey : null,
              decoration: outOfStock
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationThickness: outOfStock ? 1 : 0,
            ),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v == null || v.stock <= 0) return;
        line.item = v;
        onChanged();
      },
      decoration: const InputDecoration(
        labelText: 'اختر الصنف',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );

    // حقل الجرامات (readOnly + يفتح نومباد)
    final gramField = TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: line.mode == LineInputMode.grams && line.grams > 0
            ? '${line.grams}'
            : '',
      ),
      onTap: onTapGrams,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'الكمية (جم)',
        hintText: 'مثال: 250',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    // حقل السعر (readOnly + يفتح نومباد)
    final priceField = TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: line.mode == LineInputMode.price && line.price > 0
            ? line.price.toStringAsFixed(2)
            : '',
      ),
      onTap: onTapPrice,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'المبلغ (جم)',
        hintText: 'مثال: 120.00',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    Widget sideBox() {
      if (line.mode == LineInputMode.grams) {
        return _KVBox(
          title: 'السعر',
          value: line.linePrice,
          suffix: 'جم',
          fractionDigits: 2,
        );
      } else {
        return _KVBox(
          title: 'الجرامات',
          value: line.gramsEffective.toDouble(),
          suffix: 'جم',
          fractionDigits: 0,
        );
      }
    }

    final modeAndField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LineInputMode>(
          segments: const [
            ButtonSegment(
              value: LineInputMode.grams,
              label: Text('جرامات'),
              icon: Icon(Icons.scale),
            ),
            ButtonSegment(
              value: LineInputMode.price,
              label: Text('سعر'),
              icon: Icon(Icons.attach_money),
            ),
          ],
          selected: {line.mode},
          onSelectionChanged: (s) {
            line.mode = s.first;
            onChanged();
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        if (line.mode == LineInputMode.grams) gramField else priceField,
        if (line.mode == LineInputMode.price) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الجرامات المحسوبة: ${line.gramsEffective} جم',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );

    final removeBtn = IconButton(
      tooltip: 'حذف',
      onPressed: onRemove,
      icon: const Icon(Icons.delete_outline),
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: dropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: modeAndField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: sideBox()),
                  const SizedBox(width: 8),
                  removeBtn,
                ],
              )
            : Column(
                children: [
                  dropdown,
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: modeAndField),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: sideBox()),
                    ],
                  ),
                  Align(alignment: Alignment.centerLeft, child: removeBtn),
                ],
              ),
      ),
    );
  }
}

class _KVBox extends StatelessWidget {
  final String title;
  final double value;
  final String? suffix;
  final int fractionDigits;

  const _KVBox({
    required this.title,
    required this.value,
    this.suffix,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    final vText =
        value.toStringAsFixed(fractionDigits) +
        (suffix != null ? ' $suffix' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(vText, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final bool isComplimentary;
  final ValueChanged<bool?>? onComplimentaryChanged;

  final bool isDeferred;
  final ValueChanged<bool?>? onDeferredChanged;

  final bool isSpiced;
  final ValueChanged<bool?>? onSpicedChanged;

  final int ginsengGrams;
  final VoidCallback? onGinsengMinus;
  final VoidCallback? onGinsengPlus;

  final int totalGrams;
  final double beansAmount;
  final double spiceAmount;
  final double ginsengAmount;
  final double totalPrice;

  const _TotalsCard({
    required this.isComplimentary,
    required this.onComplimentaryChanged,
    required this.isDeferred,
    required this.onDeferredChanged,
    required this.isSpiced,
    required this.onSpicedChanged,
    required this.ginsengGrams,
    required this.onGinsengMinus,
    required this.onGinsengPlus,
    required this.totalGrams,
    required this.beansAmount,
    required this.spiceAmount,
    required this.ginsengAmount,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // — ضيافة + أجِّل (متعارضين) في صف واحد —
            Row(
              children: [
                Expanded(
                  child: ToggleCard(
                    title: 'ضيافة',
                    value: isComplimentary,
                    onChanged: (v) => onComplimentaryChanged?.call(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ToggleCard(
                    title: 'أجِّل',
                    value: isDeferred,
                    onChanged: (v) => onDeferredChanged?.call(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // — محوّج —
            ToggleCard(
              title: 'محوّج',
              value: isSpiced,
              onChanged: (v) => onSpicedChanged?.call(v),
            ),

            // — جينسنج —
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.shade100),
              ),
              child: Row(
                children: [
                  const Text(
                    'جينسنج',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: onGinsengMinus,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$ginsengGrams جم',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onGinsengPlus,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _row('إجمالي الجرامات', '$totalGrams جم'),
            const SizedBox(height: 6),
            _row('سعر البن', beansAmount.toStringAsFixed(2)),
            _row('سعر التحويج', spiceAmount.toStringAsFixed(2)),
            _row('سعر الجينسنج', ginsengAmount.toStringAsFixed(2)),
            const Divider(height: 18),
            _row('الإجمالي', totalPrice.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Row(
      children: [
        Text(k),
        const Spacer(),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;
  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
