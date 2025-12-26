part of 'single_dialog.dart';

mixin _SingleDialogComponents on _SingleDialogStateBase {
  @override
  Widget _ginsengCard() {
    if (!_canSpice) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        children: [
          const Text(
            AppStrings.labelGinseng,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed:
                _busy
                    ? null
                    : () => setState(() {
                      _ginsengGrams = (_ginsengGrams - 1).clamp(0, 1000000);
                    }),
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$_ginsengGrams ${AppStrings.labelGramsShort}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            onPressed:
                _busy
                    ? null
                    : () => setState(() {
                      _ginsengGrams = (_ginsengGrams + 1).clamp(0, 1000000);
                    }),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
