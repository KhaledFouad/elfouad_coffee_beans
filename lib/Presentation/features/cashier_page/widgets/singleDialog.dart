import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // لفلترة الإدخال

/// استثناء ودّي لرسائل واضحة للمستخدم
class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

enum CalcMode { byGrams, byMoney }

class SingleDialog extends StatefulWidget {
  final SingleGroup group;

  const SingleDialog({super.key, required this.group});

  @override
  State<SingleDialog> createState() => _SingleDialogState();
}

class _SingleDialogState extends State<SingleDialog> {
  bool _busy = false;
  String? _fatal;

  // roast (variant)
  late final List<String> _roastOptions;
  String? _roast;

  // مخزون كل Variant (doc في singles)
  final Map<String, double> _stockByVariantId = {};
  bool _stocksLoading = true;

  // كمية بالجرام (TextField)
  final TextEditingController _gramsCtrl = TextEditingController();
  // المبلغ (للبيع حسب المبلغ)
  final TextEditingController _moneyCtrl = TextEditingController();

  // وضع الحساب: وزن/مبلغ
  CalcMode _mode = CalcMode.byGrams;

  // ضيافة
  bool _isComplimentary = false;

  // محوّج
  bool _isSpiced = false;

  @override
  void initState() {
    super.initState();
    _roastOptions =
        widget.group.variants.keys
            .map((e) => e.toString().trim())
            .toSet()
            .toList()
          ..sort((a, b) {
            if (a.isEmpty && b.isEmpty) return 0;
            if (a.isEmpty) return 1;
            if (b.isEmpty) return -1;
            return a.compareTo(b);
          });
    _roast = _roastOptions.isNotEmpty ? _roastOptions.first : null;

    _preloadStocks();
  }

  Future<void> _preloadStocks() async {
    try {
      final db = FirebaseFirestore.instance;
      final futures = <Future<void>>[];
      for (final v in widget.group.variants.values) {
        futures.add(
          db.collection('singles').doc(v.id).get().then((snap) {
            final m = snap.data();
            double stock = 0.0;
            if (m != null) {
              final s = m['stock'];
              stock = (s is num) ? s.toDouble() : double.tryParse('$s') ?? 0.0;
            }
            _stockByVariantId[v.id] = stock;
          }),
        );
      }
      await Future.wait(futures);

      // لو المختار الحالي مخزونه 0، اختَر أول المتاحين
      final sel = _selected;
      if (sel != null) {
        final st = _stockByVariantId[sel.id] ?? 0.0;
        if (st <= 0) {
          for (final opt in _roastOptions) {
            final v = widget.group.variants[opt];
            if (v == null) continue;
            final s = _stockByVariantId[v.id] ?? 0.0;
            if (s > 0) {
              _roast = opt;
              break;
            }
          }
        }
      }
    } catch (_) {
      // تجاهل — بس ما نعطّل الديالوج
    } finally {
      if (mounted) setState(() => _stocksLoading = false);
    }
  }

  SingleVariant? get _selected {
    final key = _roast ?? '';
    return widget.group.variants[key];
  }

  // أسعار
  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;

  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  // === قواعد التحويج للأصناف المنفردة ===
  double _spiceRatePerKgForSingle(String name) {
    final n = name.trim();
    if (n.contains('كولومبي')) return 80;
    if (n.contains('برازيلي')) return 60;
    if (n.contains('حبشي')) return 60;
    if (n.contains('هندي')) return 60;
    return 40;
  }

  double get _spiceRatePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null) return 0.0;
    return _spiceRatePerKgForSingle(sel.name);
  }

  double get _spicePerG => _spiceRatePerKg / 1000.0;

  // ==== إدخال المستخدم ====
  // الجرامات (لو حسب الوزن) أو المحسوبة من المبلغ (لو حسب المبلغ)
  int get _grams {
    if (_mode == CalcMode.byMoney) {
      final money =
          double.tryParse(_moneyCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (money <= 0) return 0;
      if (_isComplimentary) return 0; // ضيافة: السعر = 0
      final effectivePerG = _sellPerG + (_isSpiced ? _spicePerG : 0.0);
      if (effectivePerG <= 0) return 0;
      final g = (money / effectivePerG).floor();
      return g.clamp(0, 1000000);
    } else {
      final s = _gramsCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final v = int.tryParse(s) ?? 0;
      return v.clamp(0, 1000000);
    }
  }

  double get _beansAmount => _sellPerG * _grams;
  double get _spiceAmount => _isSpiced ? (_grams * _spicePerG) : 0.0;

  double get _pricePerG => _isComplimentary ? 0.0 : _sellPerG; // عرض فقط
  double get _totalPrice =>
      _isComplimentary ? 0.0 : (_beansAmount + _spiceAmount);
  double get _totalCost => _costPerG * _grams; // تكلفة البن فقط

  Future<void> _commitSale() async {
    final sel = _selected;
    if (sel == null) {
      setState(() => _fatal = 'اختر درجة التحميص.');
      await showErrorDialog(context, _fatal!);
      return;
    }
    if (_grams <= 0) {
      setState(() => _fatal = 'من فضلك أدخل كمية صحيحة بالجرام.');
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    final db = FirebaseFirestore.instance;
    final itemRef = db.collection('singles').doc(sel.id);

    try {
      await db.runTransaction((txn) async {
        final snap = await txn.get(itemRef);
        if (!snap.exists) throw UserFriendly('العنصر غير موجود بالمخزون.');

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] is num)
            ? (data['stock'] as num).toDouble()
            : double.tryParse((data['stock'] ?? '0').toString()) ?? 0.0;

        final need = _grams.toDouble();
        if (currentStock < need) {
          final avail = currentStock.toStringAsFixed(0);
          final want = need.toStringAsFixed(0);
          throw UserFriendly(
            'المخزون غير كافٍ.\nالمتاح: $avail جم • المطلوب: $want جم',
          );
        }

        final newStock = currentStock - need;
        txn.update(itemRef, {'stock': newStock});

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': DateTime.now().toUtc(),
          'created_by': 'cashier_web',
          'type': 'single',
          'item_id': sel.id,
          'name': sel.name,
          'variant': sel.variant,
          'unit': 'g',
          'grams': need,
          'is_complimentary': _isComplimentary,

          // بن
          'price_per_kg': _sellPerKg,
          'price_per_g': _pricePerG, // للعرض فقط
          'beans_amount': _beansAmount,

          // تحويج
          'is_spiced': _isSpiced,
          'spice_rate_per_kg': _spiceRatePerKg,
          'spice_amount': _spiceAmount,

          // إجمالي
          'total_price': _totalPrice,

          // تكاليف
          'cost_per_kg': _costPerKg,
          'cost_per_g': _costPerG,
          'total_cost': _totalCost,

          'profit_total': _totalPrice - _totalCost,
          'stock_after': newStock,
          'calc_mode': _mode == CalcMode.byMoney ? 'by_money' : 'by_grams',
          'entered_money': _mode == CalcMode.byMoney
              ? (double.tryParse(_moneyCtrl.text.replaceAll(',', '.')) ?? 0.0)
              : 0.0,
        });
      });

      if (!mounted) return;

      // اغلق الديالوج وارجع للصفحة الرئيسية
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pop(); // close dialog
      nav.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      ); // عدّل اسم المسار لو غير "/"
      ScaffoldMessenger.of(nav.context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل البيع وخصم المخزون')),
      );
    } catch (e, st) {
      logError(e, st);
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
          content: Text(msg),
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
    final name = widget.group.name;
    final image = widget.group.image;

    // يحرك الديالوج فوق الكيبورد بدل ما يختفي
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      Image.asset(
                        image,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // اختيارات التحميص (أكبر + تعطيل اللي مخزونه صفر)
                      if (_roastOptions.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _roastOptions.map((r) {
                              final sel = widget.group.variants[r];
                              final isSelected = (_roast ?? '') == r;
                              final stock = (sel == null)
                                  ? 0.0
                                  : (_stockByVariantId[sel.id] ?? 0.0);
                              final disabled = !_stocksLoading && stock <= 0.0;

                              final label = StringBuffer()
                                ..write(r.isEmpty ? 'بدون' : r);
                              if (disabled) label.write(' (غير متاح)');

                              return ChoiceChip(
                                label: Text(
                                  label.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_busy || disabled)
                                    ? null
                                    : (v) {
                                        if (!v) return;
                                        setState(() => _roast = r);
                                      },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: disabled
                                      ? Colors.grey.shade300
                                      : Colors.brown.shade200,
                                ),
                                selectedColor: Colors.brown.shade100,
                                backgroundColor: disabled
                                    ? Colors.grey.shade100
                                    : null,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                              : (v) {
                                  setState(() {
                                    _isComplimentary = v ?? false;
                                    if (_isComplimentary) {
                                      // خلّي الوضع حسب الوزن لتحديد الجرامات للمخزون
                                      _mode = CalcMode.byGrams;
                                      _moneyCtrl.clear();
                                    }
                                  });
                                },
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'ضيافة',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // محوّج
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          border: Border.all(color: Colors.brown.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          value: _isSpiced,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  _isSpiced = v ?? false;
                                }),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'محوّج',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // وضع الحساب: وزن / مبلغ
                      Align(
                        alignment: Alignment.center,
                        child: SegmentedButton<CalcMode>(
                          segments: const [
                            ButtonSegment(
                              value: CalcMode.byGrams,
                              label: Text('حسب الوزن'),
                              icon: Icon(Icons.scale),
                            ),
                            ButtonSegment(
                              value: CalcMode.byMoney,
                              label: Text('حسب المبلغ'),
                              icon: Icon(Icons.payments_outlined),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: _busy
                              ? null
                              : (s) => setState(() {
                                  _mode = s.first;
                                }),
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.comfortable,
                            padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // إدخال (جرامات أو مبلغ)
                      if (_mode == CalcMode.byGrams) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            children: [
                              const Text('الكمية (جم)'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _gramsCtrl,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: 250',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            children: [
                              const Text('المبلغ (جم)'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _moneyCtrl,
                                  enabled: !_isComplimentary,
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: 100',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '≈ الجرامات المحسوبة: ${_grams.toString()} جم',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      _KVRow(k: 'سعر/كجم', v: _sellPerKg, suffix: 'جم'),
                      _KVRow(k: 'سعر/جرام', v: _pricePerG, suffix: 'جم'),
                      const SizedBox(height: 8),

                      // الإجمالي (بن + تحويج)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.brown.shade100),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'الإجمالي',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _totalPrice.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_fatal != null) ...[
                        const SizedBox(height: 10),
                        _WarningBox(text: _fatal!),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'تأكيد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _moneyCtrl.dispose();
    super.dispose();
  }
}

class _KVRow extends StatelessWidget {
  final String k;
  final double v;
  final String? suffix;
  const _KVRow({required this.k, required this.v, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(k),
        const Spacer(),
        Text('${v.toStringAsFixed(2)}${suffix != null ? ' $suffix' : ''}'),
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
