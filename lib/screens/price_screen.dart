import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/marketplace_service.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import 'add_product_screen.dart';
import 'pricing_admin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SortBy { newest, priceLow, priceHigh }

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = "";
  String _selectedCategory = "All";
  SortBy _sortBy = SortBy.newest;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isAdmin = (doc.data()?['role'] ?? 'user') == 'admin';
        });
      }
    }
  }

  final List<String> _categories = [
    'All',
    'Grains',
    'Vegetables',
    'Fruit',
    'Livestock',
    'Equipment',
    'Fertilizers',
    'Seeds',
    'Other'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            flexibleSpace: const AppGradient(),
            automaticallyImplyLeading: false,
            elevation: 2,
            foregroundColor: Colors.white,
            title: Text(
              "Marketplace",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: "OFFICIAL PRICES"),
                Tab(text: "COMMUNITY MARKET"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildOfficialPrices(),
              _buildCommunityMarket(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
            },
            backgroundColor: Colors.green[800],
            child: const Icon(Icons.add_business_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialPrices() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('market_prices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading data'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.docs;

        return Column(
          children: [
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PricingAdminScreen()),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text("MANAGE OFFICIAL PRICES"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        "No official prices posted yet.",
                        style: GoogleFonts.montserrat(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final doc = data[index];
                        final docData = doc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withValues(alpha: 0.1),
                              child: const Icon(Icons.eco, color: Colors.green),
                            ),
                            title: Text(
                              docData['crop'] ?? 'Unknown crop',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Official Market Rate",
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                                if (docData['updatedAt'] != null)
                                  Text(
                                    "Last updated: ${DateFormat('MMM d, HH:mm').format((docData['updatedAt'] as Timestamp).toDate())}",
                                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              "USD ${docData['price']}/kg",
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityMarket() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _marketplaceService.getProducts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List<Product> products = snapshot.data!;

              // Apply Filters
              if (_selectedCategory != "All") {
                products = products.where((p) => p.category == _selectedCategory).toList();
              }
              if (_searchQuery.isNotEmpty) {
                products = products.where((p) => p.title.toLowerCase().contains(_searchQuery.toLowerCase()) || p.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              // Apply Sorting
              if (_sortBy == SortBy.priceLow) {
                products.sort((a, b) => a.price.compareTo(b.price));
              } else if (_sortBy == SortBy.priceHigh) {
                products.sort((a, b) => b.price.compareTo(a.price));
              } else {
                // Default is newest (Firestore already handles this but local sort ensures it stays correct after filters)
                products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No products listed yet",
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildProductCard(product);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          // Search Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Search products...",
                        hintStyle: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<SortBy>(
                    icon: Icon(Icons.sort_rounded, color: Colors.green[800]),
                    onSelected: (SortBy val) => setState(() => _sortBy = val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: SortBy.newest, child: Text("Newest")),
                      const PopupMenuItem(value: SortBy.priceLow, child: Text("Price: Low to High")),
                      const PopupMenuItem(value: SortBy.priceHigh, child: Text("Price: High to Low")),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Categories Row
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.green[800],
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    showCheckmark: false,
                    onSelected: (val) {
                      setState(() => _selectedCategory = val ? category : "All");
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: product.imageUrls.isNotEmpty
                    ? Image.network(
                        product.imageUrls[0],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "USD ${product.price.toStringAsFixed(2)}",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
