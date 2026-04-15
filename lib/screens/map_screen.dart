import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

const Map<String, Map<String, dynamic>> mapStyles = {
  'Clean Map': {
    'base': 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    'overlays': <String>[],
  },
  'Classic Map': {
    'base': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'overlays': <String>[],
  },
  'Satellite': {
    'base': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'overlays': <String>[
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    ],
  },
  'Terrain': {
    'base': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}',
    'overlays': <String>[
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    ],
  },
};

class MapScreen extends StatefulWidget {
  final String locationString;
  final String title;
  final LatLng? exactLocation;

  const MapScreen({
    super.key,
    required this.locationString,
    required this.title,
    this.exactLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _targetLocation;
  bool _isLoading = true;
  String? _error;
  String _currentStyle = 'Clean Map';

  @override
  void initState() {
    super.initState();
    if (widget.exactLocation != null) {
      _targetLocation = widget.exactLocation;
      _isLoading = false;
    } else {
      _geocodeLocation();
    }
  }

  Future<void> _geocodeLocation() async {
    try {
      if (widget.locationString.isEmpty) {
        throw Exception("No location provided.");
      }

      // We attempt to find the coordinates for the string
      List<Location> locations = await locationFromAddress(widget.locationString);
      if (locations.isNotEmpty) {
        if (mounted) {
          setState(() {
            _targetLocation = LatLng(locations.first.latitude, locations.first.longitude);
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Location not found on map.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not find map coordinates for '${widget.locationString}'.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _targetLocation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _error ?? "Unknown error",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _targetLocation!,
            initialZoom: 13.0,
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
            MarkerLayer(
              markers: [
                Marker(
                  point: _targetLocation!,
                  width: 50,
                  height: 50,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 20,
          right: 20,
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
        Positioned(
          bottom: 30,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'btnZoomIn',
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, currentZoom + 1);
                },
                backgroundColor: Colors.white,
                child: Icon(Icons.add, color: Colors.green[800]),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'btnZoomOut',
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, currentZoom - 1);
                },
                backgroundColor: Colors.white,
                child: Icon(Icons.remove, color: Colors.green[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
