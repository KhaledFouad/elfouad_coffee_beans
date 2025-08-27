import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/cashier_viewmodel.dart';
import '../widgets/receipt_dialog.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  String? selectedProductId;
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<CashierViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل البيع")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 👇 هنا هنسحب المنتجات من Firestore
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("مفيش منتجات");
                }

                final docs = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  hint: const Text("اختر المنتج"),
                  value: selectedProductId,
                  items: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? "بدون اسم";
                    final degree = data['degree'] ?? "";
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        "$name ${degree.isNotEmpty ? "($degree)" : ""}",
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedProductId = val),
                );
              },
            ),
            const SizedBox(height: 16),

            // 👇 اختيار الكمية
            Row(
              children: [
                const Text("الكمية: "),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (quantity > 1) {
                      setState(() => quantity--);
                    }
                  },
                ),
                Text("$quantity"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => quantity++),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 👇 زر تسجيل البيع
            ElevatedButton(
              onPressed: viewModel.loading || selectedProductId == null
                  ? null
                  : () async {
                      try {
                        await viewModel.registerSale(
                          selectedProductId!,
                          quantity,
                        );

                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (_) => ReceiptDialog(
                              product: selectedProductId!,
                              quantity: quantity,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                      }
                    },
              child: viewModel.loading
                  ? const CircularProgressIndicator()
                  : const Text("تسجيل البيع"),
            ),
          ],
        ),
      ),
    );
  }
}
