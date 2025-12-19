import 'package:equatable/equatable.dart';

enum CashierCategory { drinks, singles, blends, extras, custom }

class CashierState extends Equatable {
  const CashierState({
    this.selectedCategory = CashierCategory.drinks,
    this.searchQuery = '',
  });

  final CashierCategory selectedCategory;
  final String searchQuery;

  CashierState copyWith({
    CashierCategory? selectedCategory,
    String? searchQuery,
  }) {
    return CashierState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [selectedCategory, searchQuery];
}
