import 'package:battery_plus/battery_plus.dart';
import 'package:enough_platform_widgets/enough_platform_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:locus/constants/spacing.dart';
import 'package:locus/services/location_point_service.dart';
import 'package:locus/utils/theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocationDetails extends StatefulWidget {
  final LocationPointService location;
  final bool isPreview;

  const LocationDetails({
    required this.location,
    required this.isPreview,
    Key? key,
  }) : super(key: key);

  @override
  State<LocationDetails> createState() => _LocationDetailsState();
}

class _LocationDetailsState extends State<LocationDetails> {
  bool isOpened = false;

  String get formattedString =>
      "${widget.location.latitude.toStringAsFixed(5)}, ${widget.location.longitude.toStringAsFixed(5)}";

  Map<BatteryState?, String> getBatteryStateTextMap() {
    final l10n = AppLocalizations.of(context);

    return {
      BatteryState.charging:
          l10n.taskDetails_locationDetails_batteryState_charging,
      BatteryState.discharging:
          l10n.taskDetails_locationDetails_batteryState_discharging,
      BatteryState.full: l10n.taskDetails_locationDetails_batteryState_full,
      BatteryState.unknown:
          l10n.taskDetails_locationDetails_batteryState_unknown,
      null: l10n.taskDetails_locationDetails_batteryState_unknown,
    };
  }

  IconData getIconForBatteryLevel(final double? level) {
    if (isCupertino(context)) {
      if (level == null) {
        return CupertinoIcons.battery_full;
      }

      if (level > 0.9) {
        return CupertinoIcons.battery_100;
      } else if (level > 0.25) {
        return CupertinoIcons.battery_25;
      } else {
        return CupertinoIcons.battery_0;
      }
    }

    if (level == null) {
      return Icons.battery_unknown_rounded;
    }

    if (level == 1) {
      return Icons.battery_full;
    } else if (level >= .83) {
      return Icons.battery_6_bar_rounded;
    } else if (level >= .67) {
      return Icons.battery_5_bar_rounded;
    } else if (level >= .5) {
      return Icons.battery_4_bar_rounded;
    } else if (level >= .33) {
      return Icons.battery_3_bar_rounded;
    } else if (level >= .17) {
      return Icons.battery_2_bar_rounded;
    } else if (level >= .05) {
      return Icons.battery_1_bar_rounded;
    } else {
      return Icons.battery_0_bar_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlatformTextButton(
          onPressed: widget.isPreview
              ? null
              : () {
                  setState(() {
                    isOpened = !isOpened;
                  });
                },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              formattedString,
              textAlign: TextAlign.start,
              style: getBodyTextTextStyle(context),
            ),
          ),
        ),
        isOpened
            ? Container(
                decoration: BoxDecoration(
                  color: platformThemeData(
                    context,
                    material: (data) => data.scaffoldBackgroundColor,
                    cupertino: (data) => data.scaffoldBackgroundColor,
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(MEDIUM_SPACE),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    PlatformListTile(
                      title: Text(
                        l10n.taskDetails_locationDetails_createdAt_value(
                          widget.location.createdAt,
                        ),
                      ),
                      subtitle: Text(
                        l10n.taskDetails_locationDetails_createdAt_label,
                      ),
                      leading: Icon(context.platformIcons.time),
                      trailing: SizedBox.shrink(),
                    ),
                    PlatformListTile(
                      title: Text(
                        l10n.taskDetails_locationDetails_accuracy_value(
                          widget.location.accuracy.round(),
                        ),
                      ),
                      subtitle:
                          Text(l10n.taskDetails_locationDetails_accuracy_label),
                      leading: Icon(Icons.location_on),
                      trailing: SizedBox.shrink(),
                    ),
                    PlatformListTile(
                      title: Text(
                        widget.location.batteryLevel == null
                            ? l10n.unknownValue
                            : l10n.taskDetails_locationDetails_battery_value(
                                (widget.location.batteryLevel! * 100).floor(),
                              ),
                      ),
                      subtitle:
                          Text(l10n.taskDetails_locationDetails_battery_label),
                      leading: Icon(
                        getIconForBatteryLevel(
                          widget.location.batteryLevel,
                        ),
                      ),
                      trailing: SizedBox.shrink(),
                    ),
                    PlatformListTile(
                      title: Text(
                        getBatteryStateTextMap()[widget.location.batteryState]!,
                      ),
                      subtitle: Text(
                        l10n.taskDetails_locationDetails_batteryState_label,
                      ),
                      leading: Icon(Icons.cable_rounded),
                      trailing: SizedBox.shrink(),
                    ),
                    PlatformListTile(
                      title: Text(
                        widget.location.speed == null
                            ? l10n.unknownValue
                            : l10n.taskDetails_locationDetails_speed_value(
                                widget.location.speed!.toInt().abs(),
                              ),
                      ),
                      subtitle: Text(
                        l10n.taskDetails_locationDetails_speed_label,
                      ),
                      leading: PlatformWidget(
                        material: (_, __) => Icon(Icons.speed),
                        cupertino: (_, __) => Icon(CupertinoIcons.speedometer),
                      ),
                      trailing: SizedBox.shrink(),
                    ),
                    PlatformListTile(
                      title: Text(
                        widget.location.altitude == null
                            ? l10n.unknownValue
                            : l10n.taskDetails_locationDetails_altitude_value(
                                widget.location.altitude!.toInt().abs(),
                              ),
                      ),
                      subtitle:
                          Text(l10n.taskDetails_locationDetails_altitude_label),
                      leading: PlatformWidget(
                        material: (_, __) => Icon(Icons.height_rounded),
                        cupertino: (_, __) => Icon(CupertinoIcons.alt),
                      ),
                      trailing: SizedBox.shrink(),
                    ),
                  ],
                ),
              )
            : SizedBox.shrink(),
      ],
    );
  }
}