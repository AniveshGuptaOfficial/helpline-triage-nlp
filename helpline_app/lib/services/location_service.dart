import 'package:geolocator/geolocator.dart';

/// Raised when we can't hand back coordinates, carrying copy that is safe to
/// show to the user as-is.
class LocationUnavailable implements Exception {
  final String message;
  const LocationUnavailable(this.message);

  @override
  String toString() => message;
}

/// The one place in the app that asks the device where the user is.
///
/// Used by the chat emergency flow, the Hospitals tab and Profile's
/// "Share Emergency", all of which only ever need coordinates good enough
/// to find nearby hospitals or drop a pin on a map.
///
/// ## Why this deliberately does NOT call `Geolocator.getCurrentPosition()`
///
/// `getCurrentPosition()` opens a live GPS session, and on the way out
/// geolocator tears that session down by calling
/// `LocationManager.removeNmeaListener()` and `unregisterGnssStatusCallback()`
/// (see `NmeaClient.stop()` in geolocator_android). Both are *synchronous*
/// Binder calls into the system location service, and geolocator makes them
/// on Flutter's platform thread - the same thread that hosts the Dart UI
/// isolate.
///
/// If the system side doesn't answer, that thread parks inside
/// `ioctl(BINDER_WRITE_READ)` and never returns. The app then can't build a
/// single frame or dispatch a single touch event, so it freezes solid - the
/// chat stops responding, the "Call 108" button stops working, and Android
/// puts up "helpline_app isn't responding". Choosing "Wait" does nothing,
/// because the thread is blocked rather than busy. Reproduced on an Android
/// 16 emulator: the main thread sat in `binder_ioctl_write_read` at ~1% CPU
/// indefinitely.
///
/// `getLastKnownPosition()` reaches the fused provider's cached fix through
/// `getLastLocation()` and never registers or unregisters those listeners, so
/// there is no blocking Binder call to get stuck behind. It is also
/// instantaneous, which is the right trade-off here anyway: blocking an
/// emergency flow on a cold high-accuracy GPS fix delays the one thing the
/// user actually needs.
///
/// Please don't "improve" this back to `getCurrentPosition()` - it is the
/// only geolocator call that registers and then tears down the NMEA/GNSS
/// listener, so it is the only one that can freeze the entire app.
class LocationService {
  const LocationService._();

  /// Bounds how long we wait on the platform before falling back to the
  /// caller's "no location" UI. Cheap insurance so a slow provider can
  /// never leave a spinner running indefinitely.
  static const Duration _timeout = Duration(seconds: 10);

  /// Returns the user's position, or throws [LocationUnavailable] with a
  /// user-facing reason (services off, permission denied, or no fix cached
  /// on the device yet).
  static Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationUnavailable(
        'Location services are turned off. Please enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(
        'Location permission denied. Please allow location access in your '
        'device settings.',
      );
    }

    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition().timeout(_timeout);
    } catch (_) {
      // Provider error, or it didn't answer within [_timeout]. Handled by
      // the null check below so callers see one consistent failure.
      position = null;
    }

    if (position == null) {
      throw const LocationUnavailable(
        "Couldn't get a location fix yet. Please make sure GPS is on and "
        'try again in a moment.',
      );
    }
    return position;
  }

  /// Best-effort variant for flows that must carry on without coordinates -
  /// e.g. sharing an emergency message, which is still worth sending even if
  /// the location line has to be dropped. Returns null instead of throwing.
  static Future<Position?> tryCurrentPosition() async {
    try {
      return await currentPosition();
    } catch (_) {
      return null;
    }
  }
}
