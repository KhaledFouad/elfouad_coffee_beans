// lib/Presentation/features/cashier_page/widgets/ExtraDialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/core/error/utils_error.dart';
import 'package:flutter/material.dart';

class ExtraDialog extends StatefulWidget {
  final String extraId;
  final Map<String, dynamic> extraData;

  const ExtraDialog(
      {super.key, required this.extraId, required this.extraData});

  @override
  State<ExtraDialog> createState() => _ExtraDialogState();
}

class _ExtraDialogState extends State<ExtraDialog> {
  bool _busy = false;
  String? _fatal;
  int _qty = 1;

  // ---------- safe getters ----------
  String get _name => (widget.extraData['name'] ?? '').toString();
  String get _image =>
      (widget.extraData['image'] ?? 'assets/cookies.png').toString();

  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  int _intOf(dynamic v, [int def = 0]) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }

  double get _unitPrice => _numOf(widget.extraData['price_sell']);
  double get _unitCost => _numOf(widget.extraData['cost_unit']);
  int get _stock => _intOf(widget.extraData['stock_units']);

  double get _totalPrice => _unitPrice * _qty;
  double get _totalCost => _unitCost * _qty;

  Future<void> _commitSale() async {
    if (_name.isEmpty) {
      setState(() => _fatal = '╪º╪│┘à ╪º┘ä╪╡┘å┘ü ╪║┘è╪▒ ┘à┘ê╪¼┘ê╪».');
      await showErrorDialog(context, _fatal!);
      return;
    }
    if (_qty <= 0) {
      setState(() => _fatal = '╪º┘ä┘â┘à┘è╪⌐ ╪║┘è╪▒ ╪╡╪º┘ä╪¡╪⌐.');
      await showErrorDialog(context, _fatal!);
      return;
    }

    setState(() => _busy = true);
    final db = FirebaseFirestore.instance;
    final ref = db.collection('extras').doc(widget.extraId);

    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception('╪º┘ä╪╡┘å┘ü ╪║┘è╪▒ ┘à┘ê╪¼┘ê╪».');
        }
        final data = snap.data() ?? {};
        final curStock = _intOf(data['stock_units']);
        final unitPrice = _numOf(data['price_sell']);
        final unitCost = _numOf(data['cost_unit']);

        if (curStock < _qty) {
          throw Exception(
              '╪º┘ä┘à╪«╪▓┘ê┘å ╪║┘è╪▒ ┘â╪º┘ü┘ì: ╪º┘ä┘à╪¬╪º╪¡ $curStock ┘é╪╖╪╣╪⌐');
        }

        final totalPrice = unitPrice * _qty;
        final totalCost = unitCost * _qty;
        final profit = totalPrice - totalCost;

        // ╪«╪╡┘à ╪º┘ä┘à╪«╪▓┘ê┘å
        tx.update(ref, {
          'stock_units': curStock - _qty,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // ╪│╪¼┘ä ╪º┘ä╪¿┘è╪╣ ┘ü┘è sales
        final saleRef = db.collection('sales').doc();
        tx.set(saleRef, {
          'type': 'extra',
          'source': 'extras',
          'extra_id': widget.extraId,
          'name': _name,
          'variant': (data['variant'] as String?)?.trim(),
          'unit': 'piece',
          'quantity': _qty,
          'unit_price': unitPrice,
          'total_price': totalPrice,
          'total_cost': totalCost,
          'profit_total': profit,
          'is_deferred': false,
          'paid': true,
          'payment_method': 'cash',
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pop();
      nav.pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e, st) {
      logError(e, st);
      if (mounted) await showErrorDialog(context, e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewInsets =
        EdgeInsets.fromViewPadding(view.viewInsets, view.devicePixelRatio);
    final bottomInset = viewInsets.bottom;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AnimatedPadding(
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== Header (┘å┘ü╪│ ╪│╪¬╪º┘è┘ä ╪º┘ä┘à╪┤╪▒┘ê╪¿╪º╪¬) =====
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: Stack(
                          children: [
                            Image.asset(
                              _image,
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
                                  _name,
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

                      // ===== Body =====
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // ╪│╪╖╪▒ ╪º┘ä╪│╪╣╪▒/╪º┘ä┘à╪«╪▓┘ê┘å
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '╪│╪╣╪▒ ╪º┘ä┘é╪╖╪╣╪⌐: ${_unitPrice.toStringAsFixed(2)} ╪¼',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '╪º┘ä┘à╪«╪▓┘ê┘å: $_stock ┘é╪╖╪╣╪⌐',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Stepper ┘ä┘ä┘â┘à┘è╪⌐
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          if (_qty > 1) {
                                            setState(() => _qty -= 1);
                                          }
                                        },
                                  icon: const Icon(Icons.remove),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    '$_qty',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _qty += 1),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ╪Ñ╪¼┘à╪º┘ä┘è ╪º┘ä╪│╪╣╪▒
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.brown.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: Colors.brown.shade100),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '╪º┘ä╪Ñ╪¼┘à╪º┘ä┘è',
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

                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _busy ? null : () => Navigator.pop(context),
                                child: const Text(
                                  '╪Ñ┘ä╪║╪º╪í',
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
                                        '╪¬╪ú┘â┘è╪»',
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
        ),
      ),
    );
  }
}
