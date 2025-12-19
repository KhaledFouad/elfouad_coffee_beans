import 'package:flutter_bloc/flutter_bloc.dart';

import 'cashier_state.dart';

class CashierCubit extends Cubit<CashierState> {
  CashierCubit() : super(const CashierState());

  void selectCategory(CashierCategory category) {
    if (category == state.selectedCategory) return;
    emit(state.copyWith(selectedCategory: category));
  }

  void updateSearch(String value) {
    if (value == state.searchQuery) return;
    emit(state.copyWith(searchQuery: value));
  }

  void clearSearch() {
    if (state.searchQuery.isEmpty) return;
    emit(state.copyWith(searchQuery: ''));
  }
}
