import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class DeferredNoteField extends StatefulWidget {
  const DeferredNoteField({
    super.key,
    required this.controller,
    required this.visible,
    required this.enabled,
    this.label = AppStrings.labelNote,
    this.hint = AppStrings.hintDeferredNote,
    this.minLines = 2,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final bool visible;
  final bool enabled;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  State<DeferredNoteField> createState() => _DeferredNoteFieldState();
}

class _DeferredNoteFieldState extends State<DeferredNoteField> {
  late final FocusNode _focusNode;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant DeferredNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.visible || !widget.enabled) && _dialogOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openKeyboard() async {
    if (!widget.enabled || _dialogOpen) return;
    _dialogOpen = true;
    if (kIsWeb) {
      _focusNode.requestFocus();
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      builder: (context) {
        return _ArabicKeyboardDialog(
          controller: widget.controller,
          onChar: _insertText,
          onSpace: () => _insertText(' '),
          onNewLine: () => _insertText('\n'),
          onBackspace: _backspace,
          onClear: _clear,
          label: widget.label,
          hint: widget.hint,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
        );
      },
    );
    if (!mounted) return;
    _dialogOpen = false;
    _focusNode.unfocus();
  }

  void _insertText(String value) {
    final current = widget.controller.value;
    final text = current.text;
    final selection = current.selection;
    final int start = selection.isValid ? selection.start : text.length;
    final int end = selection.isValid ? selection.end : text.length;
    final int safeStart = start.clamp(0, text.length).toInt();
    final int safeEnd = end.clamp(0, text.length).toInt();

    final newText = text.replaceRange(safeStart, safeEnd, value);
    final newOffset = safeStart + value.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _backspace() {
    final current = widget.controller.value;
    final text = current.text;
    final selection = current.selection;

    if (text.isEmpty) return;

    if (selection.isValid && !selection.isCollapsed) {
      final int start = selection.start.clamp(0, text.length).toInt();
      final int end = selection.end.clamp(0, text.length).toInt();
      final newText = text.replaceRange(start, end, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    final int cursor = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : text.length;
    if (cursor <= 0) return;

    final newText = text.replaceRange(cursor - 1, cursor, '');
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor - 1),
    );
  }

  void _clear() {
    widget.controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.brown.shade200),
    );

    if (!widget.visible) {
      return const SizedBox.shrink(key: ValueKey('deferred-note-hidden'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: const ValueKey('deferred-note-visible'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.brown.shade100),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: true,
                  showCursor: true,
                  keyboardType: TextInputType.none,
                  textInputAction: TextInputAction.newline,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  textCapitalization: TextCapitalization.sentences,
                  onTap: widget.enabled ? _openKeyboard : null,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: true,
                    fillColor:
                        widget.enabled ? Colors.white : Colors.brown.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: baseBorder,
                    enabledBorder: baseBorder,
                    disabledBorder: baseBorder.copyWith(
                      borderSide: BorderSide(color: Colors.brown.shade100),
                    ),
                    focusedBorder: baseBorder.copyWith(
                      borderSide: BorderSide(
                        color: Colors.brown.shade400,
                        width: 1.3,
                      ),
                    ),
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
