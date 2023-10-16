/*
 * Copyright 2021-2022 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of esense;

// This is the debug sampling schema used by bardram
// His eSense devices are
//
//        |     name    |     id
//  ------+-------------+--------------------
//  right | eSense-0917 |  00:04:79:00:0F:4D
//  left  | eSense-0332 |  00:04:79:00:0D:04
//
// As recommended;:
//   "it would be better to use the right earbud to record only sound samples
//    and the left earbud to record only IMU data."
//
// Hence, connect the RIGHT earbud to the phone using classic Bluetooth (for
// audio streaming), and use the LEFT earbud for IMU data collection using BLE
// as part of a mobile sensing study.

/// A [DeviceDescriptor] for an eSense device used in a [StudyProtocol].
///
/// **From the eSense User Documentation:**
///
/// Both the left and right earbud have a microphone onboard. The microphone can
/// be used to record audio samples as well as input source for phone or VoIP calls.
///
/// There is no need for special configuration to use the microphone on the earbud.
/// Once the earbud is paired (Bluetooth Classic interface), the host device will
/// recognize the earbud as a new input source. The audio recorded is mono, only
/// from the earbud paired with the host device. The same happens for calls, only
/// the speaker and microphone on the earbud paired with the host will be used
/// during an active call.
///
/// Either the right or left earbud (but not both) can be paired
/// with a host device. If the left earbud is paired, the same host device can
/// also connect to the BLE interface of the earbud to collect IMU data at the
/// same time as audio is recorded from its microphone. The earbuds are limited
/// devices and the achievable data rate of the sensors (microphone and IMU)
/// might be affected by the number of operations performed. For example, if
/// the IMU and the microphone are enabled on the same earbud while the user is
/// also listening to music, it might not be possible to achieve the desired data
/// rate and the music might be interrupted. In this situation it would be better
/// to use the right earbud to record only sound samples and the left earbud to
/// record only IMU data.
@JsonSerializable(fieldRename: FieldRename.none, includeIfNull: false)
class ESenseDevice extends DeviceConfiguration {
  /// The type of an eSense device.
  static const String DEVICE_TYPE =
      '${DeviceConfiguration.DEVICE_NAMESPACE}.ESenseDevice';

  /// The default role name for an eSense device.
  static const String DEFAULT_ROLENAME = 'eSense';

  /// The name of the eSense device.
  /// Used for connecting to the eSense hardware device over BTLE.
  /// eSense devices are typically named `eSense-xxxx`.
  String? deviceName;

  /// The sampling rate in Hz of getting sensor data from the device.
  int samplingRate;

  ESenseDevice({
    super.roleName = ESenseDevice.DEFAULT_ROLENAME,
    super.isOptional = true,
    this.deviceName,
    this.samplingRate = 10,
  });

  @override
  Function get fromJsonFunction => _$ESenseDeviceFromJson;
  factory ESenseDevice.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson(json) as ESenseDevice;
  @override
  Map<String, dynamic> toJson() => _$ESenseDeviceToJson(this);
}

/// A [DeviceManager] for the eSense device.
class ESenseDeviceManager extends BTLEDeviceManager<ESenseDevice> {
  Timer? _batteryTimer;
  StreamSubscription<ESenseEvent>? _batterySubscription;
  double? _voltageLevel;
  final StreamController<int> _batteryEventController =
      StreamController.broadcast();

  /// A handle to the [ESenseManager] plugin.
  ESenseManager? manager;

  @override
  List<Permission> get permissions => [
        Permission.microphone,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

  @override
  String get id => configuration?.deviceName ?? 'eSense-????';

  @override
  String? get displayName => btleName;

  @override
  String get btleName => configuration?.deviceName ?? 'eSense-????';

  /// Set the name of this device based on the Bluetooth name.
  /// This name is used for connecting to the device.
  @override
  set btleName(String btleName) => configuration?.deviceName = btleName;

  /// An estimate of the battery level of the eSense device.
  ///
  /// It assumes a linear relationship based on a regression on
  /// these measures of battery and voltage levels:
  ///
  /// ```
  ///   B  |  V
  ///  ----+------
  ///  1.0	| 4.1
  ///  0.8	| 3.9
  ///  0.6	| 3.8
  ///  0.4	| 3.7
  ///  0.2	| 3.4
  ///  0.0  | 3.1
  /// ```
  ///
  /// which gives; `B = 1.19V - 3.91`.
  ///
  /// See e.g. https://en.wikipedia.org/wiki/State_of_charge#Voltage_method
  @override
  int? get batteryLevel => (_voltageLevel != null)
      ? ((1.19 * _voltageLevel! - 3.91) * 100).toInt()
      : null;

  @override
  Stream<int> get batteryEvents => _batteryEventController.stream;

  ESenseDeviceManager(
    super.type, [
    super.configuration,
  ]);

  @override
  Future<bool> canConnect() async => (configuration?.deviceName != null &&
      configuration!.deviceName!.isNotEmpty);

  @override
  Future<void> onRequestPermissions() async {}

  @override
  void onInitialize(ESenseDevice configuration) {
    if (configuration.deviceName == null || configuration.deviceName!.isEmpty) {
      warning(
          '$runtimeType - cannot connect to eSense device, device name is null.');
    }
    manager = ESenseManager(id);

    super.onInitialize(configuration);
  }

  @override
  Future<DeviceStatus> onConnect() async {
    try {
      // listen for connection events
      manager?.connectionEvents.listen((event) async {
        debug('$runtimeType - $event');

        switch (event.type) {
          case ConnectionType.connected:
            status = DeviceStatus.connected;

            await manager?.setSamplingRate(configuration?.samplingRate ?? 10);

            // when connected, listen for battery events
            _batterySubscription = manager!.eSenseEvents.listen((event) {
              if (event is BatteryRead) {
                _voltageLevel = event.voltage;
                if (batteryLevel != null) {
                  _batteryEventController.add(batteryLevel!);
                }
              }
            });

            // set up a timer that asks for the voltage level
            _batteryTimer = Timer.periodic(const Duration(minutes: 2), (_) {
              if (status == DeviceStatus.connected) {
                manager?.getBatteryVoltage();
              }
            });
            break;
          case ConnectionType.unknown:
            status = DeviceStatus.unknown;
            break;
          case ConnectionType.device_found:
            status = DeviceStatus.connecting;
            break;
          case ConnectionType.device_not_found:
          case ConnectionType.disconnected:
            status = DeviceStatus.disconnected;
            _voltageLevel = null;
            _batteryTimer?.cancel();
            _batterySubscription?.cancel();
            break;
        }
      });

      // try to scan for eSense device and connect to it
      manager?.connect();
    } catch (error) {
      warning(
          '$runtimeType - Error connecting to eSense device id: $id - $error');
      return DeviceStatus.error;
    }

    return DeviceStatus.connecting;
  }

  @override
  Future<bool> onDisconnect() async => await manager?.disconnect() ?? false;
}
