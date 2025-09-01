import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SingleDialog extends StatefulWidget {
  final String title;
  final String image;
  final QueryDocumentSnapshot doc;

  const SingleDialog({
    super.key,
    required this.title,
    required this.image,
    required this.doc,
  });

  @override
  State<SingleDialog> createState() => _SingleDialogState();
}

class _SingleDialogState extends State<SingleDialog> {
  final TextEditingController _quantityController = TextEditingController(
    text: "1",
  );
  num totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotal();
    _quantityController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final data = widget.doc.data() as Map<String, dynamic>;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final sellPrice = (data['sellPrice'] as num? ?? 0) * quantity;

    setState(() {
      totalPrice = sellPrice;
    });
  }

  Future<void> _confirmOrder() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final quantity = int.tryParse(_quantityController.text) ?? 1;

    // ✅ تسجيل العملية
    await FirebaseFirestore.instance.collection("sales").add({
      "name": widget.title,
      "variant": data['variant'] ?? "",
      "quantity": quantity,
      "sellPrice": totalPrice,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // ✅ خصم المخزون
    final consumes = data['consumes'] as Map<String, dynamic>? ?? {};
    for (var entry in consumes.entries) {
      final productName = entry.key;
      final gramsUsed = (entry.value as num) * quantity;

      final productDocs = await FirebaseFirestore.instance
          .collection("blends")
          .where("name", isEqualTo: productName)
          .get();

      if (productDocs.docs.isNotEmpty) {
        final doc = productDocs.docs.first;
        final stock = (doc['stock'] as num? ?? 0) - gramsUsed;
        await doc.reference.update({"stock": stock});
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                widget.image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "الكمية",
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "💰 السعر: ${totalPrice.toStringAsFixed(2)} ج.م",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _confirmOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text("إتمام العملية"),
            ),
          ],
        ),
      ),
    );
  }
}
