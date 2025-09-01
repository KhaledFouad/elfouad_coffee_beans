import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/item_grid.dart';

class BlendsPage extends StatelessWidget {
  const BlendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('blends').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا يوجد توليفات جاهزة"));
          }

          final items = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              "name": "${data['name']} ${data['variant'] ?? ''}".trim(),
              "image": "assets/blends.jpg",
            };
          }).toList();

          return ItemCard(title: "توليفات جاهزة", items: items);
        },
      ),
    );
  }
}
