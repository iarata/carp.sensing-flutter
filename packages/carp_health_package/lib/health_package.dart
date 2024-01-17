/*
 * Copyright 2020 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

/// A CAMS sampling package for collecting health information from Apple Health
/// or Google Fit.
/// Is using the [health](https://pub.dev/packages/health) plugin.
/// Can be configured to collect the different [HealthDataType](https://pub.dev/documentation/health/latest/health/HealthDataType-class.html).
library health_package;

import 'dart:async';
import 'dart:io';
import 'package:json_annotation/json_annotation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:carp_serializable/carp_serializable.dart';
import 'package:carp_core/carp_core.dart';
import 'package:carp_mobile_sensing/carp_mobile_sensing.dart';
import 'package:health/health.dart';

part 'health_domain.dart';
part 'health_package.g.dart';
part 'health_probe.dart';
part 'health_services.dart';

/// The health sampling package supports the following overall measure type:
///
///  * `dk.cachet.carp.health`
///
/// In order to specify which health data to collect, a factory method called
/// `getHealthMeasure` can be used.
///
/// An example of a configuration of a study protocol using a health service to
/// collect a set of health data once pr. hours is:
///
/// ```dart
///  final healthService = HealthService(types: healthDataTypes);
///  protocol.addConnectedDevice(healthService, phone);
///
///  protocol.addTaskControl(
///      PeriodicTrigger(period: Duration(minutes: 60)),
///      BackgroundTask(measures: [
///        HealthSamplingPackage.getHealthMeasure([
///          HealthDataType.STEPS,
///          HealthDataType.BASAL_ENERGY_BURNED,
///          HealthDataType.WEIGHT,
///          HealthDataType.SLEEP_SESSION,
///        ])
///      ]),
///      healthService);
/// ```
///
/// To use this package, register it in the [carp_mobile_sensing] package using
///
/// ```
///   SamplingPackageRegistry.register(HealthSamplingPackage());
/// ```
class HealthSamplingPackage extends SmartphoneSamplingPackage {
  static const String HEALTH_NAMESPACE = "${NameSpace.CARP}.health";

  /// Generic measure type for collection of health data from Apple Health or
  /// Google Health Connect.
  ///  * One-time measure.
  ///  * Uses the [HealthService] device for data collection.
  ///  * Use a [HealthSamplingConfiguration] for sampling configuration.
  ///
  /// Use [getHealthMeasure] to get specific health measure
  /// type to collect.
  static const String HEALTH = HEALTH_NAMESPACE;

  /// Returns a health measure for the specified list of health data [types].
  /// Data will be collected [days] days back in time. If not specified,
  /// data will be collected for the last 30 days, which is the maximum
  /// that Google Health Connect allow.
  static Measure getHealthMeasure(List<HealthDataType> types,
          [int days = 30]) =>
      Measure(type: HealthSamplingPackage.HEALTH)
        ..overrideSamplingConfiguration = HealthSamplingConfiguration(
            past: Duration(days: days), healthDataTypes: types);

  final _deviceManager = HealthServiceManager();

  @override
  DataTypeSamplingSchemeMap get samplingSchemes =>
      DataTypeSamplingSchemeMap.from([
        DataTypeSamplingScheme(
            DataTypeMetaData(
              type: HEALTH,
              displayName: "Health Data",
              timeType: DataTimeType.TIME_SPAN,
            ),
            HealthSamplingConfiguration(
                past: Duration(days: 30),
                healthDataTypes: [HealthDataType.STEPS]))
      ]);

  @override
  Probe? create(String type) => type == HEALTH ? HealthProbe() : null;

  @override
  void onRegister() {
    FromJsonFactory().registerAll([
      HealthService(),
      HealthSamplingConfiguration(healthDataTypes: []),
    ]);
  }

  @override
  List<Permission> get permissions => [];

  @override
  String get deviceType => HealthService.DEVICE_TYPE;

  @override
  DeviceManager get deviceManager => _deviceManager;
}

/// Data types available on iOS.
const List<HealthDataType> dataTypesIOS = [
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.AUDIOGRAM,
  HealthDataType.BASAL_ENERGY_BURNED,
  HealthDataType.BLOOD_GLUCOSE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.DIETARY_CARBS_CONSUMED,
  HealthDataType.DIETARY_ENERGY_CONSUMED,
  HealthDataType.DIETARY_FATS_CONSUMED,
  HealthDataType.DIETARY_PROTEIN_CONSUMED,
  HealthDataType.ELECTRODERMAL_ACTIVITY,
  HealthDataType.FORCED_EXPIRATORY_VOLUME,
  HealthDataType.HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  HealthDataType.HEIGHT,
  HealthDataType.HIGH_HEART_RATE_EVENT,
  HealthDataType.RESPIRATORY_RATE,
  HealthDataType.PERIPHERAL_PERFUSION_INDEX,
  HealthDataType.IRREGULAR_HEART_RATE_EVENT,
  HealthDataType.LOW_HEART_RATE_EVENT,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.WAIST_CIRCUMFERENCE,
  HealthDataType.WALKING_HEART_RATE,
  HealthDataType.WEIGHT,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.DISTANCE_WALKING_RUNNING,
  HealthDataType.MINDFULNESS,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
  HealthDataType.WATER,
  HealthDataType.EXERCISE_TIME,
  HealthDataType.WORKOUT,
  HealthDataType.HEADACHE_NOT_PRESENT,
  HealthDataType.HEADACHE_MILD,
  HealthDataType.HEADACHE_MODERATE,
  HealthDataType.HEADACHE_SEVERE,
  HealthDataType.HEADACHE_UNSPECIFIED,
  HealthDataType.AUDIOGRAM,
  HealthDataType.ELECTROCARDIOGRAM,
  HealthDataType.NUTRITION,
];

/// Data types available on Android.
///
/// Note that these are only the ones supported in Android's Health Connect API.
const List<HealthDataType> dataTypesAndroid = [
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.BASAL_ENERGY_BURNED,
  HealthDataType.BLOOD_GLUCOSE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.HEIGHT,
  HealthDataType.WEIGHT,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.DISTANCE_DELTA,
  HealthDataType.RESPIRATORY_RATE,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.WATER,
  HealthDataType.WORKOUT,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.NUTRITION,
];
