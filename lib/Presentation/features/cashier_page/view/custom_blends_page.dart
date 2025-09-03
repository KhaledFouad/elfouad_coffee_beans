import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

/// ====== سطر داخل توليفة العميل ======
class _BlendLine {
  SingleVariantItem? item;
  int grams;

  _BlendLine({this.item, this.grams = 0});

  double get linePrice => (item == null) ? 0 : item!.sellPerG * grams;
  double get lineCost => (item == null) ? 0 : item!.costPerG * grams;
}

class CustomBlendsPage extends StatefulWidget {
  const CustomBlendsPage({super.key});
  static const String route = '/custom-blends';

  @override
  State<CustomBlendsPage> createState() => _CustomBlendsPageState();
}

class _CustomBlendsPageState extends State<CustomBlendsPage> {
  bool _busy = false;
  String? _fatal;

  List<SingleVariantItem> _allSingles = [];
  final List<_BlendLine> _lines = [_BlendLine()];

  bool _isComplimentary = false;
  bool _isSpiced = false; // 50ج/كجم على إجمالي الوزن

  // ملخصات
  double get _sumPriceLines =>
      _lines.fold<double>(0, (s, l) => s + l.linePrice);
  int get _sumGrams => _lines.fold<int>(0, (s, l) => s + l.grams);

  // سعر التحويج (عرض وبيع فقط)
  double get _spiceRatePerKg => _isSpiced ? 50.0 : 0.0;
  double get _spiceAmount =>
      _isSpiced ? (_sumGrams / 1000.0) * _spiceRatePerKg : 0.0;

  double get _totalPrice =>
      _isComplimentary ? 0.0 : (_sumPriceLines + _spiceAmount);

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
      setState(() {
        _allSingles = snap.docs.map(SingleVariantItem.fromDoc).toList();
      });
    } catch (e) {
      setState(() => _fatal = 'تعذر تحميل الأصناف المنفردة.');
    }
  }

  bool get _hasInvalidLine {
    for (final l in _lines) {
      if (l.item == null) return true;
      if (l.grams <= 0) return true;
    }
    return false;
  }

  Future<void> _commitSale() async {
    if (_allSingles.isEmpty) {
      setState(() => _fatal = 'لم يتم تحميل الأصناف بعد.');
      return;
    }
    if (_lines.isEmpty || _hasInvalidLine) {
      setState(() => _fatal = 'من فضلك اختر الأصناف وأدخل الكميات بالجرام.');
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    final db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((txn) async {
        // إجمالي المطلوب لكل doc (لو متكرر)
        final Map<String, int> gramsById = {};
        final Map<String, double> currentStockById = {};

        for (final l in _lines) {
          final it = l.item!;
          gramsById[it.id] = (gramsById[it.id] ?? 0) + l.grams;
        }

        // تأكيد المخزون برسالة ودّية
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

        // خصم المخزون
        for (final entry in gramsById.entries) {
          final id = entry.key;
          final need = entry.value.toDouble();
          final cur = currentStockById[id]!;
          final ref = db.collection('singles').doc(id);
          txn.update(ref, {'stock': cur - need});
        }

        // تفاصيل السطور (للتسجيل)
        final components = _lines.map((l) {
          final it = l.item!;
          final pricePerG = _isComplimentary ? 0.0 : it.sellPerG;
          final costPerG = it.costPerG; // لو هتسجل التكلفة مستقبلاً
          return {
            'item_id': it.id,
            'name': it.name,
            'variant': it.variant,
            'unit': 'g',
            'grams': l.grams.toDouble(),

            'price_per_kg': it.sellPricePerKg,
            'price_per_g': pricePerG,
            'line_total_price': pricePerG * l.grams,

            'cost_per_kg': it.costPricePerKg,
            'cost_per_g': costPerG,
            'line_total_cost': costPerG * l.grams,
          };
        }).toList();

        // إنشاء مستند البيع (عرض السعر مفصّل: بن + تحويج)
        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'custom_blend',
          'is_complimentary': _isComplimentary,

          'lines_amount': _sumPriceLines, // سعر البن فقط
          'is_spiced': _isSpiced,
          'spice_rate_per_kg': _spiceRatePerKg,
          'spice_amount': _spiceAmount, // سعر التحويج
          'total_grams': _sumGrams.toDouble(),
          'total_price': _totalPrice, // المجموع (بن + تحويج)

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

    return Scaffold(
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
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildComposerPane()),
                      SizedBox(
                        width: 360,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          child: _TotalsCard(
                            isComplimentary: _isComplimentary,
                            onComplimentaryChanged: _busy
                                ? null
                                : (v) => setState(
                                    () => _isComplimentary = v ?? false,
                                  ),
                            isSpiced: _isSpiced,
                            onSpicedChanged: _busy
                                ? null
                                : (v) => setState(() => _isSpiced = v ?? false),
                            totalGrams: _sumGrams,
                            totalPrice: _totalPrice,
                            beansAmount: _sumPriceLines,
                            spiceAmount: _spiceAmount,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    child: Column(
                      children: [
                        _buildComposerPane(),
                        const SizedBox(height: 12),
                        _TotalsCard(
                          isComplimentary: _isComplimentary,
                          onComplimentaryChanged: _busy
                              ? null
                              : (v) => setState(
                                  () => _isComplimentary = v ?? false,
                                ),
                          isSpiced: _isSpiced,
                          onSpicedChanged: _busy
                              ? null
                              : (v) => setState(() => _isSpiced = v ?? false),
                          totalGrams: _sumGrams,
                          totalPrice: _totalPrice,
                          beansAmount: _sumPriceLines,
                          spiceAmount: _spiceAmount,
                        ),
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
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.maybePop(context),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
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
    );
  }

  Widget _buildComposerPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'مكوّنات التوليفة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _lines.add(_BlendLine())),
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
                    : () => setState(() => _lines.removeAt(idx)),
              ),
            );
          }).toList(),

          if (_fatal != null) ...[
            const SizedBox(height: 8),
            _WarningBox(text: _fatal!),
          ],
        ],
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

  const _LineCard({
    super.key,
    required this.singles,
    required this.line,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    final items = singles
        .map(
          (it) => DropdownMenuItem<SingleVariantItem>(
            value: it,
            child: Text(it.fullLabel, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();

    final card = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<SingleVariantItem>(
                      value: line.item,
                      items: items,
                      onChanged: (v) {
                        line.item = v;
                        onChanged();
                      },
                      decoration: const InputDecoration(
                        labelText: 'اختر الصنف',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: line.grams > 0 ? line.grams.toString() : '',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (s) {
                        final v =
                            int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ??
                            0;
                        line.grams = v.clamp(0, 1000000);
                        onChanged();
                      },
                      decoration: const InputDecoration(
                        labelText: 'الكمية (جم)',
                        hintText: 'مثال: 250',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _KVBox(title: 'السعر', value: line.linePrice),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            : Column(
                children: [
                  DropdownButtonFormField<SingleVariantItem>(
                    value: line.item,
                    items: items,
                    onChanged: (v) {
                      line.item = v;
                      onChanged();
                    },
                    decoration: const InputDecoration(
                      labelText: 'اختر الصنف',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: line.grams > 0
                              ? line.grams.toString()
                              : '',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (s) {
                            final v =
                                int.tryParse(
                                  s.replaceAll(RegExp(r'[^0-9]'), ''),
                                ) ??
                                0;
                            line.grams = v.clamp(0, 1000000);
                            onChanged();
                          },
                          decoration: const InputDecoration(
                            labelText: 'الكمية (جم)',
                            hintText: 'مثال: 250',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KVBox(title: 'السعر', value: line.linePrice),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );

    return card;
  }
}

class _KVBox extends StatelessWidget {
  final String title;
  final double value;
  const _KVBox({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
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
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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

  // عرض الأسعار (مش تكاليف)
  final double beansAmount; // مجموع أسعار البن
  final double spiceAmount; // سعر التحويج

  const _TotalsCard({
    super.key,
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
  const _WarningBox({super.key, required this.text});

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
