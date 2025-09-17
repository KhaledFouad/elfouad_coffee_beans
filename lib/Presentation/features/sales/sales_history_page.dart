// ignore_for_file: unused_local_variable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  @override
  void initState() {
    super.initState();
    _range = _todayRange4am();
  }

  DateTimeRange? _range;
  DateTimeRange _todayRange4am() {
    final now = DateTime.now(); // توقيت الجهاز (محلي)
    final today4am = DateTime(now.year, now.month, now.day, 4); // 4 الفجر

    late DateTime startLocal;
    late DateTime endLocal;

    if (now.isBefore(today4am)) {
      // لسه قبل 4 الفجر → لسه في يوم أمس
      startLocal = today4am.subtract(const Duration(days: 1));
      endLocal = today4am;
    } else {
      // بعد 4 الفجر → بداية اليوم الحالي
      startLocal = today4am;
      endLocal = today4am.add(const Duration(days: 1));
    }

    return DateTimeRange(start: startLocal, end: endLocal);
  }

  // اليوم التشغيلي ينتهي 4 الفجر: نستخدم إزاحة -4 ساعات في الاستعلام
  Query<Map<String, dynamic>> _baseQuery() {
    final r = _range ?? _todayRange4am();
    return FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: r.start.toUtc())
        .where('created_at', isLessThan: r.end.toUtc()) // end حصري
        .orderBy('created_at', descending: true)
    // .limit(500) // اختياري: سقف أقصى يومي
    ;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = _range ?? _todayRange4am();

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
      // نعتبر بداية كل يوم هي 4 ص ونهاية اليوم التالي 4 ص
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
      final end = picked.end == picked.start
          ? endBase.add(const Duration(days: 1))
          : endBase.add(const Duration(days: 1)); // نطاق شامل لأيام كاملة

      setState(() => _range = DateTimeRange(start: start, end: end));
    }
  }

  // void _openEditSheet(DocumentSnapshot<Map<String, dynamic>> doc) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     useSafeArea: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder: (_) => _SaleEditSheet(snap: doc),
  //   );
  // }

  // Future<void> _deleteSale(DocumentSnapshot<Map<String, dynamic>> doc) async {
  //   final ok = await showDialog<bool>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('تأكيد الحذف'),
  //       content: const Text('هل تريد حذف عملية البيع هذه؟ لا يمكن التراجع.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('إلغاء'),
  //         ),
  //         FilledButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text('حذف'),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (ok != true) return;
  //   await doc.reference.delete();
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text('تم حذف عملية البيع')));
  // }

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
              actions: [
                IconButton(
                  tooltip: 'تصفية بالتاريخ',
                  onPressed: _pickRange,
                  icon: const Icon(Icons.filter_alt, color: Colors.white),
                ),
                if (_range != null)
                  IconButton(
                    tooltip: 'مسح الفلتر',
                    onPressed: () => setState(() => _range = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
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

            // نحرك الوقت -4 ساعات للتجميع اليومي
            DateTime _shiftForDay(DateTime t) =>
                t.subtract(const Duration(hours: 4));

            final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            byDay = {};
            for (final d in docs) {
              final m = d.data();
              final ts =
                  (m['created_at'] as Timestamp?)?.toDate() ??
                  DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final s = _shiftForDay(ts);
              final dayKey =
                  '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
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

            // int _sumDrinkCups(
            //   List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
            // ) {
            //   int s = 0;
            //   for (final e in es) {
            //     final m = e.data();
            //     final t = (m['type'] ?? '').toString();
            //     if (t == 'drink') {
            //       final q = _num(m['quantity']);
            //       s += (q > 0 ? q.round() : 1);
            //     }
            //   }
            //   return s;
            // }

            // double _sumBeansGrams(
            //   List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
            // ) {
            //   double s = 0;
            //   for (final e in es) {
            //     final m = e.data();
            //     final t = (m['type'] ?? '').toString();
            //     if (t == 'single' || t == 'ready_blend') {
            //       s += _num(m['grams']);
            //     } else if (t == 'custom_blend') {
            //       s += _num(m['total_grams']);
            //     }
            //   }
            //   return s;
            // }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: dayKeys.length,
              itemBuilder: (context, i) {
                final day = dayKeys[i];
                final entries = byDay[day]!;
                final sumPrice = _sum(entries, 'total_price');
                // final sumCost = _sum(entries, 'total_cost');
                // // final sumProfit = sumPrice - sumCost;
                // final cups = _sumDrinkCups(entries);
                // final grams = _sumBeansGrams(entries);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DaySection(
                    day: day,
                    entries: entries,
                    sumPrice: sumPrice,
                    // sumCost: sumCost,
                    // sumProfit: sumProfit,
                    // cups: cups,
                    // grams: grams,
                    // onEdit: (doc) => _openEditSheet(doc),
                    // onDelete: (doc) => _deleteSale(doc),
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
  final double sumPrice;
  // final int cups;
  // final double grams;
  // final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  // final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  const _DaySection({
    required this.day,
    required this.entries,
    required this.sumPrice,
    // required this.sumCost,
    // required this.sumProfit,
    // required this.cups,
    // required this.grams,
    // required this.onEdit,
    // required this.onDelete,
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
                // const SizedBox(width: 6),
                // _pill(Icons.factory, 'تكلفة', sumCost),
                // const SizedBox(width: 6),
                // _pill(Icons.trending_up, 'ربح', sumProfit),
              ],
            ),
            // const SizedBox(height: 8),
            // Row(
            //   children: [
            //     _pill(Icons.local_cafe, 'مشروبات', cups.toDouble()),
            //     const SizedBox(width: 6),
            //     _pill(Icons.scale, 'جرام بن', grams),
            //   ],
            // ),
            const Divider(height: 18),
            ...entries.map(
              (e) => _SaleTile(
                doc: e,
                // onEdit: () => onEdit(e),
                // onDelete: () => onDelete(e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, double v) {
    final text = label == 'جرام بن'
        ? '${v.toStringAsFixed(0)} جم'
        : v.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            '$label: $text',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  // final VoidCallback onEdit;
  // final VoidCallback onDelete;
  const _SaleTile({
    required this.doc,
    // required this.onEdit,
    // required this.onDelete,
  });

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
    // final totalCost = _num(m['total_cost']);
    // final profit = totalPrice - totalCost;

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
          Expanded(
            child: Text(
              _titleLine(m, type),
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
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
          const SizedBox(width: 6),
          Text(
            _fmtTime(createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: _kv('الإجمالي', totalPrice),
      // subtitle: Wrap(
      //   spacing: 10,
      //   runSpacing: 4,
      //   crossAxisAlignment: WrapCrossAlignment.center,
      //   children: [
      //     _kv('الإجمالي', totalPrice),
      //     // _kv('التكلفة', totalCost),
      //     // _kv('الربح', profit),
      //     // Row(
      //     //   mainAxisSize: MainAxisSize.min,
      //     //   children: [
      //     //     IconButton(
      //     //       tooltip: 'تعديل',
      //     //       onPressed: onEdit,
      //     //       icon: const Icon(Icons.edit),
      //     //     ),
      //     //     IconButton(
      //     //       tooltip: 'حذف',
      //     //       onPressed: onDelete,
      //     //       icon: const Icon(Icons.delete_outline),
      //     //     ),
      //     //   ],
      //     // ),
      //   ],
      // ),
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

  static String _titleLine(Map<String, dynamic> m, String type) {
    String name = (m['name'] ?? '').toString();
    String variant = (m['variant'] ?? m['roast'] ?? '').toString();
    String labelNV = variant.isNotEmpty ? '$name $variant' : name;

    switch (type) {
      case 'drink':
        final q = _num(m['quantity']) > 0
            ? _num(m['quantity']).toStringAsFixed(0)
            : '1';
        final dn = (m['drink_name'] ?? '').toString();
        final finalName = labelNV.isNotEmpty
            ? labelNV
            : (dn.isNotEmpty ? dn : 'مشروب');
        return 'مشروب - $q $finalName';
      case 'single':
        {
          final g = _num(m['grams']).toStringAsFixed(0);
          final lbl = labelNV.isNotEmpty ? labelNV : name;
          return 'صنف منفرد - $g جم ${lbl.isNotEmpty ? lbl : ''}'.trim();
        }
      case 'ready_blend':
        {
          final g = _num(m['grams']).toStringAsFixed(0);
          final lbl = labelNV.isNotEmpty ? labelNV : name;
          return 'توليفة جاهزة - $g جم ${lbl.isNotEmpty ? lbl : ''}'.trim();
        }
      case 'custom_blend':
        return 'توليفة العميل';
      default:
        return 'عملية';
    }
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
    // final cost = _num(c['line_total_cost']);

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
          // Text(
          //   'ت:${cost.toStringAsFixed(2)}',
          //   style: const TextStyle(color: Colors.black54),
          // ),
        ],
      ),
    );
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
  if (m.containsKey('single_id') || m.containsKey('single_name')) {
    return 'single';
  }
  if (m.containsKey('blend_id') || m.containsKey('blend_name')) {
    return 'ready_blend';
  }
  final items = _asListMap(m['items']);
  if (items.isNotEmpty) {
    final hasGrams = items.any((x) => x.containsKey('grams'));
    if (hasGrams) return 'single';
  }
  return 'unknown';
}

/// - drink: سطر واحد بعدد الأكواب
/// - single / ready_blend: سطر واحد بالجرامات
/// - custom_blend: نقرأ القائمة كما هي
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

  if (type == 'single' || type == 'ready_blend') {
    final name = (m['name'] ?? '').toString();
    final variant = (m['variant'] ?? '').toString();
    final grams = _num(m['grams']);
    final totalPrice = _num(m['total_price']);
    final totalCost = _num(m['total_cost']);
    return [
      {
        'name': name,
        'variant': variant,
        'grams': grams,
        'qty': 0,
        'unit': 'g',
        'line_total_price': totalPrice,
        'line_total_cost': totalCost,
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

/// ===== BottomSheet لتعديل عملية البيع =====
class _SaleEditSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> snap;
  const _SaleEditSheet({required this.snap});

  @override
  State<_SaleEditSheet> createState() => _SaleEditSheetState();
}

class _SaleEditSheetState extends State<_SaleEditSheet> {
  late Map<String, dynamic> _m;
  late String _type;

  final TextEditingController _totalPriceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _gramsCtrl = TextEditingController();
  bool _isComplimentary = false;
  bool _isSpiced = false;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    _type = (_m['type'] ?? 'unknown').toString();

    _totalPriceCtrl.text = _num(_m['total_price']).toStringAsFixed(2);

    if (_type == 'drink') {
      final qRaw = _m['quantity'];
      final q = (qRaw is num) ? qRaw.toDouble() : double.tryParse('$qRaw') ?? 1;
      _qtyCtrl.text = q.toStringAsFixed(q == q.roundToDouble() ? 0 : 2);
    } else {
      final g = _num(_m['grams']);
      if (g > 0) _gramsCtrl.text = g.toStringAsFixed(0);
    }

    _isComplimentary = (_m['is_complimentary'] ?? false) == true;
    _isSpiced = (_m['is_spiced'] ?? false) == true;
  }

  @override
  void dispose() {
    _totalPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final updates = <String, dynamic>{};

      String type = _type; // drink | single | ready_blend | custom_blend
      bool isCompl = _isComplimentary;
      bool isSpiced = _isSpiced;

      double numOf(dynamic v) =>
          (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

      // قيم محفوظة
      final oldTotalPrice = numOf(_m['total_price']);
      final oldTotalCost = numOf(_m['total_cost']);

      // مشروبات
      final listPrice = numOf(_m['list_price']);
      final unitPrice = numOf(_m['unit_price']);
      final unitCost = numOf(_m['unit_cost']) > 0
          ? numOf(_m['unit_cost'])
          : numOf(_m['list_cost']);

      // أصناف/توليفات بالجرام
      final pricePerKg = numOf(_m['price_per_kg']);
      final costPerKg = numOf(_m['cost_per_kg']);
      final pricePerG = pricePerKg > 0
          ? pricePerKg / 1000.0
          : numOf(_m['price_per_g']);
      final costPerG = costPerKg > 0
          ? costPerKg / 1000.0
          : numOf(_m['cost_per_g']);

      // توليفة العميل
      final linesAmount = numOf(_m['lines_amount']);
      final totalGramsSaved = numOf(_m['total_grams']);
      double spiceRatePerKg = numOf(_m['spice_rate_per_kg']);
      final spiceAmountSaved = numOf(_m['spice_amount']);

      // مدخلات الفورم
      final uiTotalPrice =
          double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
          oldTotalPrice;
      double qty =
          double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['quantity']);
      double grams =
          double.tryParse(_gramsCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['grams']);

      // أعلام
      updates['is_complimentary'] = isCompl;
      if (_m.containsKey('is_spiced')) updates['is_spiced'] = isSpiced;

      // هل المستخدم غيّر السعر يدويًا؟
      final bool manualOverride =
          !isCompl && (uiTotalPrice - oldTotalPrice).abs() > 0.0005;

      double newTotalPrice = oldTotalPrice;
      double newTotalCost = oldTotalCost;
      // double newProfit = 0.0;

      if (type == 'drink') {
        // حنضمن qty على الأقل 1
        qty = qty <= 0 ? 1 : qty;
        updates['quantity'] = qty;

        if (isCompl) {
          newTotalPrice = 0.0;
          newTotalCost = unitCost * qty;
          updates['unit_price'] = 0.0;
          updates['unit_cost'] = unitCost;
        } else if (manualOverride) {
          // نوزع السعر على عدد الأكواب
          final u = (qty > 0) ? (uiTotalPrice / qty) : uiTotalPrice;
          updates['unit_price'] = u;
          updates['unit_cost'] = unitCost;
          newTotalPrice = uiTotalPrice;
          newTotalCost = unitCost * qty;
          updates['manual_override'] = true;
          updates['discount_amount'] =
              (listPrice * qty) - newTotalPrice; // معلوماتي
        } else {
          final unitPriceEffective = unitPrice > 0 ? unitPrice : listPrice;
          updates['unit_price'] = isCompl ? 0.0 : unitPriceEffective;
          updates['unit_cost'] = unitCost;
          newTotalPrice = isCompl ? 0.0 : unitPriceEffective * qty;
          newTotalCost = unitCost * qty;
        }

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        // updates['profit_total'] = newTotalPrice - newTotalCost;
      } else if (type == 'single' || type == 'ready_blend') {
        // grams قد يكون صفر لو المستخدم ما دخلوش—نحافظ على القديم لو مفيش إدخال
        grams = grams > 0 ? grams : numOf(_m['grams']);
        updates['grams'] = grams;

        // تكلفة البن
        newTotalCost = costPerG * grams;

        if (isCompl) {
          newTotalPrice = 0.0;
          updates['beans_amount'] = 0.0;
          if (_m.containsKey('spice_amount')) {
            updates['spice_amount'] = 0.0;
            updates['spice_rate_per_kg'] = 0.0;
          }
        } else if (manualOverride) {
          // لو محوّج: نخلي سعر التحويج ثابت حسب الحقول الحالية/المنطق،
          // والباقي يعتبر "سعر البن"
          double spiceAmount = spiceAmountSaved;
          if (_m.containsKey('is_spiced')) {
            // احسب التحويج من جديد فقط لو flag شغال
            if (isSpiced) {
              if (spiceRatePerKg <= 0) {
                // قواعد التحويج الافتراضية:
                if (type == 'single') {
                  final name = (_m['name'] ?? '').toString();
                  spiceRatePerKg = _spiceRatePerKgForSingle(name);
                } else {
                  spiceRatePerKg = 40.0; // جاهزة
                }
              }
              spiceAmount = (grams / 1000.0) * spiceRatePerKg;
            } else {
              spiceAmount = 0.0;
              spiceRatePerKg = 0.0;
            }
            updates['spice_rate_per_kg'] = spiceRatePerKg;
            updates['spice_amount'] = spiceAmount;
          }

          final beansAmount = (uiTotalPrice - spiceAmount).clamp(
            0.0,
            double.infinity,
          );
          updates['beans_amount'] = beansAmount;

          // حفظ السعر الجديد + خصم معلوماتي اختياري
          newTotalPrice = uiTotalPrice;
          final autoPrice =
              (pricePerG * grams) +
              (isSpiced ? ((grams / 1000.0) * spiceRatePerKg) : 0.0);
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);
        } else {
          // التسعير التلقائي
          final beansAmount = pricePerG * grams;
          double spiceAmount = 0.0;
          if (_m.containsKey('is_spiced')) {
            if (isSpiced) {
              if (spiceRatePerKg <= 0) {
                if (type == 'single') {
                  final name = (_m['name'] ?? '').toString();
                  spiceRatePerKg = _spiceRatePerKgForSingle(name);
                } else {
                  spiceRatePerKg = 40.0;
                }
              }
              spiceAmount = (grams / 1000.0) * spiceRatePerKg;
            } else {
              spiceRatePerKg = 0.0;
            }
            updates['spice_rate_per_kg'] = spiceRatePerKg;
            updates['spice_amount'] = spiceAmount;
          }
          updates['beans_amount'] = beansAmount;
          newTotalPrice = beansAmount + spiceAmount;
        }

        // ثوابت عرض/مرجعية
        updates['price_per_kg'] = pricePerKg;
        updates['price_per_g'] = pricePerG;
        updates['cost_per_kg'] = costPerKg;
        updates['cost_per_g'] = costPerG;

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        // updates['profit_total'] = newTotalPrice - newTotalCost;
      } else if (type == 'custom_blend') {
        final gramsAll = totalGramsSaved > 0
            ? totalGramsSaved
            : numOf(_m['total_grams']);

        double spiceAmount = spiceAmountSaved;
        if (_m.containsKey('is_spiced')) {
          if (isSpiced) {
            spiceRatePerKg = spiceRatePerKg > 0 ? spiceRatePerKg : 50.0;
            spiceAmount = (gramsAll / 1000.0) * spiceRatePerKg;
          } else {
            spiceRatePerKg = 0.0;
            spiceAmount = 0.0;
          }
          updates['spice_rate_per_kg'] = spiceRatePerKg;
          updates['spice_amount'] = spiceAmount;
        }

        final autoPrice = linesAmount + spiceAmount;

        if (isCompl) {
          newTotalPrice = 0.0;
        } else if (manualOverride) {
          newTotalPrice = uiTotalPrice;
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);
        } else {
          newTotalPrice = autoPrice;
        }

        newTotalCost = numOf(_m['total_cost']); // مجموع تكاليف البن من السطور
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        // updates['profit_total'] = newTotalPrice - newTotalCost;
      } else {
        // أنواع غير معروفة: التزم بالسعر المدخل أو صفر لو ضيافة
        newTotalPrice = isCompl ? 0.0 : uiTotalPrice;
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = oldTotalCost;
        // updates['profit_total'] = newTotalPrice - oldTotalCost;
        updates['manual_override'] = true;
      }

      await widget.snap.reference.update(updates);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات (تطبيق سعرك اليدوي عند إدخاله)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_m['name'] ?? 'عملية بيع').toString();
    final createdAt = (_m['created_at'] as Timestamp?)?.toDate();
    final when = createdAt != null
        ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    final isDrink = _type == 'drink';
    final isWeighted = _type == 'single' || _type == 'ready_blend';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 42,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          if (when.isNotEmpty)
            Text(when, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),

          TextFormField(
            controller: _totalPriceCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'السعر الإجمالي (total_price)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          if (isDrink) ...[
            TextFormField(
              controller: _qtyCtrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'عدد الأكواب (quantity)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (isWeighted) ...[
            TextFormField(
              controller: _gramsCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية بالجرامات (grams)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
          ],

          CheckboxListTile(
            value: _isComplimentary,
            onChanged: (v) => setState(() => _isComplimentary = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('ضيافة'),
          ),

          if (_m.containsKey('is_spiced'))
            CheckboxListTile(
              value: _isSpiced,
              onChanged: (v) => setState(() => _isSpiced = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('محوّج'),
            ),

          const SizedBox(height: 8),
          const Text(
            'ملاحظة: تعديل عملية البيع لا يعيد تسوية المخزون تلقائيًا.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

double _spiceRatePerKgForSingle(String name) {
  final n = name.trim();
  if (n.contains('كولوم') || n.contains('كولومبي')) return 80.0;
  if (n.contains('برازي') || n.contains('برازيلي')) return 60.0;
  if (n.contains('حبش') || n.contains('حبشي')) return 60.0;
  if (n.contains('هند') || n.contains('هندي')) return 60.0;
  return 40.0;
}
