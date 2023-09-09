import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

import 'package:locus/services/location_alarm_service/enums.dart';

import 'package:locus/services/location_point_service.dart';

import 'LocationAlarmServiceBase.dart';

enum ProximityLocationAlarmType {
  whenEnter,
  whenLeave,
}

class ProximityLocationAlarm extends LocationAlarmServiceBase {
  // Radius in meters
  final int radius;
  final ProximityLocationAlarmType type;

  const ProximityLocationAlarm({
    required this.radius,
    required this.type,
    required String id,
  }) : super(id);

  @override
  LocationAlarmType get IDENTIFIER => LocationAlarmType.proximityLocation;

  factory ProximityLocationAlarm.fromJSON(
    final Map<String, dynamic> data,
  ) =>
      ProximityLocationAlarm(
        radius: data["radius"],
        type: ProximityLocationAlarmType.values[data["alarmType"]],
        id: data["id"],
      );

  factory ProximityLocationAlarm.create({
    required final int radius,
    required final ProximityLocationAlarmType type,
  }) =>
      ProximityLocationAlarm(
        radius: radius,
        type: type,
        id: uuid.v4(),
      );

  LocationAlarmTriggerType _wasInside(
    final LocationPointService location,
    final LocationPointService userLocation,
  ) {
    final fullDistance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      userLocation.latitude,
      userLocation.longitude,
    );

    if (fullDistance < radius && location.accuracy < radius) {
      return LocationAlarmTriggerType.yes;
    }

    if (fullDistance - location.accuracy - radius > 0) {
      return LocationAlarmTriggerType.no;
    }

    return LocationAlarmTriggerType.maybe;
  }

  @override
  LocationAlarmTriggerType check(
    LocationPointService previousLocation,
    LocationPointService nextLocation, {
    required LocationPointService userLocation,
  }) {
    final previousInside = _wasInside(previousLocation, userLocation);
    final nextInside = _wasInside(nextLocation, userLocation);

    switch (type) {
      case ProximityLocationAlarmType.whenEnter:
        if (previousInside == LocationAlarmTriggerType.no &&
            nextInside == LocationAlarmTriggerType.yes) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.maybe &&
            nextInside == LocationAlarmTriggerType.yes) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.no &&
            nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }

        if (previousInside == LocationAlarmTriggerType.maybe &&
            nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }
        break;
      case ProximityLocationAlarmType.whenLeave:
        if (previousInside == LocationAlarmTriggerType.yes &&
            nextInside == LocationAlarmTriggerType.no) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.maybe &&
            nextInside == LocationAlarmTriggerType.no) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.yes &&
            nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }

        if (previousInside == LocationAlarmTriggerType.maybe &&
            nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }
        break;
    }

    return LocationAlarmTriggerType.no;
  }

  @override
  String createNotificationTitle(AppLocalizations l10n, String viewName) {
    switch (type) {
      case ProximityLocationAlarmType.whenEnter:
        return l10n.locationAlarm_proximityLocation_notificationTitle_whenEnter(
          viewName,
          radius,
        );
      case ProximityLocationAlarmType.whenLeave:
        return l10n.locationAlarm_proximityLocation_notificationTitle_whenLeave(
          viewName,
          radius,
        );
    }
  }

  @override
  Map<String, dynamic> toJSON() {
    return {
      "_IDENTIFIER": IDENTIFIER.name,
      "radius": radius,
      "alarmType": type.index,
      "id": id,
    };
  }
}
