import 'package:geolocator/geolocator.dart';

class FeedPosition {
  const FeedPosition(this.latitude, this.longitude);
  final double latitude, longitude;
  Map<String, dynamic> get query => {'lat': latitude, 'lng': longitude};
}

/// Location failure never blocks browsing: the API uses profile/city fallback.
class FeedLocationService {
  Future<FeedPosition?> current({bool requestPermission = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse)
        return null;
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
