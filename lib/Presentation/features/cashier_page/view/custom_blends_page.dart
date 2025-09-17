// lib/Presentation/features/cashier_page/view/custom_blends_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

/// ====== موديل صنف منفرد ======
class SingleVariantItem {
  final String id;
  final String name;
  final String variant; // قد تكون ""
  final String image;
  final double sellPricePerKg;
  final double costPricePerKg;
  final double stock; // جرام
  final String unit; // "g"

  String get fullLabel => variant.isNotEmpty ? '$name - $variant' : name;
  double get sellPerG => sellPricePerKg / 1000.0;
  double get costPerG => costPricePerKg / 1000.0;

  SingleVariantItem({
    required this.id,
    required this.name,
    required this.variant,
    required this.image,
    required this.sellPricePerKg,
    required this.costPricePerKg,
    required this.stock,
    required this.unit,
  });

  static double _readNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  factory SingleVariantItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SingleVariantItem(
      id: d.id,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      image: (m['image'] ?? 'assets/singles.jpg').toString(),
      sellPricePerKg: _readNum(m['sellPricePerKg']),
      costPricePerKg: _readNum(m['costPricePerKg']),
      stock: _readNum(m['stock']),
      unit: (m['unit'] ?? 'g').toString(),
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

  List<SingleVariantItem> _allSingles = [];
  final List<_BlendLine> _lines = [_BlendLine()];

  bool _isComplimentary = false;
  bool _isSpiced = false; // 50ج/كجم على إجمالي الوزن

  // إجماليات
  double get _sumPriceLines =>
      _lines.fold<double>(0, (s, l) => s + l.linePrice);
  int get _sumGrams => _lines.fold<int>(0, (s, l) => s + l.gramsEffective);

  double get _spiceRatePerKg => _isSpiced ? 50.0 : 0.0;
  double get _spiceAmount =>
      _isSpiced ? (_sumGrams / 1000.0) * _spiceRatePerKg : 0.0;
  double get _totalPrice =>
      _isComplimentary ? 0.0 : (_sumPriceLines + _spiceAmount);

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
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',

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
    _loadSingles();
  }

  Future<void> _loadSingles() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('singles')
          .orderBy('name')
          .get();

      final all = snap.docs.map(SingleVariantItem.fromDoc).toList();
      all.sort((a, b) {
        final az = a.stock <= 0 ? 1 : 0;
        final bz = b.stock <= 0 ? 1 : 0;
        if (az != bz) return az.compareTo(bz); // المتاح الأول
        return a.fullLabel.compareTo(b.fullLabel);
      });

      setState(() {
        _allSingles = all;
      });
    } catch (e) {
      setState(() => _fatal = 'تعذر تحميل الأصناف المنفردة.');
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
    if (_allSingles.isEmpty) {
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
        final Map<String, int> gramsById = {};
        final Map<String, double> currentStockById = {};

        for (final l in _lines) {
          final it = l.item!;
          gramsById[it.id] = (gramsById[it.id] ?? 0) + l.gramsEffective;
        }

        for (final entry in gramsById.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final ref = db.collection('singles').doc(id);
          final snap = await txn.get(ref);
          if (!snap.exists) {
            throw UserFriendly('صنف غير موجود (docId=$id).');
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
          currentStockById[id] = cur;
        }

        for (final entry in gramsById.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final cur = currentStockById[id]!;
          final ref = db.collection('singles').doc(id);
          txn.update(ref, {'stock': cur - need});
        }

        final components = _lines.map((l) {
          final it = l.item!;
          final g = l.gramsEffective;
          final pricePerG = _isComplimentary ? 0.0 : it.sellPerG;
          final costPerG = it.costPerG;
          return {
            'item_id': it.id,
            'name': it.name,
            'variant': it.variant,
            'unit': 'g',
            'grams': g.toDouble(),

            'price_per_kg': it.sellPricePerKg,
            'price_per_g': pricePerG,
            'line_total_price': pricePerG * g,

            'cost_per_kg': it.costPricePerKg,
            'cost_per_g': costPerG,
            'line_total_cost': costPerG * g,
          };
        }).toList();

        final double totalCost = _lines.fold<double>(
          0.0,
          (s, l) => s + (l.item!.costPerG * l.gramsEffective),
        );

        final double totalPrice = _totalPrice;
        final double profit = totalPrice - totalCost;

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'custom_blend',
          'is_complimentary': _isComplimentary,

          'lines_amount': _sumPriceLines,
          'is_spiced': _isSpiced,
          'spice_rate_per_kg': _spiceRatePerKg,
          'spice_amount': _spiceAmount,
          'total_grams': _sumGrams.toDouble(),
          'total_price': totalPrice,

          'total_cost': totalCost,
          'profit_total': profit,

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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: 12, // نومباد داخلي مش كيبورد النظام
      ),
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
        body: _allSingles.isEmpty
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
                              singles: _allSingles,
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
                        }).toList(),
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
                          : (v) =>
                                setState(() => _isComplimentary = v ?? false),
                      isSpiced: _isSpiced,
                      onSpicedChanged: _busy
                          ? null
                          : (v) => setState(() => _isSpiced = v ?? false),
                      totalGrams: _sumGrams,
                      totalPrice: _totalPrice,
                      beansAmount: _sumPriceLines,
                      spiceAmount: _spiceAmount,
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
  final List<SingleVariantItem> singles;
  final _BlendLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  final VoidCallback onTapGrams;
  final VoidCallback onTapPrice;

  const _LineCard({
    required this.singles,
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
      items: singles.map((it) {
        final outOfStock = it.stock <= 0;
        return DropdownMenuItem<SingleVariantItem>(
          value: it,
          enabled: !outOfStock,
          child: Text(
            outOfStock ? '${it.fullLabel} (غير متاح)' : it.fullLabel,
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
      selectedItemBuilder: (ctx) => singles.map((it) {
        final outOfStock = it.stock <= 0;
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            outOfStock ? '${it.fullLabel} (غير متاح)' : it.fullLabel,
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
  final bool isSpiced;
  final ValueChanged<bool?>? onSpicedChanged;
  final int totalGrams;
  final double totalPrice;

  final double beansAmount;
  final double spiceAmount;

  const _TotalsCard({
    required this.isComplimentary,
    required this.onComplimentaryChanged,
    required this.isSpiced,
    required this.onSpicedChanged,
    required this.totalGrams,
    required this.totalPrice,
    required this.beansAmount,
    required this.spiceAmount,
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
            CheckboxListTile(
              value: isComplimentary,
              onChanged: onComplimentaryChanged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('ضيافة'),
            ),
            CheckboxListTile(
              value: isSpiced,
              onChanged: onSpicedChanged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('محوّج'),
            ),
            const SizedBox(height: 8),
            _row('إجمالي الجرامات', '$totalGrams جم'),
            const SizedBox(height: 6),
            _row('سعر البن', beansAmount.toStringAsFixed(2)),
            _row('سعر التحويج', spiceAmount.toStringAsFixed(2)),
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
