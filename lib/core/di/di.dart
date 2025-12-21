import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cart_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/bloc/cashier_cubit.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/data/cashier_datasource.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/domain/cashier_repository.dart';
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/viewmodel/cart_state.dart';
import 'package:elfouad_coffee_beans/Presentation/features/sales/bloc/sales_history_cubit.dart';
import 'package:elfouad_coffee_beans/data/repositories/sales_history_repository.dart';

final GetIt getIt = GetIt.instance;

void setupDi() {
  if (getIt.isRegistered<FirebaseFirestore>()) return;

  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );

  getIt.registerLazySingleton<CashierDataSource>(() => CashierDataSource());
  getIt.registerLazySingleton<CashierRepository>(
    () => CashierRepository(getIt<CashierDataSource>()),
  );

  getIt.registerLazySingleton<SalesHistoryRepository>(
    () => SalesHistoryRepository(getIt<FirebaseFirestore>()),
  );

  getIt.registerLazySingleton<CartCheckoutService>(() => CartCheckoutService());

  getIt.registerFactory<CartCubit>(() => CartCubit());
  getIt.registerFactory<CashierCubit>(() => CashierCubit());
  getIt.registerFactory<SalesHistoryCubit>(
    () => SalesHistoryCubit(repository: getIt<SalesHistoryRepository>()),
  );
}
