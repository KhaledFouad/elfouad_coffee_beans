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
      startLocal = today4am.subtract(const Duration(days: 1));
      endLocal = today4am;
    } else {
      startLocal = today4am;
      endLocal = today4am.add(const Duration(days: 1));
    }

    return DateTimeRange(start: startLocal, end: endLocal);
  }

  // هنجيب لحد نهاية المدى فقط (بدون lower bound) + limit
  // وبعد كده نفلتر و"نرحّل" الأجل في الواجهة.
  Query<Map<String, dynamic>> _baseQuery() {
    final r = _range ?? _todayRange4am();
    return FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isLessThan: r.end.toUtc())
        .orderBy('created_at', descending: true)
        .limit(500); // كفاية لليوم + شوية قديم لو في أجل
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
      final end = endBase.add(const Duration(days: 1));
      setState(() => _range = DateTimeRange(start: start, end: end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _range ?? _todayRange4am();

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
            final allDocs = snap.data?.docs ?? [];
            if (allDocs.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات بيع'));
            }

            // حدود المدى المختار
            final start = r.start;
            final end = r.end;

            bool _inRange(DateTime t) =>
                !t.isBefore(start) && t.isBefore(end); // [start, end)

            // فلترة: نضمّ
            // 1) أي عملية تاريخها داخل المدى
            // 2) أو عملية أجل غير مدفوعة (مهما كان تاريخها)
            // 3) أو عملية مدفوعة ومجال التسوية داخل المدى (settled_at)
            final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final d in allDocs) {
              final m = d.data();
              final createdAt = _dtOf(m['created_at']);
              final settledAt = _optDt(m['settled_at']);
              final isDeferred =
                  (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
              final paid = (m['paid'] ?? (!isDeferred)) == true;

              final include =
                  _inRange(createdAt) ||
                  (isDeferred && !paid) ||
                  (paid && settledAt != null && _inRange(settledAt));
              if (include) filtered.add(d);
            }
            if (filtered.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات في هذا النطاق'));
            }

            // التجميع بالأيام حسب "الوقت الفعّال" (effectiveTime):
            // - أجل غير مدفوع => اليوم الحالي الساعة 05:00
            // - مدفوع وبـ settled_at => يوم التسوية
            // - غير ذلك => created_at
            DateTime _effectiveTime(Map<String, dynamic> m) {
              final createdAt = _dtOf(m['created_at']);
              final settledAt = _optDt(m['settled_at']);
              final isDeferred =
                  (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
              final paid = (m['paid'] ?? (!isDeferred)) == true;

              if (isDeferred && !paid) {
                final now = DateTime.now();
                return DateTime(now.year, now.month, now.day, 5); // 05:00 اليوم
              }
              if (paid && settledAt != null) return settledAt;
              return createdAt;
            }

            // اليوم التشغيلي بين 4ص–4ص
            DateTime _shiftMinus4(DateTime t) =>
                t.subtract(const Duration(hours: 4));

            final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            byDay = {};
            for (final d in filtered) {
              final m = d.data();
              final eff = _effectiveTime(m);
              final s = _shiftMinus4(eff);
              final key =
                  '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
              byDay.putIfAbsent(key, () => []).add(d);
            }
            final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

            double sumPaidOnly(
              List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
            ) {
              double s = 0;
              for (final e in es) {
                final m = e.data();
                final isCompl = (m['is_complimentary'] ?? false) == true;
                final isDeferred =
                    (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
                final paid = (m['paid'] ?? (!isDeferred)) == true;
                if (!isCompl && paid) s += _num(m['total_price']);
              }
              return s;
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: dayKeys.length,
              itemBuilder: (context, i) {
                final day = dayKeys[i];
                final entries = byDay[day]!;
                final sumPrice = sumPaidOnly(entries);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DaySection(
                    day: day,
                    entries: entries,
                    sumPrice: sumPrice,
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

  const _DaySection({
    required this.day,
    required this.entries,
    required this.sumPrice,
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
              ],
            ),
            const Divider(height: 18),
            ...entries.map((e) => _SaleTile(doc: e)),
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
        mainAxisSize: MainAxisSize.min,
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
    final createdAt = _dtOf(m['created_at']);
    final settledAt = _optDt(m['settled_at']);

    final detectedType = _detectType(m);
    final type = (m['type'] ?? detectedType).toString();

    final isCompl = (m['is_complimentary'] ?? false) == true;
    final isDeferred = (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;

    // الوقت الفعّال للعرض
    final DateTime now = DateTime.now();
    final DateTime effectiveTime = (isDeferred && !paid)
        ? DateTime(now.year, now.month, now.day, 5) // 05:00 اليوم
        : (paid && settledAt != null ? settledAt : createdAt);

    final dueAmount = _num(m['due_amount']);
    final totalPrice = _num(m['total_price']);

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
            _chip(
              label: 'ضيافة',
              border: Colors.orange.shade200,
              fill: Colors.orange.shade50,
            ),
          ],
          if (isDeferred && !paid) ...[
            const SizedBox(width: 6),
            _chip(
              label: 'أجل',
              border: Colors.red.shade200,
              fill: Colors.red.shade50,
            ),
          ],
          if (isDeferred && paid) ...[
            const SizedBox(width: 6),
            _chip(
              label: 'مدفوع',
              border: Colors.green.shade200,
              fill: Colors.green.shade50,
            ),
          ],
          const SizedBox(width: 6),
          Text(
            _fmtTime(effectiveTime),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [_kv('الإجمالي', totalPrice)],
      ),
      children: [
        if (components.isEmpty)
          const ListTile(title: Text('— لا توجد تفاصيل مكونات —'))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: components.map(_componentRow).toList()),
          ),

        // التاريخ الأصلي يظهر لو الوقت المعروض مختلف (أجل مُرحّل أو مدفوع بـ settled_at)
        if (!_sameMinute(effectiveTime, createdAt))
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.brown),
                const SizedBox(width: 6),
                Text(
                  'التاريخ الأصلي: ${_fmtDateTime(createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // زر “تم الدفع” يظهر فقط لو العملية مؤجّلة وغير مدفوعة
        if (isDeferred && !paid && dueAmount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF543824),
                  ),
                ),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('تأكيد السداد'),
                      content: Text(
                        'سيتم تثبيت دفع ${totalPrice.toStringAsFixed(2)} جم.\nهل تريد المتابعة؟',
                      ),
                      actions: [
                        TextButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              const Color.fromARGB(255, 242, 240, 240),
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              Colors.brown,
                            ),
                            overlayColor: WidgetStateProperty.all(
                              Colors.brown.shade50,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: Colors.brown),
                          ),
                        ),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              const Color(0xFF543824),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('تأكيد'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await settleDeferredSale(doc.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تسوية العملية المؤجّلة'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر التسوية: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.payments),
                label: const Text('تم الدفع'),
              ),
            ),
          ),
      ],
    );
  }

  // تشيب صغيرة موحّدة
  Widget _chip({
    required String label,
    required Color border,
    required Color fill,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  static String _toArabicUnit(String u) {
    if (u.trim().toLowerCase() == 'piece') return 'قطعة';
    return u;
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
        final g = _num(m['grams']).toStringAsFixed(0);
        final lbl = labelNV.isNotEmpty ? labelNV : name;
        return 'صنف منفرد - $g جم ${lbl.isNotEmpty ? lbl : ''}'.trim();
      case 'ready_blend':
        final g2 = _num(m['grams']).toStringAsFixed(0);
        final lbl2 = labelNV.isNotEmpty ? labelNV : name;
        return 'توليفة جاهزة - $g2 جم ${lbl2.isNotEmpty ? lbl2 : ''}'.trim();
      case 'custom_blend':
        return 'توليفة العميل';
      case 'extra':
        final q = _num(m['quantity'] ?? m['qty'] ?? 1).toStringAsFixed(0);
        final en = (m['extra_name'] ?? m['name'] ?? 'سناكس').toString();
        final unit = _toArabicUnit((m['unit'] ?? 'piece').toString());
        return 'سناكس - $q $unit $en';
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

    final label = variant.isNotEmpty ? '$name - $variant' : name;
    final qtyText = grams > 0
        ? '${grams.toStringAsFixed(0)} جم'
        : (qty > 0 ? '$qty ${unit.isEmpty ? "" : _toArabicUnit(unit)}' : '');

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
      case 'extra':
        return Icons.cookie_rounded;
      default:
        return Icons.receipt_long;
    }
  }
}

/// ===== Helpers =====

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

DateTime _dtOf(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  final s = v?.toString() ?? '';
  return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _optDt(dynamic v) {
  if (v == null) return null;
  try {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  } catch (_) {
    return null;
  }
}

String _fmtTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _fmtDateTime(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $h:$min';
}

bool _sameMinute(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;
}

/// - drink: سطر واحد بعدد الأكواب
/// - single / ready_blend: سطر واحد بالجرامات
/// - custom_blend: نقرأ القائمة كما هي
/// - extra: سطر واحد بعدد القطع
List<Map<String, dynamic>> _extractComponents(
  Map<String, dynamic> m,
  String type,
) {
  final components = _asListMap(m['components']);
  if (components.isNotEmpty) return components.map(_normalizeRow).toList();
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

  if (type == 'extra') {
    final name = (m['extra_name'] ?? m['name'] ?? 'سناكس').toString();
    final variant = (m['variant'] ?? '').toString();
    final qty = _num(m['quantity'] ?? m['qty'] ?? 1);
    final unit = (m['unit'] ?? 'piece').toString();
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
/// (لو عندك الـ _SaleEditSheet في فايل تاني سيبه زي ما هو)
class _SaleEditSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> snap;
  const _SaleEditSheet({required this.snap});

  @override
  State<_SaleEditSheet> createState() => _SaleEditSheetState();
}

class _SaleEditSheetState extends State<_SaleEditSheet> {
  // ... (اترك شيت التعديل عندك كما هو بدون تغيير)
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// تسوية الأجل (زي ما عندك)
Future<void> settleDeferredSale(String saleId) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('sales').doc(saleId);

  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) throw Exception('Sale not found');

    final m = snap.data() as Map<String, dynamic>;
    final bool isDeferred = m['is_deferred'] == true;
    final double dueAmount = (m['due_amount'] is num)
        ? (m['due_amount'] as num).toDouble()
        : double.tryParse('${m['due_amount'] ?? 0}') ?? 0.0;

    if (!isDeferred || dueAmount <= 0) {
      throw Exception('Not a valid deferred sale.');
    }

    final double totalCost = (m['total_cost'] is num)
        ? (m['total_cost'] as num).toDouble()
        : double.tryParse('${m['total_cost'] ?? 0}') ?? 0.0;

    final comps = (m['components'] as List?)?.cast<Map<String, dynamic>>();
    if (comps != null && comps.isNotEmpty) {
      for (final c in comps) {
        final grams = (c['grams'] is num)
            ? (c['grams'] as num).toDouble()
            : double.tryParse('${c['grams'] ?? 0}') ?? 0.0;
        final ppk = (c['price_per_kg'] is num)
            ? (c['price_per_kg'] as num).toDouble()
            : double.tryParse('${c['price_per_kg'] ?? 0}') ?? 0.0;

        double ppg = (c['price_per_g'] is num)
            ? (c['price_per_g'] as num).toDouble()
            : double.tryParse('${c['price_per_g'] ?? 0}') ?? 0.0;

        if (ppg <= 0 && ppk > 0) {
          ppg = ppk / 1000.0;
          c['price_per_g'] = ppg;
          c['line_total_price'] = ppg * grams;
        }
      }
      tx.update(ref, {'components': comps});
    }

    final newTotalPrice = dueAmount;
    final newProfit = newTotalPrice - totalCost;

    tx.update(ref, {
      'total_price': newTotalPrice,
      'profit_total': newProfit,
      'is_deferred': false,
      'paid': true,
      'due_amount': 0.0,
      'settled_at': FieldValue.serverTimestamp(),
    });
  });
}

String _detectType(Map<String, dynamic> m) {
  final t = (m['type'] ?? '').toString();
  if (t.isNotEmpty) {
    if (t == 'extra') return 'extra';
    return t;
  }

  if (m.containsKey('components')) return 'custom_blend';

  if (m.containsKey('drink_id') || m.containsKey('drink_name')) {
    return 'drink';
  }
  if (m.containsKey('single_id') || m.containsKey('single_name')) {
    return 'single';
  }
  if (m.containsKey('blend_id') || m.containsKey('blend_name')) {
    return 'ready_blend';
  }
  if (m.containsKey('extra_id') || m.containsKey('extra_name')) {
    return 'extra';
  }

  final items = _asListMap(m['items']);
  if (items.isNotEmpty) {
    final hasGrams = items.any((x) => x.containsKey('grams'));
    if (hasGrams) return 'single';
  }

  return 'unknown';
}
