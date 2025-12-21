part of 'deferred_note_field.dart';

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
