import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class PricingAdminScreen extends StatefulWidget {
  const PricingAdminScreen({super.key});

  @override
  State<PricingAdminScreen> createState() => _PricingAdminScreenState();
}

class _PricingAdminScreenState extends State<PricingAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _cropController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _savePrice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final crop = _cropController.text.trim();
      final price = double.parse(_priceController.text.trim());

      // Query if this crop already exists to avoid duplicates
      final existing = await FirebaseFirestore.instance
          .collection('market_prices')
          .where('crop', isEqualTo: crop)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing
        await existing.docs.first.reference.update({
          'price': price,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new
        await FirebaseFirestore.instance.collection('market_prices').add({
          'crop': crop,
          'price': price,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _cropController.clear();
      _priceController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Price saved successfully! ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving price: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePrice(String id) async {
    try {
      await FirebaseFirestore.instance.collection('market_prices').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Price deleted. 🗑️")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          title: const Text("Manage Official Prices"),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Input Form
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          "Update Market Price",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _cropController,
                          decoration: InputDecoration(
                            labelText: "Crop Name",
                            hintText: "e.g. Maize, Soya",
                            prefixIcon: const Icon(Icons.eco_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? "Enter crop name" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Price (USD/kg)",
                            hintText: "e.g. 0.35",
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Enter price";
                            if (double.tryParse(value) == null) return "Invalid price";
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePrice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("SAVE OFFICIAL PRICE", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // List of existing prices
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('market_prices').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error fetching prices"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("No prices available.", style: TextStyle(color: Colors.white70)));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          title: Text(data['crop'] ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("USD/kg"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "USD ${data['price']}",
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deletePrice(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
