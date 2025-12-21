part of 'cart_state.dart';

/// Simple cart controller that tracks the current invoice being built.
class CartState extends ChangeNotifier {
  final List<CartLine> _lines = [];
  bool _invoiceDeferred = false;
  bool _invoiceComplimentary = false;
  String _invoiceNote = '';
  String _paymentMethod = 'cash';

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  double get totalPrice =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalPrice);
  double get totalCost =>
      _lines.fold<double>(0, (acc, l) => acc + l.lineTotalCost);
  double get totalProfit {
    if (_invoiceComplimentary) return 0.0;
    return _lines.fold<double>(0.0, (acc, line) {
      if (line.isComplimentary) return acc;
      return acc + (line.lineTotalPrice - line.lineTotalCost);
    });
  }

  bool get invoiceDeferred => _invoiceDeferred;
  bool get invoiceComplimentary => _invoiceComplimentary;
  String get invoiceNote => _invoiceNote;
  String get paymentMethod => _paymentMethod;

  void addLine(CartLine line) {
    _lines.add(line);
    notifyListeners();
  }

  void removeLine(String id) {
    _lines.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _invoiceDeferred = false;
    _invoiceComplimentary = false;
    _invoiceNote = '';
    _paymentMethod = 'cash';
    notifyListeners();
  }

  void setInvoiceDeferred(bool value) {
    _invoiceDeferred = value;
    if (value) {
      _invoiceComplimentary = false;
    }
    notifyListeners();
  }

  void setInvoiceComplimentary(bool value) {
    _invoiceComplimentary = value;
    if (value) {
      _invoiceDeferred = false;
      _invoiceNote = '';
    }
    notifyListeners();
  }

  void setInvoiceNote(String value) {
    _invoiceNote = value;
    notifyListeners();
  }

  void setPaymentMethod(String value) {
    _paymentMethod = value;
    notifyListeners();
  }
}
