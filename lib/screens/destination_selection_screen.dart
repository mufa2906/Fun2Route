import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fun2route/theme.dart';

class DestinationSelectionScreen extends StatefulWidget {
  final LatLng initialPosition;
  const DestinationSelectionScreen({super.key, required this.initialPosition});

  @override
  State<DestinationSelectionScreen> createState() => _DestinationSelectionScreenState();
}

class _DestinationSelectionScreenState extends State<DestinationSelectionScreen> {
  LatLng? _selectedPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Tujuan Manual'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.initialPosition, zoom: 15),
            onTap: (pos) => setState(() => _selectedPosition = pos),
            myLocationEnabled: true,
            markers: _selectedPosition != null ? {
              Marker(
                markerId: const MarkerId('dest'), 
                position: _selectedPosition!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              )
            } : {},
          ),
          if (_selectedPosition != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selectedPosition),
                child: const Text('Konfirmasi Tujuan'),
              ),
            )
        ],
      ),
    );
  }
}
