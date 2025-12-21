part of 'deferred_note_field.dart';

class _ArabicKeyboardDialog extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChar;
  final VoidCallback onSpace;
  final VoidCallback onNewLine;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;

  const _ArabicKeyboardDialog({
    required this.controller,
    required this.onChar,
    required this.onSpace,
    required this.onNewLine,
    required this.onBackspace,
    required this.onClear,
    required this.label,
    required this.hint,
    required this.minLines,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 600 ? 360.0 : 620.0;

    return Dialog(
      backgroundColor: Colors.brown.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                readOnly: true,
                showCursor: true,
                autofocus: true,
                minLines: minLines,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.brown.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.brown.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ArabicKeyboard(
                onChar: onChar,
                onSpace: onSpace,
                onNewLine: onNewLine,
                onBackspace: onBackspace,
                onClear: onClear,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF543824),
                        side: BorderSide(color: Colors.brown.shade300),
                      ),
                      child: const Text(AppStrings.dialogCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          const Color(0xFF543824),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.dialogConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
