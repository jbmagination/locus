import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:locus/services/location_point_service.dart';
import "package:latlong2/latlong.dart";
import 'package:locus/services/view_service.dart';
import 'package:simple_shadow/simple_shadow.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as AppleMaps;

import '../../utils/theme.dart';
import 'constants.dart';

class OutOfBoundMarker extends StatefulWidget {
  final TaskView view;
  final LocationPointService lastViewLocation;
  final VoidCallback onTap;

  final MapController? flutterMapController;
  final AppleMaps.AppleMapController? appleMapController;

  // Stream that tells when to update
  final Stream<MapEventWithMove> updateStream;

  const OutOfBoundMarker({
    required this.onTap,
    required this.view,
    required this.lastViewLocation,
    required this.updateStream,
    this.flutterMapController,
    this.appleMapController,
    super.key,
  });

  @override
  State<OutOfBoundMarker> createState() => _OutOfBoundMarkerState();
}

class _OutOfBoundMarkerState extends State<OutOfBoundMarker>
    with WidgetsBindingObserver {
  late final StreamSubscription<void> _updateSubscription;

  // Instead of using `MediaQuery.of(context).size`, we use a variable to store
  // the computed variable, for better performance
  Size size = const Size(0, 0);
  double xAvailablePercentage = 0;
  double yAvailablePercentage = 0;
  double width = 0;
  double height = 0;

  // Optimizing this by using only a certain amount of decimals doesn't work
  double x = 0;
  double y = 0;
  double rotation = 0;
  double totalDiff = 0;

  @override
  void initState() {
    super.initState();

    _updateSubscription = widget.updateStream.listen((event) {
      updatePosition();
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSizes();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription.cancel();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSizes();
    });
  }

  void _updateSizes() {
    final size = MediaQuery.of(context).size;
    final availableWidth = size.width - OUT_OF_BOUND_MARKER_X_PADDING;
    final availableHeight = size.height - OUT_OF_BOUND_MARKER_Y_PADDING;

    setState(() {
      this.size = size;
      xAvailablePercentage = availableWidth / size.width;
      yAvailablePercentage = availableHeight / size.height;
    });
  }

  void updatePosition() async {
    final bounds = await getBounds();
    final north = bounds[0];
    final east = bounds[1];
    final south = bounds[2];
    final west = bounds[3];

    final xPercentage =
        ((widget.lastViewLocation.longitude - west) / (east - west))
            .clamp(1 - xAvailablePercentage, xAvailablePercentage);
    final yPercentage =
        ((widget.lastViewLocation.latitude - north) / (south - north))
            .clamp(1 - yAvailablePercentage, yAvailablePercentage);

    // Calculate the rotation between marker and last location
    final markerLongitude = west + xPercentage * (east - west);
    final markerLatitude = north + yPercentage * (south - north);

    final diffLongitude = widget.lastViewLocation.longitude - markerLongitude;
    final diffLatitude = widget.lastViewLocation.latitude - markerLatitude;

    final rotation = atan2(diffLongitude, diffLatitude) + pi;

    final totalDiff = Geolocator.distanceBetween(
      widget.lastViewLocation.latitude,
      widget.lastViewLocation.longitude,
      markerLatitude,
      markerLongitude,
    ).roundToDouble();

    final bottomRightMapActionsHeight = size.width - (FAB_SIZE + FAB_MARGIN);
    final width =
        size.width - OUT_OF_BOUND_MARKER_X_PADDING - OUT_OF_BOUND_MARKER_SIZE;
    final height = xPercentage * size.width > bottomRightMapActionsHeight
        ? size.height - (FAB_SIZE + FAB_MARGIN) * 3
        : size.height - OUT_OF_BOUND_MARKER_Y_PADDING;

    setState(() {
      x = xPercentage * width;
      y = yPercentage * height;
      this.rotation = rotation;
      this.totalDiff = totalDiff;
    });
  }

  Future<List<double>> getBounds() async {
    if (widget.flutterMapController != null) {
      final bounds = widget.flutterMapController!.bounds!;

      return [
        bounds.north,
        bounds.east,
        bounds.south,
        bounds.west,
      ];
    }

    if (widget.appleMapController != null) {
      final bounds = await widget.appleMapController!.getVisibleRegion();

      return [
        bounds.northeast.latitude,
        bounds.northeast.longitude,
        bounds.southwest.latitude,
        bounds.southwest.longitude,
      ];
    }

    throw Exception('No map controller found');
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: (1000000 / totalDiff).clamp(0.2, 1),
        child: Transform.rotate(
          angle: rotation,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Stack(
              children: [
                SimpleShadow(
                  opacity: .4,
                  sigma: 2,
                  color: Colors.black,
                  // Calculate offset based of rotation, shadow should always show down
                  offset: Offset(
                    sin(rotation) * 4,
                    cos(rotation) * 4,
                  ),
                  child: SizedBox.square(
                    dimension: OUT_OF_BOUND_MARKER_SIZE.toDouble(),
                    child: SvgPicture.asset(
                      "assets/location-out-of-bounds-marker.svg",
                      width: OUT_OF_BOUND_MARKER_SIZE.toDouble(),
                      height: OUT_OF_BOUND_MARKER_SIZE.toDouble(),
                      colorFilter: ColorFilter.mode(
                        getSheetColor(context),
                        BlendMode.srcATop,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: OUT_OF_BOUND_MARKER_SIZE / 2 - 40 / 2,
                  top: 3,
                  child: Icon(
                    Icons.circle_rounded,
                    size: 40,
                    color: widget.view.color,
                  ),
                ),
                Positioned(
                  left: OUT_OF_BOUND_MARKER_SIZE / 2 - 30 / 2,
                  top: 7.5,
                  child: Transform.rotate(
                    angle: -rotation,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 30,
                      color: getSheetColor(context),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
