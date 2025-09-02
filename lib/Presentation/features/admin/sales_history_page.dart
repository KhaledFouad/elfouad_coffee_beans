import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  DateTimeRange? _range;

  Query<Map<String, dynamic>> _baseQuery() {
    var q = FirebaseFirestore.instance
        .collection('sales')
        .orderBy('created_at', descending: true);
    if (_range != null) {
      q = q
          .where('created_at', isGreaterThanOrEqualTo: _range!.start.toUtc())
          .where('created_at', isLessThanOrEqualTo: _range!.end.toUtc());
    }
    return q;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init =
        _range ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) {
      setState(
        () => _range = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              //   actions: [
              //        IconButton(
              //   tooltip: 'تصفية بالتاريخ',
              //   onPressed: _pickRange,
              //   icon: const Icon(Icons.filter_alt),
              // ),
              // if (_range != null)
              //   IconButton(
              //     tooltip: 'مسح الفلتر',
              //     onPressed: () => setState(() => _range = null),
              //     icon: const Icon(Icons.clear),
              //   ),
              //   ],
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'رجوع',
              ),
              title: const Text(
                'سجلّ المبيعات',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _baseQuery().snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('خطأ في تحميل السجل: ${snap.error}'));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات بيع'));
            }

            final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            byDay = {};
            for (final d in docs) {
              final m = d.data();
              final ts =
                  (m['created_at'] as Timestamp?)?.toDate() ??
                  DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dayKey =
                  '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
              byDay.putIfAbsent(dayKey, () => []).add(d);
            }

            final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

            double _sum(
              List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
              String k,
            ) {
              double s = 0;
              for (final e in es) {
                s += _num(e.data()[k]);
              }
              return s;
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: dayKeys.length,
              itemBuilder: (context, i) {
                final day = dayKeys[i];
                final entries = byDay[day]!;
                final sumPrice = _sum(entries, 'total_price');
                final sumCost = _sum(entries, 'total_cost');
                final sumProfit = sumPrice - sumCost;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DaySection(
                    day: day,
                    entries: entries,
                    sumPrice: sumPrice,
                    sumCost: sumCost,
                    sumProfit: sumProfit,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String day;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> entries;
  final double sumPrice, sumCost, sumProfit;

  const _DaySection({
    required this.day,
    required this.entries,
    required this.sumPrice,
    required this.sumCost,
    required this.sumProfit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _pill(Icons.attach_money, 'مبيعات', sumPrice),
                const SizedBox(width: 6),
                _pill(Icons.factory, 'تكلفة', sumCost),
                const SizedBox(width: 6),
                _pill(Icons.trending_up, 'ربح', sumProfit),
              ],
            ),
            const Divider(height: 18),
            ...entries.map((e) => _SaleTile(doc: e)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, double v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            '$label: ${v.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _SaleTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final createdAt =
        (m['created_at'] as Timestamp?)?.toDate() ??
        DateTime.tryParse(m['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final detectedType = _detectType(m);
    final type = (m['type'] ?? detectedType).toString();
    final isCompl = (m['is_complimentary'] ?? false) == true;

    final totalPrice = _num(m['total_price']);
    final totalCost = _num(m['total_cost']);
    final profit = totalPrice - totalCost;

    final components = _extractComponents(m, type);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.brown.shade100,
        child: Icon(_iconForType(type), color: Colors.brown.shade700, size: 18),
      ),
      title: Row(
        children: [
          Text(
            _typeLabel(type),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (isCompl) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('ضيافة', style: TextStyle(fontSize: 11)),
            ),
          ],
          const Spacer(),
          Text(
            _fmtTime(createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          _kv('الإجمالي', totalPrice),
          const SizedBox(width: 10),
          _kv('التكلفة', totalCost),
          const SizedBox(width: 10),
          _kv('الربح', profit),
        ],
      ),
      children: [
        if (components.isEmpty)
          const ListTile(title: Text('— لا توجد تفاصيل مكونات —'))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: components.map(_componentRow).toList()),
          ),
      ],
    );
  }

  Widget _kv(String k, double v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k: ', style: const TextStyle(color: Colors.black54)),
        Text(
          v.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  static Widget _componentRow(Map<String, dynamic> c) {
    final name = (c['name'] ?? '').toString();
    final variant = (c['variant'] ?? '').toString();
    final unit = (c['unit'] ?? '').toString();
    final qty = _num(c['qty']);
    final grams = _num(c['grams']);
    final price = _num(c['line_total_price']);
    final cost = _num(c['line_total_cost']);

    final label = variant.isNotEmpty ? '$name - $variant' : name;

    final qtyText = grams > 0
        ? '${grams.toStringAsFixed(0)} جم'
        : (qty > 0 ? '$qty ${unit.isEmpty ? "" : unit}' : '');

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.circle, size: 8),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qtyText.isNotEmpty)
            Text(qtyText, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 12),
          Text(
            'س:${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            'ت:${cost.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String t) {
    switch (t) {
      case 'drink':
        return 'مشروب';
      case 'single':
        return 'صنف منفرد';
      case 'ready_blend':
        return 'توليفة جاهزة';
      case 'custom_blend':
        return 'توليفة العميل';
      default:
        return 'عملية';
    }
  }

  static IconData _iconForType(String t) {
    switch (t) {
      case 'drink':
        return Icons.local_cafe;
      case 'single':
        return Icons.coffee_outlined;
      case 'ready_blend':
        return Icons.blender_outlined;
      case 'custom_blend':
        return Icons.auto_awesome_mosaic;
      default:
        return Icons.receipt_long;
    }
  }

  static String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// ===== Helpers =====

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

List<Map<String, dynamic>> _asListMap(dynamic v) {
  if (v is List) {
    return v
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }
  return const [];
}

String _detectType(Map<String, dynamic> m) {
  final t = (m['type'] ?? '').toString();
  if (t.isNotEmpty) return t;
  if (m.containsKey('components')) return 'custom_blend';
  if (m.containsKey('drink_id') || m.containsKey('drink_name')) return 'drink';
  if (m.containsKey('single_id') || m.containsKey('single_name'))
    return 'single';
  if (m.containsKey('blend_id') || m.containsKey('blend_name'))
    return 'ready_blend';
  final items = _asListMap(m['items']);
  if (items.isNotEmpty) {
    final hasGrams = items.any((x) => x.containsKey('grams'));
    if (hasGrams) return 'single';
  }
  return 'unknown';
}

List<Map<String, dynamic>> _extractComponents(
  Map<String, dynamic> m,
  String type,
) {
  final components = _asListMap(m['components']);
  if (components.isNotEmpty) {
    return components.map(_normalizeRow).toList();
  }
  final items = _asListMap(m['items']);
  if (items.isNotEmpty) return items.map(_normalizeRow).toList();
  final lines = _asListMap(m['lines']);
  if (lines.isNotEmpty) return lines.map(_normalizeRow).toList();

  // 👇 هنا التصليح الأساسي للمشروبات من غير components
  if (type == 'drink') {
    final name = (m['drink_name'] ?? m['name'] ?? 'مشروب').toString();
    final variant = (m['roast'] ?? m['variant'] ?? '').toString();
    final qty = _num(m['quantity'] ?? m['qty'] ?? 1);
    final unit = (m['unit'] ?? 'cup').toString();
    final unitPrice = _num(m['unit_price']);
    final unitCost = _num(m['unit_cost']);
    final totalPrice = _num(m['total_price']);
    final totalCost = _num(m['total_cost']);

    return [
      {
        'name': name,
        'variant': variant,
        'qty': qty,
        'unit': unit,
        'grams': 0,
        'line_total_price': totalPrice > 0 ? totalPrice : unitPrice * qty,
        'line_total_cost': totalCost > 0 ? totalCost : unitCost * qty,
      },
    ];
  }

  return const [];
}

Map<String, dynamic> _normalizeRow(Map<String, dynamic> c) {
  String name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
      .toString();
  String variant = (c['variant'] ?? c['roast'] ?? '').toString();
  double grams = _num(c['grams'] ?? c['weight'] ?? 0);
  double qty = _num(c['qty'] ?? c['count'] ?? 0);
  String unit = (c['unit'] ?? (grams > 0 ? 'g' : '')).toString();
  double linePrice = _num(c['line_total_price'] ?? c['total_price'] ?? 0);
  double lineCost = _num(c['line_total_cost'] ?? c['total_cost'] ?? 0);
  return {
    'name': name,
    'variant': variant,
    'grams': grams,
    'qty': qty,
    'unit': unit,
    'line_total_price': linePrice,
    'line_total_cost': lineCost,
  };
}
