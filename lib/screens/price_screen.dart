import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PriceScreen extends StatelessWidget {
  const PriceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CollectionReference prices =
        FirebaseFirestore.instance.collection('market_prices');

    return Scaffold(
      appBar: AppBar(title: const Text('Market Prices')),
      body: StreamBuilder<QuerySnapshot>(
        stream: prices.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.docs;

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final doc = data[index];
              return ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
                title: Text(doc['crop'],
                style: GoogleFonts.openSans(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                subtitle: Text("USD ${doc['price']} per kg",
                style: GoogleFonts.openSans(fontSize: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
