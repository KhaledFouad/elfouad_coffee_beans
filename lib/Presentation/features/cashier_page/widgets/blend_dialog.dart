// lib/Presentation/features/cashier_page/widgets/blend_dialog.dart
// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/blends_models.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/deferred_note_field.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class UserFriendly implements Exception {
  final String message;
  UserFriendly(this.message);
  @override
  String toString() => message;
}

enum InputMode { grams, price }

enum _PadTarget { grams, price, none }

class BlendDialog extends StatefulWidget {
  final BlendGroup group;
  const BlendDialog({super.key, required this.group});

  @override
  State<BlendDialog> createState() => _BlendDialogState();
}

class _BlendDialogState extends State<BlendDialog> {
  bool _busy = false;
  String? _fatal;

  late final List<String> _variantOptions;
  String? _variant;

  final TextEditingController _gramsCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  InputMode _mode = InputMode.grams;

  bool _showPad = false;
  _PadTarget _padTarget = _PadTarget.none;

  // حالات
  bool _isComplimentary = false; // ضيافة
  bool _isDeferred = false; // أجِّل
  bool _isSpiced = false; // محوّج

  // جينسنج (يظهر فقط لو canSpice)
  int _ginsengGrams = 0;
  static const double _ginsengPricePerG = 5.0;
  static const double _ginsengCostPerG = 4.0;

  // من الداتا: تحويج/كجم (سعر/تكلفة) + فلاغ دعم التحويج
  final Map<String, double> _spicesPricePerKgById = {};
  final Map<String, double> _spicesCostPerKgById = {};
  final Map<String, bool> _supportsSpiceById = {};

  static const Set<String> _flavored = {
    'قهوة كراميل',
    'قهوة بندق',
    'قهوة بندق قطع',
    'قهوة شوكلت',
    'قهوة فانيليا',
    'قهوة توت',
    'قهوة فراولة',
    'قهوة مانجو',
    'شاي',
    'شاى',
  };

  // تنافي ضيافة وأجِّل
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) {
        _isDeferred = false;
        _noteCtrl.clear();
        // ضيافة = صفر، يبقى نقفل إدخال بالسعر
        if (_mode == InputMode.price) {
          _mode = InputMode.grams;
          _priceCtrl.clear();
          if (_showPad && _padTarget == _PadTarget.price) _closePad();
        }
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

  int get _grams => _parseInt(_gramsCtrl.text);
  double get _inputPrice => _parseDouble(_priceCtrl.text);

  @override
  void initState() {
    super.initState();
    _variantOptions =
        widget.group.variants.keys
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    _variant = _variantOptions.isNotEmpty ? _variantOptions.first : null;
    _preloadVariantMeta();
  }

  Future<void> _preloadVariantMeta() async {
    try {
      final db = FirebaseFirestore.instance;
      final futures = <Future<void>>[];
      for (final v in widget.group.variants.values) {
        futures.add(
          db.collection('blends').doc(v.id).get().then((snap) {
            final m = snap.data();
            if (m == null) return;
            _spicesPricePerKgById[v.id] = (m['spicesPrice'] is num)
                ? (m['spicesPrice'] as num).toDouble()
                : double.tryParse('${m['spicesPrice'] ?? ''}') ?? 0.0;
            _spicesCostPerKgById[v.id] = (m['spicesCost'] is num)
                ? (m['spicesCost'] as num).toDouble()
                : double.tryParse('${m['spicesCost'] ?? ''}') ?? 0.0;
            _supportsSpiceById[v.id] = (m['supportsSpice'] == true);
          }),
        );
      }
      await Future.wait(futures);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  BlendVariant? get _selected {
    if (_variant != null) return widget.group.variants[_variant!];
    if (widget.group.variants.containsKey('')) return widget.group.variants[''];
    if (widget.group.variants.length == 1) {
      return widget.group.variants.values.first;
    }
    return null;
  }

  double get _sellPerKg => _selected?.sellPricePerKg ?? 0.0;
  double get _costPerKg => _selected?.costPricePerKg ?? 0.0;

  double get _sellPerG => _sellPerKg / 1000.0;
  double get _costPerG => _costPerKg / 1000.0;

  bool get _dbSaysCanSpice {
    final sel = _selected;
    if (sel == null) return false;
    final id = sel.id;
    return (_supportsSpiceById[id] == true) ||
        ((_spicesPricePerKgById[id] ?? 0) > 0) ||
        ((_spicesCostPerKgById[id] ?? 0) > 0);
  }

  bool get _canSpice {
    final sel = _selected;
    if (sel == null) return false;
    final nm = sel.name.trim();
    if (nm == 'توليفة فرنساوي') return false;
    if (_flavored.contains(nm)) return false;
    return _dbSaysCanSpice;
  }

  double get _spicesPricePerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesPricePerKgById[sel.id] ?? 0.0;
  }

  double get _spicesCostPerKg {
    final sel = _selected;
    if (!_isSpiced || sel == null || !_canSpice) return 0.0;
    return _spicesCostPerKgById[sel.id] ?? 0.0;
  }

  double get _spicePricePerG => _spicesPricePerKg / 1000.0;
  double get _spiceCostPerG => _spicesCostPerKg / 1000.0;

  int get _gramsEffective {
    if (_mode == InputMode.grams) return _grams;
    if (_isComplimentary) return 0;
    final perG = _sellPerG + (_isSpiced ? _spicePricePerG : 0.0);
    if (perG <= 0) return 0;
    final g = (_inputPrice / perG).floor();
    return g.clamp(0, 1000000);
  }

  // أجزاء السعر/التكلفة (بن + تحويج + جينسنج)
  double get _beansAmount => _sellPerG * _gramsEffective;
  double get _spiceAmount =>
      (_isSpiced && _canSpice) ? (_gramsEffective * _spicePricePerG) : 0.0;
  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;

  double get _beansCostAmount => _costPerG * _gramsEffective;
  double get _spiceCostAmount =>
      (_isSpiced && _canSpice) ? (_gramsEffective * _spiceCostPerG) : 0.0;
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  double get _pricePerG => _isComplimentary
      ? 0.0
      : (_sellPerG + (_isSpiced && _canSpice ? _spicePricePerG : 0.0));

  double get _totalPrice => _isComplimentary
      ? 0.0
      : (_beansAmount + _spiceAmount + _ginsengPriceAmount);

  double get _totalCost =>
      _beansCostAmount + _spiceCostAmount + _ginsengCostAmount;

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
    final ctrl = (_padTarget == _PadTarget.grams) ? _gramsCtrl : _priceCtrl;
    if (k == 'back') {
      if (ctrl.text.isNotEmpty) {
        ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
      }
    } else if (k == 'clear') {
      ctrl.clear();
    } else if (k == 'dot') {
      if (_padTarget == _PadTarget.price && !ctrl.text.contains('.')) {
        ctrl.text = ctrl.text.isEmpty ? '0.' : '${ctrl.text}.';
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
        final btnW = (maxW - (3 * 8) - (2 * 12)) / 3;
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

  // كارت الجينسنج (لا يظهر إلا لو canSpice)
  Widget _ginsengCard() {
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
      setState(() => _fatal = 'لم يتم تحديد الصنف/التحميص.');
      await showErrorDialog(context, _fatal!);
      return;
    }
    final gramsToSell = _gramsEffective;
    if (gramsToSell <= 0) {
      setState(
        () => _fatal = _mode == InputMode.grams
            ? 'من فضلك أدخل كمية صحيحة بالجرام.'
            : (_isComplimentary
                  ? 'لا يمكن إدخال بالسعر مع ضيافة.'
                  : 'من فضلك أدخل سعرًا صحيحًا.'),
      );
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() {
      _busy = true;
      _fatal = null;
    });

    final db = FirebaseFirestore.instance;
    final itemRef = db.collection('blends').doc(sel.id);

    try {
      await db.runTransaction((txn) async {
        final snap = await txn.get(itemRef);
        if (!snap.exists) throw UserFriendly('التوليفة غير موجودة بالمخزون.');

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] is num)
            ? (data['stock'] as num).toDouble()
            : double.tryParse('${data['stock'] ?? 0}') ?? 0.0;

        final need = gramsToSell.toDouble();
        if (currentStock < need) {
          throw UserFriendly(
            'المخزون غير كافٍ.\nالمتاح: ${currentStock.toStringAsFixed(0)} جم • المطلوب: ${need.toStringAsFixed(0)} جم',
          );
        }

        final newStock = currentStock - need;
        txn.update(itemRef, {'stock': newStock});

        // fallback لو ما اتحملوش فوق
        final spicesPricePerKg = (data['spicesPrice'] is num)
            ? (data['spicesPrice'] as num).toDouble()
            : double.tryParse('${data['spicesPrice'] ?? ''}') ?? 0.0;
        final spicesCostPerKg = (data['spicesCost'] is num)
            ? (data['spicesCost'] as num).toDouble()
            : double.tryParse('${data['spicesCost'] ?? ''}') ?? 0.0;

        final canSp = _canSpice;
        final spicePricePerG = (_isSpiced && canSp)
            ? (spicesPricePerKg / 1000.0)
            : 0.0;
        final spiceCostPerG = (_isSpiced && canSp)
            ? (spicesCostPerKg / 1000.0)
            : 0.0;

        // مبالغ السعر/التكلفة (بن + تحويج + جينسنج)
        final beansPriceAmount = _sellPerG * need;
        final spicePriceAmount = (_isSpiced && canSp)
            ? (spicePricePerG * need)
            : 0.0;
        final ginsengPriceAmount = _isComplimentary
            ? 0.0
            : (_ginsengGrams * _ginsengPricePerG);

        final beansCostAmount = _costPerG * need;
        final spiceCostAmount = (_isSpiced && canSp)
            ? (spiceCostPerG * need)
            : 0.0;
        final ginsengCostAmount = _ginsengGrams * _ginsengCostPerG;

        final isComp = _isComplimentary;
        final isDef = _isDeferred && !isComp; // لا تؤجَّل الضيافة

        // السعر الحقيقي (لا نصفر للأجل)
        final wouldTotalPrice = isComp
            ? 0.0
            : (beansPriceAmount + spicePriceAmount + ginsengPriceAmount);

        final totalCostOut =
            beansCostAmount + spiceCostAmount + ginsengCostAmount;

        // الربح الظاهر = 0 لو ضيافة أو أجل غير مدفوع
        final profitOut = (isDef || isComp)
            ? 0.0
            : (wouldTotalPrice - totalCostOut);

        final note = isDef ? _noteCtrl.text.trim() : '';
        final saleRef = db.collection('sales').doc();
        txn.set(saleRef, {
          'created_at': FieldValue.serverTimestamp(),
          'created_by': 'cashier_web',
          'type': 'ready_blend',
          'item_id': sel.id,
          'name': sel.name,
          'variant': sel.variant,
          'unit': 'g',
          'grams': need,

          // حالات
          'is_complimentary': isComp,
          'is_deferred': isDef,
          'due_amount': isDef ? wouldTotalPrice : 0.0,
          'paid': !isDef,
          'note': note,

          // تحويج
          'is_spiced': _isSpiced && canSp,
          'spice_rate_per_kg': (_isSpiced && canSp) ? spicesPricePerKg : 0.0,
          'spice_amount': (_isSpiced && canSp) ? spicePriceAmount : 0.0,
          'spice_cost_per_kg': (_isSpiced && canSp) ? spicesCostPerKg : 0.0,
          'spice_cost_amount': (_isSpiced && canSp) ? spiceCostAmount : 0.0,

          // أسعار/تكاليف (نصفّر السعر فقط في الضيافة—not الأجل)
          'price_per_kg': _sellPerKg,
          'price_per_g': isComp
              ? 0.0
              : (_sellPerG + ((_isSpiced && canSp) ? spicePricePerG : 0.0)),
          'beans_amount': beansPriceAmount,

          // جينسنج
          'ginseng_grams': _ginsengGrams,
          'ginseng_price_per_g': _ginsengPricePerG,
          'ginseng_cost_per_g': _ginsengCostPerG,
          'ginseng_price_amount': isComp ? 0.0 : ginsengPriceAmount,
          'ginseng_cost_amount': ginsengCostAmount,

          'cost_per_kg': _costPerKg,
          'cost_per_g':
              _costPerG + ((_isSpiced && canSp) ? spiceCostPerG : 0.0),
          'total_cost': totalCostOut,

          // إجمالي/ربح
          'total_price': wouldTotalPrice, // ✅ لا نصفر في الأجل
          'profit_total': profitOut,
          'profit_expected': (wouldTotalPrice - totalCostOut),

          'stock_after': newStock,
        });
      });

      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pop();
      nav.pushNamedAndRemoveUntil('/', (r) => false);
      ScaffoldMessenger.of(nav.context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل بيع التوليفة وخصم المخزون')),
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
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.55),
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
                        if (_variantOptions.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _variantOptions.map((r) {
                                final selected = (_variant ?? '') == r;
                                final v = widget.group.variants[r];
                                final stock = v?.stock ?? double.infinity;
                                final disabled = stock <= 0;
                                final label = disabled ? '$r (غير متاح)' : r;
                                return ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (disabled)
                                        const Icon(Icons.block, size: 16),
                                      if (disabled) const SizedBox(width: 6),
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  selected: selected,
                                  onSelected: _busy || disabled
                                      ? null
                                      : (vSel) {
                                          if (!vSel) return;
                                          setState(() {
                                            _variant = r;
                                            if (!_canSpice) {
                                              _isSpiced = false;
                                              _ginsengGrams = 0;
                                            }
                                          });
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
                                  selectedColor: disabled
                                      ? Colors.grey.shade200
                                      : Colors.brown.shade100,
                                  backgroundColor: disabled
                                      ? Colors.grey.shade100
                                      : null,
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // === محوّج + ضيافة + أجِّل (صف واحد) ===
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
                        DeferredNoteField(
                          controller: _noteCtrl,
                          visible: _isDeferred,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: 12),

                        // === جينسنج (فقط لو canSpice) ===
                        _ginsengCard(),
                        if (_canSpice) const SizedBox(height: 12),

                        // وضع الإدخال
                        Align(
                          alignment: Alignment.center,
                          child: SegmentedButton<InputMode>(
                            segments: const [
                              ButtonSegment(
                                value: InputMode.grams,
                                label: Text('إدخال بالجرامات'),
                                icon: Icon(Icons.scale),
                              ),
                              ButtonSegment(
                                value: InputMode.price,
                                label: Text('إدخال بالسعر'),
                                icon: Icon(Icons.attach_money),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: _busy
                                ? null
                                : (s) => setState(() {
                                    _mode =
                                        (s.first == InputMode.price &&
                                            _isComplimentary)
                                        ? InputMode.grams
                                        : s.first;
                                    if (_showPad) {
                                      if (_padTarget == _PadTarget.price &&
                                          _mode != InputMode.price) {
                                        _closePad();
                                      }
                                      if (_padTarget == _PadTarget.grams &&
                                          _mode != InputMode.grams) {
                                        _closePad();
                                      }
                                    }
                                  }),
                            showSelectedIcon: false,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_mode == InputMode.grams) ...[
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
                                    controller: _priceCtrl,
                                    readOnly: true,
                                    enabled: !_isComplimentary,
                                    textAlign: TextAlign.center,
                                    onTap: (_busy || _isComplimentary)
                                        ? null
                                        : () => _openPad(_PadTarget.price),
                                    decoration: const InputDecoration(
                                      hintText: 'مثال: 120.00',
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
                          Row(
                            children: [
                              const Text('الجرامات المحسوبة'),
                              const Spacer(),
                              Text(
                                '${_gramsEffective.toString()} جم',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _totalPrice.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
                                  allowDot: _padTarget == _PadTarget.price,
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
    _priceCtrl.dispose();
    _noteCtrl.dispose();
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
