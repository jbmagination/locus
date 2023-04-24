import 'package:enough_platform_widgets/enough_platform_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:locus/api/get-locations.dart';
import 'package:locus/services/view_service.dart';
import 'package:locus/widgets/FillUpPaint.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../constants/spacing.dart';
import '../services/location_point_service.dart';
import '../utils/theme.dart';
import '../widgets/LocationsLoadingScreen.dart';

class LineSliderTickMarkShape extends SliderTickMarkShape {
  final double tickWidth;

  const LineSliderTickMarkShape({
    this.tickWidth = 1.0,
  }) : super();

  @override
  Size getPreferredSize({required SliderThemeData sliderTheme, required bool isEnabled}) {
    // We don't need this
    return Size.zero;
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    // This block is just copied from `slider_theme`
    final bool isTickMarkRightOfThumb = center.dx > thumbCenter.dx;
    final begin =
        isTickMarkRightOfThumb ? sliderTheme.disabledInactiveTickMarkColor : sliderTheme.disabledActiveTickMarkColor;
    final end = isTickMarkRightOfThumb ? sliderTheme.inactiveTickMarkColor : sliderTheme.activeTickMarkColor;
    final Paint paint = Paint()..color = ColorTween(begin: begin, end: end).evaluate(enableAnimation)!;

    final trackHeight = sliderTheme.trackHeight!;

    final rect = Rect.fromCenter(
      center: center,
      width: tickWidth,
      height: trackHeight,
    );

    context.canvas.drawRect(rect, paint);
  }
}

class ViewDetailScreen extends StatefulWidget {
  final TaskView view;

  const ViewDetailScreen({
    required this.view,
    Key? key,
  }) : super(key: key);

  @override
  State<ViewDetailScreen> createState() => _ViewDetailScreenState();
}

class _ViewDetailScreenState extends State<ViewDetailScreen> {
  late final MapController _controller;
  void Function()? _unsubscribeGetLocations;
  final List<LocationPointService> _locations = [];
  bool _isLoading = true;
  bool _isError = false;

  double timeOffset = 0;

  @override
  void initState() {
    super.initState();

    _controller = MapController(
      initMapWithUserPosition: true,
    );
    addListener();
  }

  @override
  void dispose() {
    _controller.dispose();
    _unsubscribeGetLocations?.call();

    super.dispose();
  }

  addListener() async {
    _unsubscribeGetLocations = await getLocations(
      viewPrivateKey: widget.view.viewPrivateKey,
      signPublicKey: widget.view.signPublicKey,
      nostrPublicKey: widget.view.nostrPublicKey,
      relays: widget.view.relays,
      onLocationFetched: (final LocationPointService location) {
        _locations.add(location);
        setState(() {});
      },
      onEnd: () {
        setState(() {
          _isLoading = false;
        });
      },
      onError: () {
        setState(() {
          _isError = true;
        });
      },
    );
  }

  DateTime normalizeDateTime(final DateTime dateTime) => DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
      );

  // Groups the locations by hour and returns a map of the hour and the number of locations in that hour.
  Map<DateTime, List<LocationPointService>> getLocationsPerHour() =>
      _locations.fold({}, (final Map<DateTime, List<LocationPointService>> value, element) {
        final date = normalizeDateTime(element.createdAt);

        if (value.containsKey(date)) {
          value[date]!.add(element);
        } else {
          value[date] = [element];
        }

        return value;
      });

  void drawPoints({final List<LocationPointService>? locations}) {
    final List<LocationPointService> locs = locations ?? _locations;

    _controller.removeAllCircle();

    for (final location in locs) {
      _controller.drawCircle(
        CircleOSM(
          key: "circle_${location.latitude}:${location.longitude}",
          centerPoint: GeoPoint(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
          radius: 200,
          color: Colors.blue,
          strokeWidth: location.accuracy < 10 ? 1 : 3,
        ),
      );
    }
  }

  void goToLocation(final LocationPointService location) {
    _controller.goToLocation(
      GeoPoint(
        latitude: location.latitude,
        longitude: location.longitude,
      ),
    );
    _controller.setZoom(zoomLevel: 15);
  }

  @override
  Widget build(BuildContext context) {
    final locationsPerHour = getLocationsPerHour();
    final locationsAmount = locationsPerHour.values.isEmpty
        ? 1
        : locationsPerHour.values.fold(0, (value, element) => value + element.length);
    final shades = getPrimaryColorShades(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('View Detail'),
        material: (_, __) => MaterialAppBarData(
          centerTitle: true,
        ),
      ),
      body: _isError
          ? Center(
              child: Text(
                "There was an error fetching the locations. Please try again later.",
                style: getBodyTextTextStyle(context).copyWith(
                  color: Colors.red,
                ),
              ),
            )
          : _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(MEDIUM_SPACE),
                  child: LocationsLoadingScreen(
                    locations: _locations,
                  ),
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      flex: 11,
                      child: VisibilityDetector(
                        key: const Key('map'),
                        onVisibilityChanged: (visibility) {
                          // Initial draw
                          if (visibility.visibleFraction == 1) {
                            drawPoints();
                            goToLocation(_locations.last);
                          }
                        },
                        child: OSMFlutter(
                          controller: _controller,
                          initZoom: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(24, (index) => 23 - index).map((hour) {
                          final date = DateTime.now().subtract(Duration(hours: hour));
                          final normalizedDate = normalizeDateTime(date);

                          return PlatformInkWell(
                            onTap: () {
                              _controller.removeAllCircle();

                              if (locationsPerHour[normalizedDate] == null) {
                                return;
                              }

                              drawPoints(
                                locations: locationsPerHour[normalizedDate],
                              );
                              goToLocation(locationsPerHour[normalizedDate]!.last);
                            },
                            child: FillUpPaint(
                              color: shades[0]!,
                              fillPercentage: (locationsPerHour[normalizedDate]?.length ?? 0).toDouble() /
                                  locationsAmount.toDouble(),
                              size: Size(
                                MediaQuery.of(context).size.width / 24,
                                50,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}
