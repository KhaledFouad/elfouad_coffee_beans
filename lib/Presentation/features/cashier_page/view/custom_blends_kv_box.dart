part of 'custom_blends_page.dart';

class _KVBox extends StatelessWidget {
  final String title;
  final double value;
  final String? suffix;
  final int fractionDigits;

  const _KVBox({
    required this.title,
    required this.value,
    this.suffix,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    final vText =
        value.toStringAsFixed(fractionDigits) +
        (suffix != null ? ' $suffix' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(vText, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
