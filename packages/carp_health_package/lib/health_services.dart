/*
 * Copyright 2024 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of health_package;

/// An [OnlineService] for the [health](https://pub.dev/packages/health) service.
///
/// On Android, this health package always uses Google [Health Connect](https://developer.android.com/health-and-fitness/guides/health-connect).
@JsonSerializable(fieldRename: FieldRename.none, includeIfNull: false)
class HealthService extends OnlineService {
  /// The type of the health service.
  static const String DEVICE_TYPE =
      '${DeviceConfiguration.DEVICE_NAMESPACE}.HealthService';

  /// The default role name for a health service.
  static const String DEFAULT_ROLE_NAME = 'Health Service';

  /// Create a new [HealthService] with a default role name, if not specified.
  HealthService({super.roleName = HealthService.DEFAULT_ROLE_NAME});

  @override
  Function get fromJsonFunction => _$HealthServiceFromJson;
  factory HealthService.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson(json) as HealthService;
  @override
  Map<String, dynamic> toJson() => _$HealthServiceToJson(this);
}

/// A [DeviceManager] for the [HealthService].
class HealthServiceManager extends OnlineServiceManager<HealthService> {
  HealthFactory? _service;

  /// A handle to the [HealthFactory] plugin.
  /// Returns null if the service is not configured.
  HealthFactory? get service => (configuration != null)
      ? _service ??= HealthFactory(useHealthConnectIfAvailable: true)
      : null;

  @override
  String get id => (configuration != null)
      ? (Platform.isIOS)
          ? "Apple Health"
          : "Google Health Connect"
      : 'N/A';

  @override
  String? get displayName => 'Health Service';

  @override
  List<Permission> get permissions => [];

  /// Which health data types should this service access.
  List<HealthDataType>? types;

  HealthServiceManager([
    HealthService? configuration,
  ]) : super(HealthService.DEVICE_TYPE, configuration);

  @override
  // ignore: avoid_renaming_method_parameters
  void onInitialize(HealthService service) {
    // TODO - Populate [types] based on what is actually in the protocol and not just "everything", as done below.
    types = Platform.isIOS ? dataTypesIOS : dataTypesAndroid;

    if (Platform.isAndroid) {
      var sdkLevel = int.parse(DeviceInfo().sdk ?? '-1');
      if (sdkLevel < 34) {
        warning(
            '$runtimeType - Trying to use Google Health Connect on a phone with SDK level < 34 (SDK is $sdkLevel). '
            'In order to use Health Connect on this phone, you need to install Health Connect as a separate app. '
            'Please read more about Health Connect at https://developer.android.com/health-and-fitness/guides/health-connect/develop/get-started');
      }
    }
  }

  @override
  Future<bool> onHasPermissions() async {
    if (types != null) {
      try {
        await service?.hasPermissions(types!);
      } catch (error) {
        warning('$runtimeType - Error getting permission status - $error');
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> onRequestPermissions() async {
    if (types != null) {
      try {
        await service?.requestAuthorization(types!);
      } catch (error) {
        warning('$runtimeType - Error requesting permissions - $error');
      }
    }
  }

  @override
  Future<bool> canConnect() async => true;

  @override
  Future<DeviceStatus> onConnect() async => DeviceStatus.connected;

  @override
  Future<bool> onDisconnect() async => true;
}
