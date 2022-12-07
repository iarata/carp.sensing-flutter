part of carp_context_package;

/// Collects local air quality information using the [AirQuality] plugin.
class AirQualityProbe extends MeasurementProbe {
  @override
  AirQualityServiceManager get deviceManager =>
      super.deviceManager as AirQualityServiceManager;

  @override
  bool onInitialize() {
    LocationManager().configure().then((_) => super.onInitialize());
    return true;
  }

  /// Returns the [AirQualityIndex] based on the location of the phone.
  // ignore: annotate_overrides
  Future<Measurement> getMeasurement() async {
    if (deviceManager.service != null) {
      try {
        final loc = await LocationManager().getLastKnownLocation();
        AirQualityData airQuality = await deviceManager.service!
            .feedFromGeoLocation(loc.latitude!, loc.longitude!);

        return Measurement.fromData(
            AirQualityIndex.fromAirQualityData(airQuality));
      } catch (err) {
        warning('$runtimeType - Error getting air quality - $err');
        return Measurement.fromData(
            Error(message: '$runtimeType Exception: $err'));
      }
    }
    warning(
        '$runtimeType - no service available. Did you remember to add the AirQualityService to the study protocol?');

    return Measurement.fromData(
        Error(message: ('$runtimeType - no service available.')));
  }
}
