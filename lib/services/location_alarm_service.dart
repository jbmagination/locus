import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'location_point_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const uuid = Uuid();

enum LocationAlarmTriggerType {
  yes,
  no,
  maybe,
}

abstract class LocationAlarmServiceBase {
  final String id;

  String get IDENTIFIER;

  String createNotificationTitle(final AppLocalizations l10n, final String viewName);

  Map<String, dynamic> toJSON();

  // Checks if the alarm should be triggered
  // This function will be called each time the background fetch is updated and there are new locations
  LocationAlarmTriggerType check(final LocationPointService previousLocation, final LocationPointService nextLocation);

  String getStorageKey() => "location_alarm_service:$IDENTIFIER:$id";

  const LocationAlarmServiceBase(this.id);
}

enum RadiusBasedRegionLocationAlarmType {
  whenEnter,
  whenLeave,
}

class RadiusBasedRegionLocationAlarm extends LocationAlarmServiceBase {
  final String zoneName;
  final LatLng center;

  // Radius in meters
  final double radius;
  final RadiusBasedRegionLocationAlarmType type;

  const RadiusBasedRegionLocationAlarm({
    required this.center,
    required this.radius,
    required this.type,
    required this.zoneName,
    required String id,
  }) : super(id);

  String get IDENTIFIER => "radius_based_region";

  factory RadiusBasedRegionLocationAlarm.fromJSON(final Map<String, dynamic> data) => RadiusBasedRegionLocationAlarm(
        center: LatLng(data["center"]["latitude"], data["center"]["longitude"]),
        radius: data["radius"],
        type: RadiusBasedRegionLocationAlarmType.values[data["alarmType"]],
        zoneName: data["zoneName"],
        id: data["id"],
      );

  factory RadiusBasedRegionLocationAlarm.create({
    required final LatLng center,
    required final double radius,
    required final RadiusBasedRegionLocationAlarmType type,
    required final String zoneName,
  }) =>
      RadiusBasedRegionLocationAlarm(
        center: center,
        radius: radius,
        type: type,
        zoneName: zoneName,
        id: uuid.v4(),
      );

  @override
  Map<String, dynamic> toJSON() {
    return {
      "type": IDENTIFIER,
      "center": center.toJson(),
      "radius": radius,
      "zoneName": zoneName,
      "alarmType": type.index,
      "id": id,
    };
  }

  @override
  String createNotificationTitle(final l10n, final viewName) {
    switch (type) {
      case RadiusBasedRegionLocationAlarmType.whenEnter:
        return l10n.locationAlarm_radiusBasedRegion_notificationTitle_whenEnter(viewName, zoneName);
      case RadiusBasedRegionLocationAlarmType.whenLeave:
        return l10n.locationAlarm_radiusBasedRegion_notificationTitle_whenLeave(viewName, zoneName);
    }
  }

  // Checks if a given location was inside. If not, it must be outside
  LocationAlarmTriggerType _wasInside(final LocationPointService location) {
    final fullDistance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      center.latitude,
      center.longitude,
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
  LocationAlarmTriggerType check(final previousLocation, final nextLocation) {
    final previousInside = _wasInside(previousLocation);
    final nextInside = _wasInside(nextLocation);

    switch (type) {
      case RadiusBasedRegionLocationAlarmType.whenEnter:
        if (previousInside == LocationAlarmTriggerType.no && nextInside == LocationAlarmTriggerType.yes) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.maybe && nextInside == LocationAlarmTriggerType.yes) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.no && nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }

        if (previousInside == LocationAlarmTriggerType.maybe && nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }
        break;
      case RadiusBasedRegionLocationAlarmType.whenLeave:
        if (previousInside == LocationAlarmTriggerType.yes && nextInside == LocationAlarmTriggerType.no) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.maybe && nextInside == LocationAlarmTriggerType.no) {
          return LocationAlarmTriggerType.yes;
        }

        if (previousInside == LocationAlarmTriggerType.yes && nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }

        if (previousInside == LocationAlarmTriggerType.maybe && nextInside == LocationAlarmTriggerType.maybe) {
          return LocationAlarmTriggerType.maybe;
        }
        break;
    }

    return LocationAlarmTriggerType.no;
  }
}
