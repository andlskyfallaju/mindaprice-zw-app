import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/marketplace_service.dart';
import 'location_picker_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  double? _selectedLatitude;
  double? _selectedLongitude;

  String _selectedCategory = 'Grains';
  final List<String> _categories = [
    'Grains',
    'Vegetables',
    'Fruit',
    'Livestock',
    'Equipment',
    'Fertilizers',
    'Seeds',
    'Other'
  ];

  final List<XFile> _images = [];
  final MarketplaceService _marketplaceService = MarketplaceService();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 5 images allowed")),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _images.add(pickedFile);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await _marketplaceService.addProduct(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      price: double.parse(_priceController.text),
      category: _selectedCategory,
      images: _images,
      location: _locationController.text.trim(),
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product listed successfully!")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error")),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          title: Text(
            "List a Product",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section
                      Text(
                        "Product Images (${_images.length}/5)",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ..._images.asMap().entries.map((entry) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: kIsWeb 
                                          ? NetworkImage(entry.value.path) as ImageProvider
                                          : FileImage(io.File(entry.value.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: -4,
                                    child: IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red),
                                      onPressed: () => _removeImage(entry.key),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            if (_images.length < 5)
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                  ),
                                  child: const Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: GoogleFonts.montserrat(color: Colors.black87),
                        decoration: _inputDecoration("Product Title", Icons.title),
                        validator: (val) => val == null || val.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 18),

                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: _inputDecoration("Category", Icons.category),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.montserrat()));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                      const SizedBox(height: 18),

                      // Price
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.montserrat(color: Colors.black87),
                        decoration: _inputDecoration("Price (USD per unit)", Icons.attach_money),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid price";
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Location
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push<LocationPickerResult>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LocationPickerScreen(),
                            ),
                          );

                          if (result != null && mounted) {
                            setState(() {
                              _locationController.text = result.locationName;
                              _selectedLatitude = result.location.latitude;
                              _selectedLongitude = result.location.longitude;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _locationController,
                            style: GoogleFonts.montserrat(color: Colors.black87),
                            decoration: _inputDecoration(
                              "Tap to Pinpoint Location", 
                              Icons.location_on_outlined,
                              suffixIcon: const Icon(Icons.map, color: Colors.green),
                            ),
                            validator: (val) => val == null || val.isEmpty ? "Required" : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        style: GoogleFonts.montserrat(color: Colors.black87),
                        decoration: _inputDecoration("Description", Icons.description_outlined),
                        validator: (val) => val == null || val.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            "Post Listing",
                            style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: label,
      hintStyle: GoogleFonts.montserrat(color: Colors.green[900]?.withValues(alpha: 0.6)),
      prefixIcon: Icon(icon, color: Colors.green[800]),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.green, width: 2)),
    );
  }
}
