part of 'cart_state.dart';

class _CustomBlendWrite {
  _CustomBlendWrite({
    required this.title,
    required this.components,
    required this.totalGrams,
    required this.totalPrice,
    required this.spiced,
    required this.ginsengGrams,
    required this.isComplimentary,
    required this.isDeferred,
    required this.source,
    required this.isInvoice,
  });

  final String title;
  final List<dynamic> components;
  final double totalGrams;
  final double totalPrice;
  final bool spiced;
  final int ginsengGrams;
  final bool isComplimentary;
  final bool isDeferred;
  final String source;
  final bool isInvoice;
}
