import 'package:flutter/material.dart';

class ReceiptDialog extends StatelessWidget {
  final String product;
  final int quantity;

  const ReceiptDialog({
    super.key,
    required this.product,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("✅ تم تسجيل البيع"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("المنتج: $product"),
          Text("العدد: $quantity"),
          Text("التاريخ: ${DateTime.now().toString().substring(0, 16)}"),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("تمام"),
        ),
      ],
    );
  }
}
