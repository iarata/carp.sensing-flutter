part of health_package;

String enumToString(dynamic enumeration) =>
    enumeration.toString().split('.').last;

/// Diet, Alcohol, Smoking, Exercise, Sleep (DASES) data types.
enum DasesHealthDataType {
  /// Number of calories consumed.
  CALORIES_INTAKE,

  /// Units of alcohol.
  ALCOHOL,

  /// Blood alcohol content in percentage.
  BLOOD_ALCOHOL_CONTENT,

  /// Number of smoked cigarettes.
  SMOKED_CIGARETTES,

  /// Number of smoked other thing (pipe, cigar, ...).
  SMOKED_OTHER,

  /// Duration of exercise.
  EXERCISE,

  /// Duration of sleep.
  SLEEP,
}

/// Map a [DasesHealthDataType] to a [HealthDataUnit].
const Map<DasesHealthDataType, HealthDataUnit> dasesDataTypeToUnit = {
  DasesHealthDataType.CALORIES_INTAKE: HealthDataUnit.KILOCALORIE,
  DasesHealthDataType.ALCOHOL: HealthDataUnit.COUNT,
  DasesHealthDataType.BLOOD_ALCOHOL_CONTENT: HealthDataUnit.PERCENT,
  DasesHealthDataType.SMOKED_CIGARETTES: HealthDataUnit.COUNT,
  DasesHealthDataType.SMOKED_OTHER: HealthDataUnit.COUNT,
  DasesHealthDataType.EXERCISE: HealthDataUnit.NO_UNIT,
  DasesHealthDataType.SLEEP: HealthDataUnit.NO_UNIT,
};

/// Specify the configuration on how to collect health data.
///
/// The [healthDataTypes] parameter specifies which [HealthDataType]
/// to collect.
@JsonSerializable(fieldRename: FieldRename.none, includeIfNull: false)
class HealthSamplingConfiguration extends HistoricSamplingConfiguration {
  /// The list of [HealthDataType] to collect.
  List<HealthDataType> healthDataTypes;

  HealthSamplingConfiguration({super.past, required this.healthDataTypes});

  @override
  Function get fromJsonFunction => _$HealthSamplingConfigurationFromJson;

  @override
  Map<String, dynamic> toJson() => _$HealthSamplingConfigurationToJson(this);

  factory HealthSamplingConfiguration.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson(json) as HealthSamplingConfiguration;
}

/// A no-op function for deserializing a HealthValue - never used.
HealthValue _healthValueFromJson(json) => NumericHealthValue(-1);

/// A [Data] object that holds health data from a [HealthDataPoint].
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class HealthData extends Data {
  /// The value of the health data.
  @JsonKey(fromJson: _healthValueFromJson)
  HealthValue value;

  /// Unit of health data.
  ///
  /// Note that the uppercase version is used, e.g. `COUNT` in the case of step counts.
  String unit;

  /// Start date-time for this health data.
  DateTime dateFrom;

  /// End date-time for this health data.
  DateTime dateTo;

  /// The type of health data -- see [HealthDataType](https://pub.dev/documentation/health/latest/health/HealthDataType-class.html).
  ///
  /// Note that the uppercase version is used, e.g. `STEPS`.
  String dataType;

  /// The platform from which this health data point came from (ANDROID, IOS).
  String platform;

  /// The device id of the phone.
  String deviceId;

  /// The unique UUID of the data point.
  String uuid;

  /// Create a [HealthData] object.
  HealthData(
    this.value,
    this.unit,
    this.dataType,
    this.dateFrom,
    this.dateTo,
    this.platform,
    this.deviceId,
    this.uuid,
  ) : super();

  /// Create a [HealthData] from a [HealthDataPoint] health data object.
  factory HealthData.fromHealthDataPoint(HealthDataPoint healthDataPoint) {
    String uuid =
        Uuid().v5(Uuid.NAMESPACE_URL, healthDataPoint.toJson().toString());
    return HealthData(
      healthDataPoint.value,
      healthDataPoint.unitString,
      healthDataPoint.typeString,
      healthDataPoint.dateFrom,
      healthDataPoint.dateTo,
      enumToString(healthDataPoint.platform),
      healthDataPoint.deviceId,
      uuid,
    );
  }

  factory HealthData.fromJson(Map<String, dynamic> json) =>
      _$HealthDataFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$HealthDataToJson(this);

  /// The json type of this health data is `dk.cachet.carp.health.<healthdatatype>`,
  /// where `<healthdatatype>` is the lowercase version of the [HealthDataType].
  @override
  String get jsonType =>
      '${HealthSamplingPackage.HEALTH}.${dataType.toLowerCase()}';

  @override
  String toString() => '${super.toString()}'
      ', dataType: $dataType'
      ', platform: $platform'
      ', value: $value'
      ', unit: $unit'
      ', dateFrom: $dateFrom'
      ', dateTo: $dateTo';
}
