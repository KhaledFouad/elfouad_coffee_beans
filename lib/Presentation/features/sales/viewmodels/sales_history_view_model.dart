import 'package:flutter/material.dart';

import '../../../../data/repositories/sales_history_repository.dart';
import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../utils/sale_utils.dart';

class SalesHistoryState {
  const SalesHistoryState({
    required this.groups,
    required this.range,
  });

  final List<SalesDayGroup> groups;
  final DateTimeRange range;

  bool get isEmpty => groups.isEmpty;
}

class SalesHistoryViewModel extends ChangeNotifier {
  SalesHistoryViewModel({required SalesHistoryRepository repository})
      : _repository = repository;

  final SalesHistoryRepository _repository;

  DateTimeRange? _customRange;

  DateTimeRange get activeRange => _customRange ?? defaultSalesRange();

  DateTimeRange? get customRange => _customRange;

  bool get isFiltered => _customRange != null;

  void setRange(DateTimeRange? range) {
    _customRange = range;
    notifyListeners();
  }

  DateTimeRange normalizePickerRange(DateTimeRange picked) {
    final start = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
      4,
    );
    final endBase = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      4,
    );
    return DateTimeRange(start: start, end: endBase.add(const Duration(days: 1)));
  }

  Stream<SalesHistoryState> historyStream() {
    final range = activeRange;
    return _repository.watchSales(range: range).map((docs) {
      final records = docs.map(SaleRecord.new).toList();
      return _buildState(records, range);
    });
  }

  Future<void> settleDeferredSale(String saleId) {
    return _repository.settleDeferredSale(saleId);
  }

  SalesHistoryState _buildState(
    List<SaleRecord> records,
    DateTimeRange range,
  ) {
    final start = range.start;
    final end = range.end;

    bool inRange(DateTime value) {
      return !value.isBefore(start) && value.isBefore(end);
    }

    final filtered = <SaleRecord>[];
    for (final record in records) {
      final include = inRange(record.createdAt) ||
          (record.isDeferred && !record.isPaid) ||
          (record.isPaid && record.settledAt != null && inRange(record.settledAt!));
      if (include) {
        filtered.add(record);
      }
    }

    final Map<String, List<SaleRecord>> grouped = {};
    for (final record in filtered) {
      final effective = record.effectiveTime;
      final shifted = shiftDayByFourHours(effective);
      final key =
          '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
    }

    final dayKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final groups = dayKeys
        .map((key) {
          final entries = grouped[key]!;
          final totalPaid = _sumPaidOnly(entries);
          return SalesDayGroup(label: key, entries: entries, totalPaid: totalPaid);
        })
        .toList();

    return SalesHistoryState(groups: groups, range: range);
  }

  double _sumPaidOnly(List<SaleRecord> entries) {
    double sum = 0;
    for (final entry in entries) {
      if (!entry.isComplimentary && entry.isPaid) {
        sum += entry.totalPrice;
      }
    }
    return sum;
  }
}
