import 'package:geolocator/geolocator.dart';

class FeedPosition {
  const FeedPosition(this.latitude, this.longitude);
  final double latitude, longitude;
  Map<String, dynamic> get query => {'lat': latitude, 'lng': longitude};
}

/// Location failure never blocks browsing: the API uses profile/city fallback.
class FeedLocationService {
  /// The phone's last known position: instant, and never asks permission.
  /// Null when there is none or location is not allowed.
  Future<FeedPosition?> lastKnown() async {
    try {
      // A real phone answers at once; never let Home wait on it.
      const limit = Duration(seconds: 1);
      final permission = await Geolocator.checkPermission().timeout(limit);
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getLastKnownPosition().timeout(limit);
      return position == null
          ? null
          : FeedPosition(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Metres between two positions.
  static double distanceBetween(FeedPosition a, FeedPosition b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  Future<FeedPosition?> current({bool requestPermission = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return FeedPosition(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
