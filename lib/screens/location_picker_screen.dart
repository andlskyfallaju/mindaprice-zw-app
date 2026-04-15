import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import 'map_screen.dart';

class LocationPickerResult {
  final LatLng location;
  final String locationName;

  LocationPickerResult({required this.location, required this.locationName});
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(-17.824858, 31.053028); // Harare default
  bool _isLoading = true;
  bool _isSelecting = false;
  String _currentStyle = 'Clean Map';

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final locService = LocationService();
      final details = await locService.getCurrentLocation();
      if (details != null && mounted) {
        setState(() {
          _currentCenter = LatLng(details.latitude, details.longitude);
        });
      }
    } catch (_) {
      // Fallback to default if permissions denied
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectLocation() async {
    setState(() => _isSelecting = true);
    try {
      final currentPos = _mapController.camera.center;
      
      // Reverse geocode
      List<Placemark> placemarks = await placemarkFromCoordinates(
        currentPos.latitude,
        currentPos.longitude,
      );

      String locationName = "Unknown Location";
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? place.subAdministrativeArea ?? 'Unknown City';
        String country = place.country ?? 'Zimbabwe';
        locationName = "$city, $country";
      }

      if (mounted) {
        Navigator.pop(
          context,
          LocationPickerResult(
            location: currentPos,
            locationName: locationName,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking location: $e")),
        );
        setState(() => _isSelecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Pick Location", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Drag Map to Pinpoint", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchCurrentLocation().then((_) {
                _mapController.move(_currentCenter, 15.0);
              });
            },
            icon: const Icon(Icons.my_location),
            tooltip: "My Location",
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: mapStyles[_currentStyle]!['base'],
                userAgentPackageName: 'com.example.mindaprice_test',
              ),
              ...((mapStyles[_currentStyle]!['overlays'] as List<String>).map((overlayUrl) => 
                 TileLayer(
                   urlTemplate: overlayUrl,
                   userAgentPackageName: 'com.example.mindaprice_test',
                 )
              )),
            ],
          ),
          
          // Center Crosshair
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 50.0), // Offset slightly to pin bottom
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Colors.red,
              ),
            ),
          ),

          // Map Style layer toggle
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentStyle,
                  items: mapStyles.keys.map((String style) {
                    return DropdownMenuItem<String>(
                      value: style,
                      child: Text(style, style: GoogleFonts.montserrat(color: Colors.green[900])),
                    );
                  }).toList(),
                  onChanged: (String? newStyle) {
                    if (newStyle != null) {
                      setState(() => _currentStyle = newStyle);
                    }
                  },
                  iconEnabledColor: Colors.green[800],
                ),
              ),
            ),
          ),

          // Zoom Controls
          Positioned(
            bottom: 120,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'pickZoomIn',
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Colors.green[800]),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'pickZoomOut',
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                  backgroundColor: Colors.white,
                  child: Icon(Icons.remove, color: Colors.green[800]),
                ),
              ],
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isSelecting ? null : _selectLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
              ),
              child: _isSelecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      "Select This Location",
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
