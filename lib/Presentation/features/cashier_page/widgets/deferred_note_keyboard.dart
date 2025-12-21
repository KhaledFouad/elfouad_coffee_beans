part of 'deferred_note_field.dart';

class _ArabicKeyboard extends StatelessWidget {
  final ValueChanged<String> onChar;
  final VoidCallback onSpace;
  final VoidCallback onNewLine;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _ArabicKeyboard({
    required this.onChar,
    required this.onSpace,
    required this.onNewLine,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 6.0;

    const rowNumbers = [
      '\u0661',
      '\u0662',
      '\u0663',
      '\u0664',
      '\u0665',
      '\u0666',
      '\u0667',
      '\u0668',
      '\u0669',
      '\u0660',
      '.',
    ];
    const row1 = [
      '\u0636',
      '\u0635',
      '\u062B',
      '\u0642',
      '\u0641',
      '\u063A',
      '\u0639',
      '\u0647',
      '\u062E',
      '\u062D',
      '\u062C',
      '\u062F',
    ];
    const row2 = [
      '\u0634',
      '\u0633',
      '\u064A',
      '\u0628',
      '\u0644',
      '\u0627',
      '\u062A',
      '\u0646',
      '\u0645',
      '\u0643',
      '\u0637',
    ];
    const row3 = [
      '\u0626',
      '\u0621',
      '\u0624',
      '\u0631',
      '\u0644\u0627',
      '\u0649',
      '\u0629',
      '\u0648',
      '\u0632',
      '\u0638',
    ];

    Widget buildKey({
      required Widget child,
      required VoidCallback onPressed,
      Color? backgroundColor,
      Color? foregroundColor,
    }) {
      return SizedBox(
        height: 46,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? Colors.brown.shade200,
            foregroundColor: foregroundColor ?? const Color(0xFF543824),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    Widget buildRow(List<String> keys) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (int i = 0; i < keys.length; i++) ...[
              Expanded(
                child: buildKey(
                  child: Text(
                    keys[i],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => onChar(keys[i]),
                ),
              ),
              if (i != keys.length - 1) const SizedBox(width: spacing),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildRow(rowNumbers),
          const SizedBox(height: spacing),
          buildRow(row1),
          const SizedBox(height: spacing),
          buildRow(row2),
          const SizedBox(height: spacing),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                for (int i = 0; i < row3.length; i++) ...[
                  Expanded(
                    child: buildKey(
                      child: Text(
                        row3[i],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => onChar(row3[i]),
                    ),
                  ),
                  const SizedBox(width: spacing),
                ],
                Expanded(
                  child: buildKey(
                    child: const Icon(Icons.backspace_outlined),
                    onPressed: onBackspace,
                    backgroundColor: Colors.brown.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: spacing),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: buildKey(
                    child: const Text(
                      '\u0645\u0633\u062D',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: onClear,
                    backgroundColor: Colors.brown.shade300,
                  ),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  flex: 6,
                  child: buildKey(
                    child: const Text(
                      '\u0627\u0644\u0639\u0631\u0628\u064A\u0629',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: onSpace,
                    backgroundColor: Colors.brown.shade200,
                  ),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  flex: 2,
                  child: buildKey(
                    child: const Icon(Icons.keyboard_return),
                    onPressed: onNewLine,
                    backgroundColor: const Color(0xFF543824),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
