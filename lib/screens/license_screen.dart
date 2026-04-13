import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final Map<String, List<LicenseEntry>> _packageToLicenses = {};
  final List<String> _sortedPackages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    await for (final license in LicenseRegistry.licenses) {
      for (final package in license.packages) {
        if (!_packageToLicenses.containsKey(package)) {
          _packageToLicenses[package] = [];
        }
        _packageToLicenses[package]!.add(license);
      }
    }

    if (mounted) {
      setState(() {
        _sortedPackages.clear();
        _sortedPackages.addAll(_packageToLicenses.keys);
        _sortedPackages.sort();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            "Licenses",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _sortedPackages.length,
                itemBuilder: (context, index) {
                  final packageName = _sortedPackages[index];
                  final licenses = _packageToLicenses[packageName]!;
                  
                  return Card(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        packageName,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        "${licenses.length} ${licenses.length == 1 ? 'license' : 'licenses'}",
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LicenseDetailScreen(
                              packageName: packageName,
                              licenses: licenses,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class LicenseDetailScreen extends StatelessWidget {
  final String packageName;
  final List<LicenseEntry> licenses;

  const LicenseDetailScreen({
    super.key,
    required this.packageName,
    required this.licenses,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            packageName,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            return Card(
              color: Theme.of(context).cardColor.withValues(alpha: 0.95),
              margin: const EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (licenses.length > 1) ...[
                      Text(
                        "License ${index + 1}",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const Divider(),
                    ],
                    Text(
                      license.paragraphs.map((p) => p.text).join('\n\n'),
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
