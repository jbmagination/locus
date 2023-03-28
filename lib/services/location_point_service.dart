import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:openpgp/openpgp.dart';

class LocationPointService {
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? speedAccuracy;
  final double? heading;
  final double? headingAccuracy;

  LocationPointService({
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.speedAccuracy,
    this.heading,
    this.headingAccuracy,
  });

  static LocationPointService fromJson(Map<String, dynamic> json) {
    return LocationPointService(
      createdAt: DateTime.parse(json["createdAt"]),
      latitude: json["latitude"],
      longitude: json["longitude"],
      altitude: json["altitude"],
      accuracy: json["accuracy"],
      speed: json["speed"],
      speedAccuracy: json["speedAccuracy"],
      heading: json["heading"],
      headingAccuracy: json["headingAccuracy"],
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      "createdAt": createdAt.toIso8601String(),
      "latitude": latitude,
      "longitude": longitude,
      "altitude": altitude,
      "accuracy": accuracy,
      "speed": speed,
      "speedAccuracy": speedAccuracy,
      "heading": heading,
      "headingAccuracy": headingAccuracy,
    };
  }

  Future<String> toEncryptedMessage({
    required final String viewPublicKey,
    required final String signPublicKey,
    required final String signPrivateKey,
  }) async {
    final rawMessage = jsonEncode(toJSON());
    final signedMessage = await OpenPGP.sign(rawMessage, signPublicKey, signPrivateKey, "");
    final content = {
      "message": rawMessage,
      "signature": signedMessage,
    };
    final rawContent = jsonEncode(content);

    return OpenPGP.encrypt(rawContent, viewPublicKey);
  }

  static Future<LocationPointService> createUsingCurrentLocation() async {
    final locationData = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(minutes: 5),
    );

    return LocationPointService(
      createdAt: DateTime.now(),
      latitude: locationData.latitude,
      longitude: locationData.longitude,
      altitude: locationData.altitude,
      accuracy: locationData.accuracy,
      speed: locationData.speed,
      speedAccuracy: locationData.speedAccuracy,
      heading: locationData.heading,
    );
  }

  static Future<LocationPointService> fromEncrypted(
    final String encryptedMessage,
    final String viewPrivateKey,
    final String signPublicKey,
  ) async {
    final rawContent = await OpenPGP.decrypt(
      encryptedMessage,
      viewPrivateKey,
      "",
    );
    final content = jsonDecode(rawContent);
    final message = content["message"];
    final signature = content["signature"];

    final isSignatureValid = await OpenPGP.verify(signature, message, signPublicKey);

    if (!isSignatureValid) {
      throw Exception("Invalid signature");
    }

    return LocationPointService.fromJson(jsonDecode(message));
  }
}
