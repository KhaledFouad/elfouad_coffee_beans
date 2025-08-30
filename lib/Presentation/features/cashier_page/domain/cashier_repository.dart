import '../data/cashier_datasource.dart' show CashierDataSource;

class CashierRepository {
  final CashierDataSource dataSource;

  CashierRepository(this.dataSource);

  Future<void> registerSale(String productId, int quantity) {
    return dataSource.registerSale(productId, quantity);
  }
}
