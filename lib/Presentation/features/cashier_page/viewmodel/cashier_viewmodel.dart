import 'package:flutter/material.dart';
import '../domain/cashier_repository.dart';

class CashierViewModel extends ChangeNotifier {
  final CashierRepository repository;

  CashierViewModel(this.repository);

  bool _loading = false;
  bool get loading => _loading;

  Future<void> registerSale(String productId, int quantity) async {
    try {
      _loading = true;
      notifyListeners();

      await repository.registerSale(productId, quantity);
    } catch (e) {
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
