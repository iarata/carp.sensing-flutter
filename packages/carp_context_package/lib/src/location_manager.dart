/*
 * Copyright 2018-2023 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of carp_context_package;

/// A manger that knows how to get location information.
/// Provide access to location data while the app is in the background.
///
/// Use as a singleton:
///
///  `LocationManager()...`
///
/// Note that this [LocationManager] **tries** to handle location permissions
/// during its configuration (via the [configure] method) and the [hasPermission]
/// and [requestPermission] methods.
/// **However**, it is much better - and also recommended by both Apple and
/// Google - to handle permissions on an application level and show the location
/// permission dialogue to the user **before** using probes that depend on location.
///
/// This version of the location manager is based on the [location](https://pub.dev/packages/location)
/// plugin.
class LocationManager {
  static final LocationManager _instance = LocationManager._();
  LocationManager._();

  /// Get the singleton [LocationManager] instance
  factory LocationManager() => _instance;

  Location _lastKnownLocation = Location(latitude: 55.7944, longitude: 12.4463);
  bool _enabled = false, _configuring = false;
  final _provider = location.Location();

  /// Is the location service enabled, which entails that
  ///  * location service is enabled
  ///  * permissions granted
  ///  * configuration is done
  bool get enabled => _enabled;

  /// Is service enabled in background mode?
  Future<bool> isBackgroundModeEnabled() async =>
      await _provider.isBackgroundModeEnabled();

  /// Has the app permission to access location?
  ///
  /// If the result is [PermissionStatus.deniedForever], no dialog will be
  /// shown on [requestPermission].
  Future<location.PermissionStatus> hasPermission() async =>
      await _provider.hasPermission();

  /// Request permissions to access location?
  ///
  /// If the result is [PermissionStatus.deniedForever], no dialog will be
  /// shown on [requestPermission].
  Future<location.PermissionStatus> requestPermission() async =>
      await _provider.requestPermission();

  /// Configures the [LocationManager], incl. sending a notification to the
  /// Android notification system.
  ///
  /// Configuration is done based on the [LocationService]. If not provided,
  /// as set of default configurations are used.
  Future<void> configure([LocationService? configuration]) async {
    // fast out if already enabled or is in the process of configuring
    if (enabled) return;
    if (_configuring) return;

    _configuring = true;
    info('Configuring $runtimeType - configuration: $configuration');

    _enabled = false;

    bool serviceEnabled = await _provider.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _provider.requestService();
      if (!serviceEnabled) {
        warning('$runtimeType - Location service could not be enabled.');
        return;
      }
    }

    if (await _provider.hasPermission() != location.PermissionStatus.granted) {
      warning(
          "$runtimeType - Permission to collect location data 'Always' in the background has not been granted. "
          "Make sure to grant this BEFORE sensing is resumed. "
          "The context sampling package does not handle permissions. This should be handled on the application level.");
      _configuring = false;
      return;
    }

    try {
      await _provider.changeSettings(
        accuracy: location.LocationAccuracy.values[
            configuration?.accuracy.index ??
                GeolocationAccuracy.balanced.index],
        distanceFilter: configuration?.distance ?? 0,
        interval: configuration?.interval.inMilliseconds ?? 1000,
      );

      await _provider.changeNotificationOptions(
          title: configuration?.notificationTitle ?? 'CARP Location Service',
          subtitle: configuration?.notificationMessage ??
              'The location service is running in the background',
          description: configuration?.notificationDescription ??
              'Background location is on to keep the CARP Mobile Sensing app up-to-date with your location. '
                  'This is required for main features to work properly when the app is not in use.',
          onTapBringToFront: configuration?.notificationOnTapBringToFront,
          iconName: configuration?.notificationIconName);
    } catch (error) {
      warning('$runtimeType - Configuration failed - $error');
      return;
    }

    _enabled = true;

    bool backgroundMode = false;
    try {
      backgroundMode = await _provider.enableBackgroundMode();
    } catch (error) {
      warning('$runtimeType - Could not enable background mode - $error');
    }
    info('$runtimeType - configured, background mode enabled: $backgroundMode');
  }

  /// Gets the current location of the phone.
  /// Throws an error if the app has no permission to access location.
  Future<Location> getLocation() async => _lastKnownLocation =
      Location.fromLocationData(await _provider.getLocation());

  /// Get the last known location.
  Future<Location> getLastKnownLocation() async => _lastKnownLocation;

  /// Returns a stream of [Location] objects.
  /// Throws an error if the app has no permission to access location.
  Stream<Location> get onLocationChanged => _provider.onLocationChanged
      .map((location) => Location.fromLocationData(location));
}

/// The precision of the Location. A lower precision will provide a greater
/// battery life.
///
/// This is modelled following [LocationAccuracy](https://pub.dev/documentation/location_platform_interface/latest/location_platform_interface/LocationAccuracy.html)
/// in the location plugin. This is good compromise between the iOS and Android models:
///
///  * iOS [CLLocationAccuracy](https://developer.apple.com/documentation/corelocation/cllocationaccuracy?language=objc)
///  * Android [LocationRequest](https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest)
enum GeolocationAccuracy {
  powerSave,
  low,
  balanced,
  high,
  navigation,
}

/// A manger that knows how to configure and get location.
// /// Provide access to location data while the app is in the background.
// ///
// /// Use as a singleton:
// ///
// ///  `LocationManager()...`
// ///
// /// Note that this [LocationManager] **does not** handle location permissions.
// /// This should be handled and granted on an application level before using
// /// probes that depend on location.
// ///
// /// This version of the location manager is based on the `carp_background_location`
// /// plugin.
// class LocationManager {
//   static final LocationManager _instance = LocationManager._();
//   LocationManager._();

//   /// Get the singleton [LocationManager] instance
//   factory LocationManager() => _instance;

//   Location? _lastKnownLocation;
//   bool _enabled = false, _configuring = false;

//   /// Is the location service enabled, which entails that
//   ///  * location service is enabled
//   ///  * permissions granted
//   ///  * configuration is done
//   bool get enabled => _enabled;

//   // /// Configures the [LocationManager], incl. sending a notification to the
//   /// Android notification system.
//   ///
//   /// Configuration is done based on the [LocationService]. If not provided,
//   /// as set of default configurations are used.
//   Future<void> configure([LocationService? configuration]) async {
//     // fast out if already enabled or is in the process of configuring
//     if (enabled) return;
//     if (_configuring) return;

//     _configuring = true;
//     info('Configuring $runtimeType - configuration: $configuration');

//     _enabled = false;

//     try {
//       cbl.LocationManager().interval = configuration?.interval.inSeconds ?? 30;
//       cbl.LocationManager().distanceFilter = configuration?.distance ?? 0;
//       cbl.LocationManager().accuracy = configuration?.accuracy == null
//           ? cbl.LocationAccuracy.NAVIGATION
//           : configuration?.accuracy == GeolocationAccuracy.powerSave
//               ? cbl.LocationAccuracy.POWERSAVE
//               : configuration?.accuracy == GeolocationAccuracy.low
//                   ? cbl.LocationAccuracy.LOW
//                   : configuration?.accuracy == GeolocationAccuracy.balanced
//                       ? cbl.LocationAccuracy.BALANCED
//                       : configuration?.accuracy == GeolocationAccuracy.high
//                           ? cbl.LocationAccuracy.HIGH
//                           : cbl.LocationAccuracy.NAVIGATION;

//       cbl.LocationManager().notificationTitle =
//           configuration?.notificationMessage ??
//               'The location service is running in the background';
//       cbl.LocationManager().notificationMsg =
//           configuration?.notificationMessage ??
//               'The location service is running in the background';
//     } catch (error) {
//       warning('$runtimeType - Configuration failed - $error');
//       return;
//     }

//     _enabled = true;
//   }

//   /// Gets the current location of the phone.
//   /// Throws an error if the app has no permission to access location.
//   Future<Location> getLocation() async =>
//       _lastKnownLocation = Location.fromLocationDto(
//           await cbl.LocationManager().getCurrentLocation());

//   /// Get the last known location.
//   Future<Location> getLastKnownLocation() async =>
//       _lastKnownLocation ?? await getLocation();

//   /// Returns a stream of [Location] objects.
//   /// Throws an error if the app has no permission to access location.
//   Stream<Location> get onLocationChanged => cbl.LocationManager()
//       .locationStream
//       .map((location) => Location.fromLocationDto(location));
// }
