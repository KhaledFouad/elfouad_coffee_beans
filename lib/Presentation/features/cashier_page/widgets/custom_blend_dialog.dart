import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// موديل صنف منفرد (بالتحميص)
class SingleVariantItem {
  final String id;
  final String name;
  final String variant; // ممكن تبقى ""
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
}

/// سطر (مكوّن) داخل توليفة العميل
class _BlendLine {
  SingleVariantItem? item;
  int grams; // جرامات

  _BlendLine({this.item, this.grams = 0});

  double get linePrice => (item == null) ? 0 : item!.sellPerG * grams;

  double get lineCost => (item == null) ? 0 : item!.costPerG * grams;
}

class CustomBlendDialog extends StatefulWidget {
  const CustomBlendDialog({super.key});

  @override
  State<CustomBlendDialog> createState() => _CustomBlendDialogState();
}

class _CustomBlendDialogState extends State<CustomBlendDialog> {
  bool _busy = false;
  String? _fatal;

  /// كل الأصناف المنفردة (مع التحميص) من مجموعة singles
  List<SingleVariantItem> _allSingles = [];

  /// الصفوف الحالية
  final List<_BlendLine> _lines = [_BlendLine()];

  bool _isComplimentary = false;

  @override
  void initState() {
    super.initState();
    _loadSingles();
  }

  Future<void> _loadSingles() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('singles').get();

      final items = <SingleVariantItem>[];
      for (final d in snap.docs) {
        final m = d.data();
        final name = (m['name'] ?? '').toString();
        final variant = (m['variant'] ?? '').toString();
        final image = (m['image'] ?? 'assets/singles.jpg').toString();

        double readNum(dynamic v) {
          if (v is num) return v.toDouble();
          return double.tryParse(v?.toString() ?? '0') ?? 0.0;
        }

        final sellPerKg = readNum(m['sellPricePerKg']);
        final costPerKg = readNum(m['costPricePerKg']);
        final stock = readNum(m['stock']);
        final unit = (m['unit'] ?? 'g').toString();

        items.add(
          SingleVariantItem(
            id: d.id,
            name: name,
            variant: variant,
            image: image,
            sellPricePerKg: sellPerKg,
            costPricePerKg: costPerKg,
            stock: stock,
            unit: unit,
          ),
        );
      }

      setState(() => _allSingles = items);
    } catch (e, st) {
      debugPrint('❌ load singles: $e\n$st');
      setState(() => _fatal = 'تعذر تحميل الأصناف المنفردة.');
    }
  }

  double get _totalPrice {
    final p = _lines.fold<double>(0, (sum, l) => sum + l.linePrice);
    return _isComplimentary ? 0.0 : p;
  }

  double get _totalCost => _lines.fold<double>(0, (sum, l) => sum + l.lineCost);

  int get _totalGrams => _lines.fold<int>(0, (sum, l) => sum + (l.grams));

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
        // تحقق، خصم مخزون، ثم سجّل البيع
        // هنجمع تفاصيل العناصر لتتسجل في sales
        final List<Map<String, dynamic>> components = [];

        for (final l in _lines) {
          final it = l.item!;
          final grams = l.grams;

          final ref = db.collection('singles').doc(it.id);
          final snap = await txn.get(ref);
          if (!snap.exists) {
            throw Exception('الصنف "${it.fullLabel}" غير موجود.');
          }

          final current = (snap.get('stock') as num?)?.toDouble() ?? 0.0;
          if (current < grams) {
            throw Exception(
              'المخزون غير كافٍ لـ "${it.fullLabel}". المتاح: ${current.toStringAsFixed(0)} جم',
            );
          }

          txn.update(ref, {'stock': current - grams});

          components.add({
            'item_id': it.id,
            'name': it.name,
            'variant': it.variant, // قد تكون ""
            'unit': 'g',
            'grams': grams.toDouble(),
            'price_per_kg': it.sellPricePerKg,
            'price_per_g': _isComplimentary ? 0.0 : it.sellPerG,
            'line_total_price': _isComplimentary ? 0.0 : (it.sellPerG * grams),
            'cost_per_kg': it.costPricePerKg,
            'cost_per_g': it.costPerG,
            'line_total_cost': it.costPerG * grams,
          });
        }

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'custom_blend',
          'is_complimentary': _isComplimentary,

          'total_grams': _totalGrams.toDouble(),
          'total_price': _totalPrice,
          'total_cost': _totalCost,
          'profit_total': _totalPrice - _totalCost,

          'components': components, // تفاصيل كل مكوّن
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل توليفة العميل وخصم المخزون')),
      );
    } catch (e, st) {
      debugPrint('❌ commit custom blend: $e\n$st');
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حدث خطأ'),
          content: SingleChildScrollView(child: Text('$e')),
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
    final isWide = MediaQuery.of(context).size.width >= 720;

    final shell = isWide
        ? Dialog(
            // ديسكتوب/تابلت: ديالوج كبير
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildBody(maxWidth: 900),
          )
        : Dialog.fullscreen(
            // موبايل: Fullscreen
            child: _buildBody(maxWidth: 600),
          );

    return shell;
  }

  Widget _buildBody({required double maxWidth}) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            // AppBar داخلي للديالوج
            Material(
              color: const Color(0xFF6D4C41),
              elevation: 2,
              child: ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                ),
                title: const Text(
                  'توليفات العميل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: const SizedBox(width: 40),
              ),
            ),

            Expanded(
              child: _allSingles.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // سطور المكونات
                          ..._lines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            return _LineEditor(
                              key: ValueKey('line_$idx'),
                              singles: _allSingles,
                              line: line,
                              onChanged: () => setState(() {}),
                              onRemove: _lines.length == 1 || _busy
                                  ? null
                                  : () => setState(() => _lines.removeAt(idx)),
                            );
                          }).toList(),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _lines.add(_BlendLine()),
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة مكوّن'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ضيافة
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              border: Border.all(color: Colors.brown.shade100),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CheckboxListTile(
                              value: _isComplimentary,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                      () => _isComplimentary = v ?? false,
                                    ),
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('ضيافة (السعر = 0)'),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // إجماليات
                          _TotalsCard(
                            totalGrams: _totalGrams,
                            totalPrice: _totalPrice,
                            totalCost: _totalCost,
                          ),

                          if (_fatal != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _fatal!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _commitSale,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تأكيد'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ويدجت سطر مكوّن
class _LineEditor extends StatelessWidget {
  final List<SingleVariantItem> singles;
  final _BlendLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _LineEditor({
    super.key,
    required this.singles,
    required this.line,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    // Dropdown items (اسم + تحميص)
    final items = singles
        .map(
          (it) => DropdownMenuItem<SingleVariantItem>(
            value: it,
            child: Text(it.fullLabel, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اختيار الصنف
        Expanded(
          flex: 4,
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

        // الكمية بالجرام
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: line.grams > 0 ? line.grams.toString() : '',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (s) {
              final v = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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

        // سعر السطر
        Expanded(
          flex: 2,
          child: _KVCard(title: 'سعر السطر', value: line.linePrice),
        ),
        const SizedBox(width: 8),

        // حذف السطر
        IconButton(
          onPressed: onRemove,
          tooltip: 'حذف',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );

    if (!isWide) {
      // على الشاشات الضيقة نخليها عمودية
      row = Column(
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
                  initialValue: line.grams > 0 ? line.grams.toString() : '',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (s) {
                    final v =
                        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
                child: _KVCard(title: 'سعر السطر', value: line.linePrice),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 12), child: row);
  }
}

class _KVCard extends StatelessWidget {
  final String title;
  final double value;
  const _KVCard({super.key, required this.title, required this.value});

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
  final int totalGrams;
  final double totalPrice;
  final double totalCost;

  const _TotalsCard({
    super.key,
    required this.totalGrams,
    required this.totalPrice,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    final profit = totalPrice - totalCost;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Column(
        children: [
          _row('إجمالي الجرامات', '$totalGrams جم'),
          const SizedBox(height: 6),
          _row('الإجمالي', '${totalPrice.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _row('التكلفة', '${totalCost.toStringAsFixed(2)}'),
          const Divider(height: 18),
          _row('الربح', '${profit.toStringAsFixed(2)}'),
        ],
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
