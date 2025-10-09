// lib/Presentation/features/cashier_page/widgets/singleDialog.dart
// ignore_for_file: unused_local_variable, unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/singles_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

enum CalcMode { byGrams, byMoney }

enum _PadTarget { grams, money, none }

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

  final Map<String, double> _stockByVariantId = {};
  final Map<String, double> _spicesPriceByVariantId =
      {}; // سعر التحويج/كجم (للبيع)
  final Map<String, double> _spicesCostByVariantId = {}; // تكلفة التحويج/كجم
  bool _stocksLoading = true;

  final TextEditingController _gramsCtrl = TextEditingController();
  final TextEditingController _moneyCtrl = TextEditingController();

  CalcMode _mode = CalcMode.byGrams;

  // ضيافة
  bool _isComplimentary = false;

  // أجِّل
  bool _isDeferred = false;

  // محوّج
  bool _isSpiced = false;

  // جينسنج
  int _ginsengGrams = 0;
  static const double _ginsengPricePerG = 5.0;
  static const double _ginsengCostPerG = 4.0;

  // --- نومباد داخلي ---
  bool _showPad = false;
  _PadTarget _padTarget = _PadTarget.none;

  // تنافي ضيافة وأجِّل
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) {
        _isDeferred = false; // تنافي
        // بما إن الضيافة = 0 جنيه، نقفّل وضع "حسب المبلغ"
        _mode = CalcMode.byGrams;
        _moneyCtrl.clear();
        if (_showPad && _padTarget == _PadTarget.money) _closePad();
      }
    });
  }

  void _setDeferred(bool v) {
    setState(() {
      _isDeferred = v;
      if (v) {
        _isComplimentary = false; // تنافي
      }
    });
  }

  int _parseInt(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
    final v = int.tryParse(cleaned) ?? 0;
    return v.clamp(0, 1000000);
  }

  double _parseDouble(String s) {
    final cleaned = s
        .replaceAll(',', '.')
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

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
            double spicesPrice = 0.0;
            double spicesCost = 0.0;
            if (m != null) {
              final s = m['stock'];
              stock = (s is num) ? s.toDouble() : double.tryParse('$s') ?? 0.0;
              final spP = m['spicesPrice'];
              final spC = m['spicesCost'];
              spicesPrice = (spP is num)
                  ? spP.toDouble()
                  : double.tryParse('$spP') ?? 0.0;
              spicesCost = (spC is num)
                  ? spC.toDouble()
                  : double.tryParse('$spC') ?? 0.0;
            }
            _stockByVariantId[v.id] = stock;
            _spicesPriceByVariantId[v.id] = spicesPrice;
            _spicesCostByVariantId[v.id] = spicesCost;
          }),
        );
      }
      await Future.wait(futures);

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
      // تجاهل
    } finally {
      if (mounted) setState(() => _stocksLoading = false);
    }
  }

  SingleVariant? get _selected {
    final key = _roast ?? '';
    return widget.group.variants[key];
  }

  // يحقّ التحويج لو في الداتابيز قيم (سعر/تكلفة) للتحويج
  bool get _canSpice {
    final sel = _selected;
    if (sel == null) return false;
    final p = _spicesPriceByVariantId[sel.id] ?? 0.0;
    final c = _spicesCostByVariantId[sel.id] ?? 0.0;
    return (p > 0.0 || c > 0.0);
  }

  // أسعار بن (من الموديل)
  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;
  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  // تحويج (من الداتابيز)
  double get _spicesPricePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesPriceByVariantId[sel.id] ?? 0.0;
  }

  double get _spicesCostPerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesCostByVariantId[sel.id] ?? 0.0;
  }

  double get _spicePricePerG => _spicesPricePerKg / 1000.0;
  double get _spiceCostPerG => _spicesCostPerKg / 1000.0;

  int get _grams {
    if (_mode == CalcMode.byMoney) {
      final money = _parseDouble(_moneyCtrl.text);
      if (money <= 0) return 0;
      if (_isComplimentary) return 0; // ضيافة = 0
      final effectivePerG = _sellPerG + (_isSpiced ? _spicePricePerG : 0.0);
      if (effectivePerG <= 0) return 0;
      final g = (money / effectivePerG).floor();
      return g.clamp(0, 1000000);
    } else {
      return _parseInt(_gramsCtrl.text);
    }
  }

  // مبالغ السعر/التكلفة (بن + تحويج + جينسنج)
  double get _beansAmount => _sellPerG * _grams;
  double get _spiceAmount =>
      (_isSpiced && _canSpice) ? (_grams * _spicePricePerG) : 0.0;
  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;

  double get _beansCostAmount => _costPerG * _grams;
  double get _spiceCostAmount =>
      (_isSpiced && _canSpice) ? (_grams * _spiceCostPerG) : 0.0;
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  double get _pricePerG => _isComplimentary
      ? 0.0
      : (_sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0));

  double get _totalPrice => _isComplimentary
      ? 0.0
      : (_beansAmount + _spiceAmount + _ginsengPriceAmount);

  double get _totalCost =>
      _beansCostAmount + _spiceCostAmount + _ginsengCostAmount;

  // ===== نومباد داخلي =====
  void _openPad(_PadTarget target) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _padTarget = target;
      _showPad = true;
    });
  }

  void _closePad() {
    setState(() {
      _showPad = false;
      _padTarget = _PadTarget.none;
    });
  }

  void _applyPadKey(String k) {
    final ctrl = (_padTarget == _PadTarget.grams) ? _gramsCtrl : _moneyCtrl;
    if (k == 'back') {
      if (ctrl.text.isNotEmpty) {
        ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
      }
    } else if (k == 'clear') {
      ctrl.clear();
    } else if (k == 'dot') {
      if (_padTarget == _PadTarget.money && !ctrl.text.contains('.')) {
        ctrl.text = (ctrl.text.isEmpty ? '0.' : '${ctrl.text}.');
      }
    } else if (k == 'done') {
      _closePad();
      return;
    } else {
      ctrl.text += k;
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
        final btnSize = (maxW - 3 * 8 - 2 * 12) / 3;
        return Container(
          margin: const EdgeInsets.only(top: 12),
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
                    width: btnSize,
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

  // === كروت التبديل بنفس ديزاين المشروبات ===

  Widget _ginsengCard() {
    // يظهر فقط لو الصنف بيدعم التحويج (canSpice)
    if (!_canSpice) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        border: Border.all(color: Colors.brown.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text(
            'جينسنج',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: _busy
                ? null
                : () {
                    setState(
                      () => _ginsengGrams = (_ginsengGrams > 0)
                          ? _ginsengGrams - 1
                          : 0,
                    );
                  },
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$_ginsengGrams جم',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _ginsengGrams += 1);
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

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

        // أسعار التحويج من الداتابيز
        final spicesPricePerKg = (data['spicesPrice'] is num)
            ? (data['spicesPrice'] as num).toDouble()
            : double.tryParse('${data['spicesPrice'] ?? ''}') ?? 0.0;

        final spicesCostPerKg = (data['spicesCost'] is num)
            ? (data['spicesCost'] as num).toDouble()
            : double.tryParse('${data['spicesCost'] ?? ''}') ?? 0.0;

        final canSpiceNow = _canSpice;
        final spicePricePerG = (_isSpiced && canSpiceNow)
            ? (spicesPricePerKg / 1000.0)
            : 0.0;
        final spiceCostPerG = (_isSpiced && canSpiceNow)
            ? (spicesCostPerKg / 1000.0)
            : 0.0;

        // أجزاء السعر/التكلفة
        final beansPriceAmount = _sellPerG * need;
        final spicePriceAmount = (_isSpiced && canSpiceNow)
            ? (spicePricePerG * need)
            : 0.0;
        final ginsengPriceAmount = _isComplimentary
            ? 0.0
            : (_ginsengGrams * _ginsengPricePerG);

        final beansCostAmount = _costPerG * need;
        final spiceCostAmount = (_isSpiced && canSpiceNow)
            ? (spiceCostPerG * need)
            : 0.0;
        final ginsengCostAmount = _ginsengGrams * _ginsengCostPerG;

        // إجماليات
        final isComp = _isComplimentary;
        final isDeferred = _isDeferred && !isComp; // لا تؤجَّل الضيافة
        final wouldTotalPrice = isComp
            ? 0.0
            : (beansPriceAmount + spicePriceAmount + ginsengPriceAmount);
        final totalCostOut =
            beansCostAmount + spiceCostAmount + ginsengCostAmount;
        final profitExpected = (isComp || isDeferred)
            ? 0.0
            : wouldTotalPrice - totalCostOut;
        final totalPriceNormal =
            beansPriceAmount + spicePriceAmount + ginsengPriceAmount;

        final totalPriceOut = (isComp || isDeferred) ? 0.0 : totalPriceNormal;

        final profitOut = (isComp || isDeferred)
            ? 0.0
            : (totalPriceOut - totalCostOut);

        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': FieldValue.serverTimestamp(),
          'created_by': 'cashier_web',
          'type': 'single',
          'item_id': sel.id,
          'name': sel.name,
          'variant': sel.variant,
          'unit': 'g',
          'grams': need,

          // حالات
          'is_complimentary': isComp,
          'is_deferred': isDeferred,
          'paid': isDeferred ? false : true,
          'due_amount': isDeferred ? wouldTotalPrice : 0.0,

          // بن
          'price_per_kg': _sellPerKg,
          'price_per_g': isComp
              ? 0.0
              : (_sellPerG +
                    ((_isSpiced && canSpiceNow) ? spicePricePerG : 0.0)),
          'beans_amount': beansPriceAmount,

          // تحويج (سعر + تكلفة)
          'is_spiced': _isSpiced && canSpiceNow,
          'spice_rate_per_kg': (_isSpiced && canSpiceNow)
              ? spicesPricePerKg
              : 0.0,
          'spice_amount': spicePriceAmount,
          'spice_cost_per_kg': (_isSpiced && canSpiceNow)
              ? spicesCostPerKg
              : 0.0,
          'spice_cost_amount': spiceCostAmount,

          // جينسنج
          'ginseng_grams': _ginsengGrams,
          'ginseng_price_per_g': _ginsengPricePerG,
          'ginseng_cost_per_g': _ginsengCostPerG,
          'ginseng_price_amount': isComp ? 0.0 : ginsengPriceAmount,
          'ginseng_cost_amount': ginsengCostAmount,

          // تكاليف
          'cost_per_kg': _costPerKg,
          'cost_per_g':
              _costPerG + ((_isSpiced && canSpiceNow) ? spiceCostPerG : 0.0),
          'total_cost': totalCostOut,

          // إجمالي
          'total_price': wouldTotalPrice, // ⬅️ مش بنصفّر في الأجل
          'profit_total': (isComp || isDeferred) ? 0.0 : profitExpected,
          'profit_expected': profitExpected,

          'stock_after': newStock,
          'calc_mode': _mode == CalcMode.byMoney ? 'by_money' : 'by_grams',
          'entered_money': _mode == CalcMode.byMoney
              ? _parseDouble(_moneyCtrl.text)
              : 0.0,
        });
      });

      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pop();
      nav.pushNamedAndRemoveUntil('/', (r) => false);
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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset + 12),
      child: SafeArea(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
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
                                final disabled =
                                    !_stocksLoading && stock <= 0.0;

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

                        // === محوّج + ضيافة + أجِّل في صف واحد ===
                        Row(
                          children: [
                            if (_canSpice) ...[
                              Expanded(
                                child: ToggleCard(
                                  title: 'محوّج',
                                  value: _isSpiced,
                                  onChanged: (v) =>
                                      setState(() => _isSpiced = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: ToggleCard(
                                title: 'ضيافة',
                                value: _isComplimentary,
                                onChanged: (v) => _setComplimentary(v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ToggleCard(
                                title: 'أجِّل',
                                value: _isDeferred,
                                onChanged: (v) => _setDeferred(v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // === جينسنج (يظهر فقط لو canSpice) ===
                        _ginsengCard(),
                        if (_canSpice) const SizedBox(height: 12),

                        // وضع الحساب
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
                                : (s) {
                                    setState(() {
                                      _mode = s.first;
                                      // ممنوع "حسب المبلغ" مع ضيافة
                                      if (_mode == CalcMode.byMoney &&
                                          _isComplimentary) {
                                        _mode = CalcMode.byGrams;
                                      }
                                      if (_showPad) {
                                        if (_padTarget == _PadTarget.money &&
                                            _mode != CalcMode.byMoney) {
                                          _closePad();
                                        }
                                        if (_padTarget == _PadTarget.grams &&
                                            _mode != CalcMode.byGrams) {
                                          _closePad();
                                        }
                                      }
                                    });
                                  },
                            showSelectedIcon: false,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // مدخلات الوزن/السعر
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
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    onTap: _busy
                                        ? null
                                        : () => _openPad(_PadTarget.grams),
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
                                    readOnly: true,
                                    enabled: !_isComplimentary,
                                    textAlign: TextAlign.center,
                                    onTap: (_busy || _isComplimentary)
                                        ? null
                                        : () => _openPad(_PadTarget.money),
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
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        _KVRow(k: 'سعر/كجم', v: _sellPerKg, suffix: 'جم'),
                        _KVRow(k: 'سعر/جرام', v: _pricePerG, suffix: 'جم'),
                        const SizedBox(height: 8),

                        // الإجمالي
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

                        // النومباد
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: _showPad
                              ? _numPad(
                                  allowDot: _padTarget == _PadTarget.money,
                                )
                              : const SizedBox.shrink(),
                        ),
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
                                color: Color(0xFF543824),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                const Color(0xFF543824),
                              ),
                            ),
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
