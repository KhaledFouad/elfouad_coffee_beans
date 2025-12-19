import 'package:flutter/material.dart';

import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    super.key,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
    this.onConfirmLongPress,
    this.confirmText = AppStrings.dialogConfirm,
    this.cancelText = AppStrings.dialogCancel,
  });

  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final VoidCallback? onConfirmLongPress;
  final String confirmText;
  final String cancelText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onCancel,
            child: Text(
              cancelText,
              style: const TextStyle(
                color: Color(0xFF543824),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                const Color(0xFF543824),
              ),
            ),
            onPressed: busy ? null : onConfirm,
            onLongPress: busy ? null : onConfirmLongPress,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    confirmText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
