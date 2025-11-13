import 'package:flutter/material.dart';

class DeferredNoteField extends StatelessWidget {
  const DeferredNoteField({
    super.key,
    required this.controller,
    required this.visible,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool visible;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.brown.shade200),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !visible
          ? const SizedBox.shrink(key: ValueKey('deferred-note-hidden'))
          : Column(
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
                      const Text(
                        'ملاحظة',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        enabled: enabled,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: '...اكتب ملاحظة بخصوص البيع المؤجل هنا',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: baseBorder,
                          enabledBorder: baseBorder,
                          disabledBorder: baseBorder.copyWith(
                            borderSide: BorderSide(
                              color: Colors.brown.shade100,
                            ),
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
