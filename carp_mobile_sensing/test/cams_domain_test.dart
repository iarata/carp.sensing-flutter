import 'dart:convert';
import 'dart:io';
import 'package:carp_core/carp_core.dart';
import 'package:carp_mobile_sensing/carp_mobile_sensing.dart';
import 'package:carp_serializable/carp_serializable.dart';

import 'package:test/test.dart';

void main() {
  late SmartphoneStudyProtocol primaryProtocol;
  late Smartphone primaryPhone;
  DeviceConfiguration eSense;

  setUp(() {
    // Initialization of serialization
    CarpMobileSensing();

    // Create a new study protocol.
    primaryProtocol = SmartphoneStudyProtocol(
      ownerId: 'user@dtu.dk',
      name: 'patient_tracking',
      studyDescription: StudyDescription(
        title: 'A Test',
        purpose: 'Testing',
        description: 'A testing protocol',
      ),
      dataEndPoint: SQLiteDataEndPoint(),
    );

    // Define which devices are used for data collection.
    primaryPhone = Smartphone();
    eSense = DeviceConfiguration(roleName: 'esense');

    primaryProtocol
      ..addPrimaryDevice(primaryPhone)
      ..addConnectedDevice(eSense);

    // Define what needs to be measured, on which device, when.
    List<Measure> measures = [
      Measure(type: DataType(NameSpace.CARP, 'light').toString()),
      Measure(type: DataType(NameSpace.CARP, 'gps').toString()),
      Measure(type: DataType(NameSpace.CARP, 'steps').toString()),
    ];

    var task = BackgroundTask(name: 'Start measures')..addMeasures(measures);
    primaryProtocol.addTaskControl(
      TriggerConfiguration(),
      task,
      primaryPhone,
      Control.Start,
    );

    // adding all measure from the sampling packages to one one trigger and one task
    primaryProtocol.addTaskControl(
      ImmediateTrigger(), // a simple trigger that starts immediately
      BackgroundTask()
        ..measures = SamplingPackageRegistry()
            .dataTypes
            .map((type) => Measure(type: type.type))
            .toList(),
      primaryPhone, Control.Start,
    );

    // collect device info only once
    primaryProtocol.addTaskControl(
      OneTimeTrigger(),
      BackgroundTask()
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    var sensingAppTask = AppTask(
      type: BackgroundSensingUserTask.ONE_TIME_SENSING_TYPE,
      title: "Location, Weather & Air Quality",
      description: "Collect location, weather and air quality",
    )..addMeasures([
        Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME),
        Measure(type: CarpDataTypes.STEP_COUNT_TYPE_NAME),
      ]);

    primaryProtocol.addTaskControl(
      ImmediateTrigger(),
      sensingAppTask,
      primaryPhone,
      Control.Start,
    );

    primaryProtocol.addTaskControl(
      UserTaskTrigger(
        taskName: sensingAppTask.name,
        triggerCondition: UserTaskState.done,
      ),
      sensingAppTask,
      primaryPhone,
      Control.Start,
    );

    // adding two measures to another device
    primaryProtocol.addTaskControl(
      ImmediateTrigger(),
      BackgroundTask()
        ..addMeasure(Measure(type: DeviceSamplingPackage.FREE_MEMORY_TYPE_NAME))
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME)),
      eSense,
      Control.Start,
    );
    primaryProtocol.addParticipantRole(ParticipantRole('Participant'));

    primaryProtocol.addExpectedParticipantData(ExpectedParticipantData(
        ParticipantAttribute(inputDataType: 'dk.cachet.carp.sex'),
        AssignedTo(roleNames: {'Participant'})));

    primaryProtocol.addApplicationData('uiTheme', 'black');
  });

  test('DataPoints -> JSON', () async {
    final device = DataPoint.fromData(
        DeviceInformation(platform: 'iOS', deviceId: '1234abcd'));
    print(toJsonString(device));
  });

  test('Measurement -> JSON', () async {
    final device = Measurement.fromData(
        DeviceInformation(platform: 'iOS', deviceId: '1234abcd'));
    print(toJsonString(device));
  });

  test('SmartphoneStudyProtocol -> JSON', () async {
    print(primaryProtocol.applicationData);
    print(toJsonString(primaryProtocol));
    expect(primaryProtocol.ownerId, 'user@dtu.dk');
    expect(primaryProtocol.primaryDevices.length, 1);
    expect(primaryProtocol.connectedDevices?.length, 1);
    expect(primaryProtocol.triggers.length, 7);
    expect(primaryProtocol.triggers.keys.first, '0');
    expect(primaryProtocol.tasks.length, 6);
    expect(primaryProtocol.taskControls.length, 7);
    expect(primaryProtocol.expectedParticipantData?.length, 1);
  });

  test(
      'SmartphoneStudyProtocol -> JSON -> SmartphoneStudyProtocol :: deep assert',
      () async {
    // print('#1 : $primaryProtocol');
    print(toJsonString(primaryProtocol));
    final studyJson = toJsonString(primaryProtocol);

    SmartphoneStudyProtocol protocolFromJson = SmartphoneStudyProtocol.fromJson(
        json.decode(studyJson) as Map<String, dynamic>);
    print(toJsonString(protocolFromJson));
    expect(toJsonString(protocolFromJson), equals(studyJson));
    // print('#2 : $protocolFromJson');
  });

  test('JSON File -> SmartphoneStudyProtocol', () async {
    // Read the study protocol from json file
    String plainJson = File('test/json/study_protocol.json').readAsStringSync();

    SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol.fromJson(
        json.decode(plainJson) as Map<String, dynamic>);

    expect(protocol.ownerId, primaryProtocol.ownerId);
    expect(protocol.primaryDevices.first.roleName,
        SmartphoneDeploymentService().thisPhone.roleName);
    print(toJsonString(protocol));
  });

  test('SmartphoneDeployment -> JSON', () async {
    var deployment = SmartphoneDeployment.fromSmartphoneStudyProtocol(
      studyDeploymentId: '1234',
      primaryDeviceRoleName: 'phone',
      protocol: primaryProtocol,
    );

    print(toJsonString(deployment));
    expect(deployment.deviceConfiguration.roleName, 'phone');
    expect(deployment.connectedDevices.length, 1);
    expect(deployment.triggers.length, 7);
    expect(deployment.triggers.keys.first, '0');
    expect(deployment.tasks.length, 6);
    expect(deployment.taskControls.length, 7);
    expect(deployment.dataEndPoint?.type, DataEndPointTypes.SQLITE);
    expect(deployment.expectedParticipantData.length, 1);
    expect(deployment.getApplicationData('uiTheme'), 'black');
  });

  test('SmartphoneDeployment -> JSON -> SmartphoneDeployment :: deep assert',
      () async {
    var deployment = SmartphoneDeployment.fromSmartphoneStudyProtocol(
      studyDeploymentId: '1234',
      primaryDeviceRoleName: 'phone',
      protocol: primaryProtocol,
    );
    print(toJsonString(deployment));

    final studyJson = toJsonString(deployment);
    SmartphoneDeployment deploymentFromJson = SmartphoneDeployment.fromJson(
        json.decode(studyJson) as Map<String, dynamic>);
    print(toJsonString(deploymentFromJson));
    expect(toJsonString(deploymentFromJson), equals(studyJson));
    // print('#2 : $protocolFromJson');
  });

  test('JSON File -> SmartphoneDeployment', () async {
    // Read the deployment protocol from json file
    String plainJson =
        File('test/json/study_deployment.json').readAsStringSync();

    SmartphoneDeployment deployment = SmartphoneDeployment.fromJson(
        json.decode(plainJson) as Map<String, dynamic>);

    print(toJsonString(deployment));
    expect(deployment.deviceConfiguration.roleName, 'phone');
    expect(deployment.connectedDevices.length, 1);
    expect(deployment.triggers.length, 6);
    expect(deployment.triggers.keys.first, '0');
    expect(deployment.tasks.length, 5);
    expect(deployment.taskControls.length, 6);
    expect(deployment.dataEndPoint?.type, DataEndPointTypes.SQLITE);
    expect(deployment.expectedParticipantData.length, 1);
    expect(deployment.getApplicationData('uiTheme'), 'black');
  });

  test('Triggers -> JSON -> Triggers', () async {
    primaryProtocol.addTaskControl(
      DelayedTrigger(delay: Duration(seconds: 10)),
      BackgroundTask()
        ..addMeasure(Measure(type: CarpDataTypes.STEP_COUNT_TYPE_NAME))
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.SCREEN_EVENT_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    primaryProtocol.addTaskControl(
      PeriodicTrigger(period: const Duration(minutes: 1)), // collect every min.
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME))
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    RecurrentScheduledTrigger t1, t2, t3, t4;

    // collect every day at 13:30.
    t1 = RecurrentScheduledTrigger(
      type: RecurrentType.daily,
      time: TimeOfDay(hour: 21, minute: 30),
      duration: Duration(seconds: 1),
    );
    print('$t1');
    primaryProtocol.addTaskControl(
      t1,
      BackgroundTask()
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.FREE_MEMORY_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    // collect every other day at 13:30.
    t2 = RecurrentScheduledTrigger(
      type: RecurrentType.daily,
      time: TimeOfDay(hour: 13, minute: 30),
      separationCount: 1,
      duration: Duration(seconds: 1),
    );
    print('$t2');
    primaryProtocol.addTaskControl(
      t2,
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME))
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.FREE_MEMORY_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    // collect every wednesday at 12:23.
    t3 = RecurrentScheduledTrigger(
      type: RecurrentType.weekly,
      time: TimeOfDay(hour: 12, minute: 23),
      dayOfWeek: DateTime.wednesday,
      duration: Duration(seconds: 1),
    );
    print('$t3');
    primaryProtocol.addTaskControl(
      t3,
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME))
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.BATTERY_STATE_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    // collect every 2nd monday at 12:23.
    t4 = RecurrentScheduledTrigger(
      type: RecurrentType.weekly,
      time: TimeOfDay(hour: 12, minute: 23),
      dayOfWeek: DateTime.monday,
      separationCount: 1,
      duration: Duration(seconds: 1),
    );
    print('$t4');
    primaryProtocol.addTaskControl(
      t4,
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME))
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.SCREEN_EVENT_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    // when battery level is 10% then sample light
    primaryProtocol.addTaskControl(
      SamplingEventTrigger(
          measureType: DeviceSamplingPackage.BATTERY_STATE_TYPE_NAME,
          triggerCondition: BatteryState(10)),
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    // when the screen is turned off then get device info
    primaryProtocol.addTaskControl(
      SamplingEventTrigger(
          measureType: DeviceSamplingPackage.SCREEN_EVENT_TYPE_NAME,
          triggerCondition: ScreenEvent('SCREEN_OFF')),
      BackgroundTask()
        ..addMeasure(
            Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    primaryProtocol.addTaskControl(
      ConditionalSamplingEventTrigger(
          measureType: DeviceSamplingPackage.BATTERY_STATE_TYPE_NAME,
          triggerCondition: (measurement) =>
              (measurement.data as BatteryState).batteryLevel == 10),
      BackgroundTask()
        ..addMeasure(
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT_TYPE_NAME)),
      primaryPhone,
      Control.Start,
    );

    final studyJson = toJsonString(primaryProtocol);

    print(studyJson);

    SmartphoneStudyProtocol protocol_2 = SmartphoneStudyProtocol.fromJson(
        json.decode(studyJson) as Map<String, dynamic>);
    expect(protocol_2.ownerId, primaryProtocol.ownerId);

    print('#1 : $primaryProtocol');

    SmartphoneStudyProtocol protocolFromJson = SmartphoneStudyProtocol.fromJson(
        json.decode(studyJson) as Map<String, dynamic>);
    expect(toJsonString(protocolFromJson), equals(studyJson));
    print('#2 : $protocolFromJson');
  });

  test('Sampling configurations', () async {
    SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
      ownerId: 'user@dtu.dk',
      name: 'sampling_configurations',
    );

    Smartphone phone = Smartphone();

    phone.defaultSamplingConfiguration!
      ..addAll(DeviceSamplingPackage().samplingSchema.configurations)
      ..addAll(SensorSamplingPackage().samplingSchema.configurations);

    protocol.addPrimaryDevice(phone);

    expect(
        protocol.primaryDevice.defaultSamplingConfiguration?.keys.contains(
            DeviceSamplingPackage().samplingSchema.configurations.keys.first),
        true);
    expect(
        protocol.primaryDevice.defaultSamplingConfiguration?.keys.contains(
            SensorSamplingPackage().samplingSchema.configurations.keys.first),
        true);
    print(toJsonString(protocol));
  });

  test('Register Device', () async {
    StudyDeploymentStatus status_1 = await (SmartphoneDeploymentService()
        .createStudyDeployment(primaryProtocol));
    print(status_1);
    assert(status_1.status == StudyDeploymentStatusTypes.Invited);

    StudyDeploymentStatus status_2 = await (SmartphoneDeploymentService()
        .registerDevice(
            status_1.studyDeploymentId, 'esense', DeviceRegistration()));
    print(status_2);
    assert(status_2.studyDeploymentId == status_1.studyDeploymentId);
    assert(status_2.status == StudyDeploymentStatusTypes.DeployingDevices);
    assert(status_2 == status_1);

    StudyDeploymentStatus status_3 = await SmartphoneDeploymentService()
        .registerDevice(
            status_1.studyDeploymentId, 'nonsense', DeviceRegistration());
    assert(status_3.status == StudyDeploymentStatusTypes.DeployingDevices);
    assert(status_3.studyDeploymentId == status_1.studyDeploymentId);
    print(status_3);
  });

  test('Study Deployment', () async {
    StudyDeploymentStatus status_1 = await SmartphoneDeploymentService()
        .createStudyDeployment(primaryProtocol);

    print(status_1);
    print(toJsonString(status_1));
    // we expect the phone and esense devices
    expect(status_1.deviceStatusList.length, 2);
    expect(status_1.status, StudyDeploymentStatusTypes.Invited);
    expect(status_1.deviceStatusList[0].device.roleName,
        Smartphone.DEFAULT_ROLENAME);
    // the phone as a master device is always registred by the CAMSDeploymentService
    expect(status_1.deviceStatusList[0].status,
        DeviceDeploymentStatusTypes.Registered);
    // but we do not expect the esense device to be registrered (yet)
    expect(status_1.deviceStatusList[1].device.roleName, 'esense');
    expect(status_1.deviceStatusList[1].status,
        DeviceDeploymentStatusTypes.Unregistered);

    StudyDeploymentStatus status_2 = await SmartphoneDeploymentService()
        .registerDevice(
            status_1.studyDeploymentId, 'esense', DeviceRegistration());

    print(status_2);
    print(toJsonString(status_2));
    expect(status_2.studyDeploymentId, status_1.studyDeploymentId);
    expect(status_1.deviceStatusList[1].device.roleName, 'esense');
    // now we expect the esense device to be registred
    expect(status_1.deviceStatusList[1].status,
        DeviceDeploymentStatusTypes.Registered);

    SmartphoneDeployment deployment = await SmartphoneDeploymentService()
        .getDeviceDeployment(status_1.studyDeploymentId);
    print(deployment);
    print(toJsonString(deployment));
    expect(deployment.studyDeploymentId, status_1.studyDeploymentId);
    expect(deployment.tasks.length, primaryProtocol.tasks.length);
    expect(deployment.triggers.length, primaryProtocol.triggers.length);
    expect(deployment.taskControls.length, primaryProtocol.taskControls.length);

    StudyDeploymentStatus status_3 = await SmartphoneDeploymentService()
        .deploymentSuccessful(status_1.studyDeploymentId);
    expect(status_3.status, StudyDeploymentStatusTypes.DeploymentReady);
    expect(status_3.studyDeploymentId, status_1.studyDeploymentId);
    print(status_3);
    print(toJsonString(status_3));
    expect(
      status_3.deviceStatusList[0].status,
      DeviceDeploymentStatusTypes.Deployed,
    );
    expect(
      status_3.deviceStatusList[1].status,
      DeviceDeploymentStatusTypes.Deployed,
    );
  });
}
