import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../utils/sale_utils.dart';

class SalesHistoryState extends Equatable {
  static const _unset = Object();

  const SalesHistoryState({
    required this.groups,
    required this.range,
    required this.allRecords,
    required this.fullTotalsByDay,
    required this.isLoadingFirst,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isRangeTotalLoading,
    this.customRange,
  });

  factory SalesHistoryState.initial() => SalesHistoryState(
        groups: const [],
        range: defaultSalesRange(),
        allRecords: const [],
        fullTotalsByDay: const {},
        isLoadingFirst: true,
        isLoadingMore: false,
        hasMore: true,
        isRangeTotalLoading: true,
        customRange: null,
      );

  final List<SalesDayGroup> groups;
  final DateTimeRange range;
  final List<SaleRecord> allRecords;
  final Map<String, double> fullTotalsByDay;
  final bool isLoadingFirst;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isRangeTotalLoading;
  final DateTimeRange? customRange;

  bool get isEmpty => allRecords.isEmpty;
  bool get isFiltered => customRange != null;

  SalesHistoryState copyWith({
    List<SalesDayGroup>? groups,
    DateTimeRange? range,
    List<SaleRecord>? allRecords,
    Map<String, double>? fullTotalsByDay,
    bool? isLoadingFirst,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isRangeTotalLoading,
    Object? customRange = _unset,
  }) {
    return SalesHistoryState(
      groups: groups ?? this.groups,
      range: range ?? this.range,
      allRecords: allRecords ?? this.allRecords,
      fullTotalsByDay: fullTotalsByDay ?? this.fullTotalsByDay,
      isLoadingFirst: isLoadingFirst ?? this.isLoadingFirst,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isRangeTotalLoading:
          isRangeTotalLoading ?? this.isRangeTotalLoading,
      customRange: identical(customRange, _unset)
          ? this.customRange
          : customRange as DateTimeRange?,
    );
  }

  @override
  List<Object?> get props => [
        groups,
        range,
        allRecords,
        fullTotalsByDay,
        isLoadingFirst,
        isLoadingMore,
        hasMore,
        isRangeTotalLoading,
        customRange,
      ];
}
