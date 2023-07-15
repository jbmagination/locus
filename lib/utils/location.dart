import 'dart:async';

import 'package:flutter_logs/flutter_logs.dart';
import 'package:geolocator/geolocator.dart';
import 'package:locus/constants/values.dart';
import "package:latlong2/latlong.dart";

enum LocationMethod {
  best,
  worst,
  androidLocationManagerBest,
  androidLocationManagerWorst,
}

const TIMEOUT_DURATION = Duration(minutes: 1);

Future<Position?> _getLocationUsingMethod(
  final LocationMethod method, [
  final Duration timeout = TIMEOUT_DURATION,
]) async {
  FlutterLogs.logInfo(
    LOG_TAG,
    "Get Location",
    "Getting location using method: $method",
  );

  try {
    switch (method) {
      case LocationMethod.best:
        final result = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          forceAndroidLocationManager: false,
          timeLimit: timeout,
        );
        return result;
      case LocationMethod.worst:
        final result = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.lowest,
          forceAndroidLocationManager: false,
          timeLimit: timeout,
        );
        return result;
      case LocationMethod.androidLocationManagerBest:
        final result = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          forceAndroidLocationManager: true,
          timeLimit: timeout,
        );
        return result;
      case LocationMethod.androidLocationManagerWorst:
        final result = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          forceAndroidLocationManager: true,
          timeLimit: timeout,
        );
        return result;
    }
  } catch (error) {
    FlutterLogs.logError(
      LOG_TAG,
      "Get Location",
      "Error getting location using method $method: $error",
    );
    return null;
  }
}

Future<Position> getCurrentPosition({
  final void Function(LocationMethod)? onMethodCheck,
  final List<Duration> timeouts = const [
    Duration(seconds: 5),
    TIMEOUT_DURATION,
    Duration(minutes: 3)
  ],
}) async {
  for (final timeout in timeouts) {
    for (final method in LocationMethod.values) {
      onMethodCheck?.call(method);

      final position = await _getLocationUsingMethod(method, timeout);
      if (position != null) {
        return position;
      }
    }
  }

  throw Exception("Could not get location");
}

Stream<Position> getLastAndCurrentPosition({
  final bool updateLocation = false,
}) {
  final controller = StreamController<Position>.broadcast();

  Geolocator.getLastKnownPosition().then((position) {
    if (position != null) {
      controller.add(position);
    }
  });

  getCurrentPosition().then((position) {
    controller.add(position);
  });

  if (updateLocation) {
    final positionStream = Geolocator.getPositionStream().listen((position) {
      controller.add(position);
    });

    controller.onCancel = () {
      positionStream.cancel();
    };
  }

  return controller.stream;
}

String formatRawAddress(final LatLng location) =>
    "${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}";
