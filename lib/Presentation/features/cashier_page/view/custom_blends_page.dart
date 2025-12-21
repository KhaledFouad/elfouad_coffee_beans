// lib/Presentation/features/cashier_page/view/custom_blends_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/deferred_note_field.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/toggle_card.dart';
import 'package:elfouad_coffee_beans/core/di/di.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:elfouad_coffee_beans/core/utils/app_breakpoints.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

part 'custom_blends_models.dart';
part 'custom_blends_line_card.dart';
part 'custom_blends_kv_box.dart';
part 'custom_blends_totals_card.dart';
part 'custom_blends_warning_box.dart';
part 'custom_blends_pad.dart';
part 'custom_blends_load.dart';
part 'custom_blends_checkout.dart';
part 'custom_blends_invoice_flags.dart';
part 'custom_blends_build.dart';

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

abstract class _CustomBlendsStateBase extends State<CustomBlendsPage> {
  bool get _busy;
  set _busy(bool value);

  String? get _fatal;
  set _fatal(String? value);

  bool get _canQuickConfirm;

  List<SingleVariantItem> get _allItems;
  set _allItems(List<SingleVariantItem> value);

  List<_BlendLine> get _lines;

  TextEditingController get _noteCtrl;
  TextEditingController get _titleCtrl;

  bool get _templateApplied;
  set _templateApplied(bool value);

  bool get _isComplimentary;
  set _isComplimentary(bool value);
  bool get _isDeferred;
  set _isDeferred(bool value);
  bool get _isSpiced;
  set _isSpiced(bool value);

  int get _ginsengGrams;
  set _ginsengGrams(int value);

  double get _sumPriceLines;
  int get _sumGrams;
  bool get _canSpiceAny;
  double get _spiceAmount;
  double get _spiceCostAmount;
  double get _effectiveSpiceRatePerKg;
  double get _effectiveSpiceCostPerKg;
  double get _ginsengPriceAmount;
  double get _ginsengCostAmount;
  double get _totalPriceWould;
  double get _uiTotal;

  bool get _showPad;
  set _showPad(bool value);
  _PadTargetType get _padType;
  set _padType(_PadTargetType value);
  int get _padLineIndex;
  set _padLineIndex(int value);
  String get _padBuffer;
  set _padBuffer(String value);

  void _openPadForLine(int lineIndex, _PadTargetType type);
  void _closePad();
  Widget _numPad({required bool allowDot});

  void _setComplimentary(bool v);
  void _setDeferred(bool v);

  CartLine _buildCartLine();
  Future<void> _commitSale();
  Future<void> _commitInstantInvoice();
}

class _CustomBlendsPageState extends _CustomBlendsStateBase
    with
        _CustomBlendsPad,
        _CustomBlendsLoad,
        _CustomBlendsCheckout,
        _CustomBlendsInvoiceFlags,
        _CustomBlendsBuild {
  @override
  bool _busy = false;
  @override
  String? _fatal;
  @override
  bool get _canQuickConfirm => widget.cartMode || widget.onAddToCart != null;

  @override
  List<SingleVariantItem> _allItems = []; // Singles + Blends (محددة)
  @override
  final List<_BlendLine> _lines = [_BlendLine()];
  @override
  final TextEditingController _noteCtrl = TextEditingController();
  @override
  final TextEditingController _titleCtrl = TextEditingController();
  @override
  bool _templateApplied = false;

  @override
  bool _isComplimentary = false; // ضيافة
  @override
  bool _isDeferred = false; // أجِّل
  @override
  bool _isSpiced = false; // التحويج على إجمالي التوليفة

  // جينسنج (على إجمالي الجرامات)
  @override
  int _ginsengGrams = 0;
  static const double _ginsengPricePerG = 5.0;
  static const double _ginsengCostPerG = 4.0;

  // إجماليات
  @override
  double get _sumPriceLines =>
      _lines.fold<double>(0, (s, l) => s + l.linePrice);
  @override
  int get _sumGrams => _lines.fold<int>(0, (s, l) => s + l.gramsEffective);

  // هل أي مكوّن يدعم التحويج؟
  @override
  bool get _canSpiceAny {
    for (final l in _lines) {
      final it = l.item;
      if (it != null && it.supportsSpice) return true;
    }
    return false;
  }

  // التحويج من الداتابيز — نجمع حسب كل مكوّن
  @override
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

  @override
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
  @override
  double get _effectiveSpiceRatePerKg {
    final gKg = _sumGrams / 1000.0;
    if (!_isSpiced || gKg <= 0) return 0.0;
    return _spiceAmount / gKg;
  }

  @override
  double get _effectiveSpiceCostPerKg {
    final gKg = _sumGrams / 1000.0;
    if (!_isSpiced || gKg <= 0) return 0.0;
    return _spiceCostAmount / gKg;
  }

  @override
  double get _ginsengPriceAmount => _ginsengGrams * _ginsengPricePerG;
  @override
  double get _ginsengCostAmount => _ginsengGrams * _ginsengCostPerG;

  @override
  double get _totalPriceWould =>
      _sumPriceLines + _spiceAmount + _ginsengPriceAmount;

  // قيمة واجهة المستخدم (العرض على الشاشة)
  // صفر فقط في حالة الضيافة
  @override
  double get _uiTotal => _isComplimentary ? 0.0 : _totalPriceWould;

  // ===== نومباد داخلي للصفحة كلها =====
  @override
  bool _showPad = false;
  @override
  _PadTargetType _padType = _PadTargetType.none;
  @override
  int _padLineIndex = -1;
  @override
  String _padBuffer = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildPage(context);
  }

}
