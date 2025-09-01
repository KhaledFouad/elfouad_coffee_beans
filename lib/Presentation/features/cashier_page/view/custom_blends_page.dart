import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/widgets/item_grid.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomBlendsPage extends StatelessWidget {
  const CustomBlendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // 👇 حالياً نفس الداتا من singles
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا يوجد أصناف متاحة"));
          }

          final items = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              "name": data['name'],
              "image": "assets/custom.jpg", // تقدر تفرقها عن singles
            };
          }).toList();

          return ItemCard(title: "توليفات العميل", items: items);
        },
      ),
    );
  }
}
