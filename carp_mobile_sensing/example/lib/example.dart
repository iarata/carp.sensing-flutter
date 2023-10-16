/*
 * Copyright 2019-2023 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

import 'dart:async';
import 'dart:convert';

import 'package:carp_core/carp_core.dart';
import 'package:carp_mobile_sensing/carp_mobile_sensing.dart';
import 'package:carp_serializable/carp_serializable.dart';
import 'package:iso_duration_parser/iso_duration_parser.dart';

/// This is an example of how to set up a the most minimal study.
/// Used in the README file.
Future<void> minimalExample() async {
  // Create a protocol.
  final phone = Smartphone();
  final protocol = SmartphoneStudyProtocol(
    ownerId: 'AB',
    name: 'Tracking steps, light, screen, and battery',
    dataEndPoint: SQLiteDataEndPoint(),
  )
    ..addPrimaryDevice(phone)
    ..addTaskControl(
      DelayedTrigger(delay: const Duration(seconds: 10)),
      BackgroundTask(measures: [
        Measure(type: SensorSamplingPackage.STEP_COUNT),
        Measure(type: SensorSamplingPackage.AMBIENT_LIGHT),
        Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
        Measure(type: DeviceSamplingPackage.BATTERY_STATE),
      ]),
      phone,
      Control.Start,
    );

  // Create and configure a client manager for this phone.
  await SmartPhoneClientManager().configure();

  // Create a study based on the protocol.
  SmartPhoneClientManager().addStudyProtocol(protocol);

  /// Start sampling.
  SmartPhoneClientManager().start();

  // Alternatively: do it all in one line of code....!
  // Create and configure a client manager for this phone, add the protocol,
  // and start sampling data.
  SmartPhoneClientManager().configure().then((_) => SmartPhoneClientManager()
      .addStudyProtocol(protocol)
      .then((_) => SmartPhoneClientManager().start()));

  // Listening on the data stream and print them as json.
  SmartPhoneClientManager()
      .measurements
      .listen((measurement) => print(toJsonString(measurement)));

  // Stop sampling again.
  SmartPhoneClientManager().stop();

  // Dispose the client. Can not be used anymore.
  SmartPhoneClientManager().dispose();
}

/// This is an example of how to set up a the most minimal study
/// Used in the intro on the wiki
Future<void> example_0() async {
  // STEP I -- DEFINE PROTOCOL

  // Create a study protocol
  SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
    ownerId: 'AB',
    name: 'Track patient movement',
  );

  // Define which devices are used for data collection.
  // In this case, its only this smartphone
  var phone = Smartphone();
  protocol.addPrimaryDevice(phone);

  // Automatically collect step count, ambient light, screen activity, and
  // battery level. Sampling is delaying by 10 seconds.
  protocol.addTaskControl(
    DelayedTrigger(delay: const Duration(seconds: 10)),
    BackgroundTask(measures: [
      Measure(type: SensorSamplingPackage.STEP_COUNT),
      Measure(type: SensorSamplingPackage.AMBIENT_LIGHT),
      Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
      Measure(type: DeviceSamplingPackage.BATTERY_STATE),
    ]),
    phone,
    Control.Start,
  );

  // STEP II -- DEPLOY STUDY ON A CLIENT

  // Create and configure a client manager for this phone, and
  // create a study based on the protocol.
  SmartPhoneClientManager client = SmartPhoneClientManager();
  await client.configure();
  Study study = await client.addStudyProtocol(protocol);

  // Get the study controller and try to deploy the study.
  //
  // Note that if the study has already been deployed on this phone
  // it has been cached locally in a file and the local cache will
  // be used pr. default.
  // If not deployed before (i.e., cached) the study deployment will be
  // fetched from the deployment service.
  SmartphoneDeploymentController? controller = client.getStudyRuntime(study);
  await controller?.tryDeployment();

  // Configure the controller.
  await controller?.configure();

  // STEP III -- START THE STUDY

  // Start the data sampling
  controller?.start();

  // Listening and print all measurements collected
  controller?.measurements.forEach(print);
}

/// This is an example of how to set up a study.
/// This protocol uses the default sampling configuration and stores
/// collected data in a local SQLite database.
void example_1() async {
  // Create a study protocol storing data in a local SQLite database.
  SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
    ownerId: 'abc@dtu.dk',
    name: 'Track patient movement',
    dataEndPoint: SQLiteDataEndPoint(),
  );

  // Define which devices are used for data collection.
  // In this case, its only this smartphone.
  Smartphone phone = Smartphone();
  protocol.addPrimaryDevice(phone);

  // Automatically collect step count, ambient light, screen activity, and
  // battery level. Sampling is delaying by 10 seconds.
  protocol.addTaskControl(
    ImmediateTrigger(),
    BackgroundTask(measures: [
      Measure(type: SensorSamplingPackage.STEP_COUNT),
      Measure(type: SensorSamplingPackage.AMBIENT_LIGHT),
      Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
      Measure(type: DeviceSamplingPackage.BATTERY_STATE),
    ]),
    phone,
  );

  // Use the on-phone deployment service.
  DeploymentService deploymentService = SmartphoneDeploymentService();

  // Create a study deployment using the protocol
  var status = await deploymentService.createStudyDeployment(protocol);

  // Create and configure a client manager for this phone.
  SmartPhoneClientManager client = SmartPhoneClientManager();
  await client.configure(deploymentService: deploymentService);

  // Add the study to the client manager and get a study runtime to
  // control this deployment
  Study study = await client.addStudy(
    status.studyDeploymentId,
    status.primaryDeviceStatus!.device.roleName,
  );
  SmartphoneDeploymentController? controller = client.getStudyRuntime(study);

  // Deploy the study on this phone.
  await controller?.tryDeployment();

  // Configure the controller and start sampling.
  await controller?.configure();
  controller?.start();

  // Print all data events from the study
  controller?.measurements.forEach(print);
}

/// This is a more elaborate example used in the README.md file.
void example_2() async {
  // Create a study protocol
  SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
    ownerId: 'abc@dtu.dk',
    name: 'Tracking',
    studyDescription: StudyDescription(
        title: 'CAMS App - Sensing Coverage Study',
        description:
            'The default study testing coverage of most measures. Used in the coverage tests.',
        purpose: 'To test sensing coverage',
        responsible: StudyResponsible(
          id: 'abc',
          title: 'professor',
          address: 'Ørsteds Plads',
          affiliation: 'Technical University of Denmark',
          email: 'abc@dtu.dk',
          name: 'Alex B. Christensen',
        )),
    dataEndPoint: FileDataEndPoint(
      bufferSize: 500 * 1000,
      zip: true,
      encrypt: false,
    ),
  );

  // define which devices are used for data collection
  // in this case, its only this smartphone
  Smartphone phone = Smartphone();
  protocol.addPrimaryDevice(phone);

  // automatically collect accelerometer and gyroscope data
  // but delay the sampling by 10 seconds
  protocol.addTaskControl(
    DelayedTrigger(delay: const Duration(seconds: 10)),
    BackgroundTask(name: 'Sensor Task', measures: [
      Measure(type: SensorSamplingPackage.ACCELERATION),
      Measure(type: SensorSamplingPackage.ROTATION),
    ]),
    phone,
    Control.Start,
  );

  // specify details of a light measure
  Measure lightMeasure = Measure(
    type: SensorSamplingPackage.AMBIENT_LIGHT,
  )..overrideSamplingConfiguration = PeriodicSamplingConfiguration(
      interval: const Duration(minutes: 10),
      duration: const Duration(seconds: 20),
    );

  // add it to the study to start immediately
  protocol.addTaskControl(
    ImmediateTrigger(),
    BackgroundTask(name: 'Light')..addMeasure(lightMeasure),
    phone,
    Control.Start,
  );

  // use the on-phone deployment service
  DeploymentService deploymentService = SmartphoneDeploymentService();

  // create a study deployment based on the protocol
  // no need for any invitation when deploying locally
  StudyDeploymentStatus status =
      await deploymentService.createStudyDeployment(protocol);

  // create and configure a client manager for this phone
  SmartPhoneClientManager client = SmartPhoneClientManager();
  await client.configure(deploymentService: deploymentService);

  // create a study runtime to control this deployment
  Study study = await client.addStudy(
    status.studyDeploymentId,
    status.primaryDeviceStatus!.device.roleName,
  );
  SmartphoneDeploymentController? controller = client.getStudyRuntime(study);

  // deploy the study on this phone (controller)
  await controller?.tryDeployment();

  // start sampling
  controller?.start();

  // listening to the stream of all measurements from the controller
  controller?.measurements.listen((measurement) => print(measurement));

  // listen only on CARP measurements
  controller?.measurements
      .where(
          (measurement) => measurement.data.format.namespace == NameSpace.CARP)
      .listen((event) => print(event));

  // listen on ambient light measurements only
  controller?.measurements
      .where((measurement) =>
          measurement.data.format.toString() ==
          SensorSamplingPackage.AMBIENT_LIGHT)
      .listen((measurement) => print(measurement));

  // map measurements to JSON and then print
  controller?.measurements
      .map((measurement) => measurement.toJson())
      .listen((json) => print(json));

  // subscribe to the stream of measurements
  StreamSubscription<Measurement> subscription =
      controller!.measurements.listen((Measurement measurement) {
    // do something w. the measurement, e.g. print the json
    print(const JsonEncoder.withIndent(' ').convert(measurement));
  });

  // Sampling can be stopped and started
  controller.executor.stop();
  controller.executor.start();

  // Stop specific probe(s)
  controller.executor
      .lookupProbe(CarpDataTypes.ACCELERATION_TYPE_NAME)
      .forEach((probe) => probe.stop());

  // Adapt a measure
  //
  // Note that this will only work if the protocol is created locally on the
  // phone (as in the example above)
  // If downloaded and deserialized from json, then we need to locate the
  // measure in the deployment
  lightMeasure.overrideSamplingConfiguration = PeriodicSamplingConfiguration(
    interval: const Duration(minutes: 5),
    duration: const Duration(seconds: 10),
  );

  // Restart the light probe(s) in order to load the new configuration
  controller.executor
      .lookupProbe(SensorSamplingPackage.AMBIENT_LIGHT)
      .forEach((probe) => probe.restart());

  // Once the sampling has to stop, e.g. in a Flutter dispose() methods,
  // call the controller's dispose method.
  controller.dispose();

  // Cancel the subscription.
  await subscription.cancel();
}

/// An example of how to configure a [SmartphoneStudyProtocol] with the
/// default privacy schema.
void studyControllerExample() async {
  SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
    ownerId: 'AB',
    name: 'Track patient movement',
    privacySchemaName: PrivacySchema.DEFAULT,
  );
}

/// Example of different configuration options.
void example_3() async {
  var protocol = SmartphoneStudyProtocol(
    ownerId: 'abc@dtu.dk',
    name: 'Tracking',
  );

  // create and configure a client manager for this phone
  final client = SmartPhoneClientManager();

  // default configuration using:
  // * [AwesomeNotificationController]
  // * [SmartphoneDeploymentService]
  // * [DeviceController]
  await client.configure();

  // use flutter_local_notification for notifications
  await client.configure(
    notificationController: FlutterLocalNotificationController(),
    askForPermissions: false,
    enableNotifications: false,
  );

  // add and deploy the protocol
  final study = await client.addStudyProtocol(protocol);
  final controller = client.getStudyRuntime(study);

  // configure the controller
  controller?.configure(
    dataEndPoint: FileDataEndPoint(bufferSize: 50 * 1000, encrypt: false),
    transformer: (data) => data,
  );
}

/// Example of device management.
///
/// In this example we assume that the protocol has been deployed
/// (e.g. to the CARP server) and that we get it from there.
///
/// The steps involved in this example is then:
///  * get the study deployment status
///  * create the devices needed in the protocol
///  * register the devices which are available
///  * get the study deployment for this primary device
///  * start the sensing
void example_4() async {
  // we assume that we know the study deployment id
  // this might have been obtained from an invitation
  String studyDeploymentId = '2938y4h-rfhklwe98-erhui';

  // get the status of this deployment
  StudyDeploymentStatus? status = await SmartphoneDeploymentService()
      .getStudyDeploymentStatus(studyDeploymentId);

  // register the needed devices - listed in the deployment status
  status?.deviceStatusList.forEach((deviceStatus) async {
    String type = deviceStatus.device.type;
    String deviceRoleName = deviceStatus.device.roleName;

    // create and register the device in the CAMS DeviceRegistry
    await DeviceController().createDevice(type);

    // if the device manager is created successfully on the phone
    if (DeviceController().hasDevice(type)) {
      // ask the device manager for a unique id of the device
      String deviceId = DeviceController().getDevice(type)!.id;
      DeviceRegistration registration = DeviceRegistration(deviceId: deviceId);
      // (all of the above can actually be handled directly by the SmartphoneDeploymentService.registerDevice() method)

      // register the device in the deployment service
      await SmartphoneDeploymentService()
          .registerDevice(studyDeploymentId, deviceRoleName, registration);
    }
  });

  // now get the study deployment for this smartphone device and its registered devices
  SmartphoneDeployment? deployment = await SmartphoneDeploymentService()
      .getDeviceDeployment(studyDeploymentId);

  print(deployment);
}

void protocolExample() async {
  // Create a protocol. Note that the [id] is not used for anything.
  SmartphoneStudyProtocol protocol = SmartphoneStudyProtocol(
      ownerId: 'AB',
      name: 'Track patient movement',
      dataEndPoint: SQLiteDataEndPoint());

  // Define which devices are used for data collection.
  //
  // In this case, its only this phone.
  // See the CARP Mobile Sensing app for a full-blown example of how to
  // use connected devices (e.g., a Polar heart rate monitor) and online
  // services (e.g., a weather service).
  var phone = Smartphone();
  protocol.addPrimaryDevice(phone);

  // Collect timezone info every time the app restarts.
  protocol.addTaskControl(
      ImmediateTrigger(),
      BackgroundTask(measures: [
        Measure(type: DeviceSamplingPackage.TIMEZONE),
      ]),
      phone);

  // Collect device info only once, when this study is deployed.
  protocol.addTaskControl(
    OneTimeTrigger(),
    BackgroundTask(
        measures: [Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION)]),
    phone,
  );

  // Add background measures from the [DeviceSamplingPackage] and
  // [SensorSamplingPackage] sampling packages.
  //
  // Note that some of these measures only works on Android:
  //  * screen events
  //  * ambient light
  //  * free memory (there seems to be a bug in the underlying sysinfo plugin)
  protocol.addTaskControl(
    ImmediateTrigger(),
    BackgroundTask(measures: [
      Measure(type: DeviceSamplingPackage.FREE_MEMORY),
      Measure(type: DeviceSamplingPackage.BATTERY_STATE),
      Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
      Measure(type: CarpDataTypes.STEP_COUNT_TYPE_NAME),
      Measure(type: SensorSamplingPackage.AMBIENT_LIGHT)
    ]),
    phone,
  );

  // Collect IMU data every 10 secs for 1 sec.
  protocol.addTaskControl(
    PeriodicTrigger(period: const Duration(seconds: 10)),
    BackgroundTask(
      measures: [
        Measure(type: CarpDataTypes.ACCELERATION_TYPE_NAME),
        Measure(type: CarpDataTypes.ROTATION_TYPE_NAME),
      ],
      duration: const IsoDuration(seconds: 1),
    ),
    phone,
  );

  // // Example of how to start and stop sampling using the Control.Start and
  // // Control.Stop method
  // var task_1 = BackgroundTask(
  //   measures: [
  //     Measure(type: CarpDataTypes.ACCELERATION_TYPE_NAME),
  //     Measure(type: CarpDataTypes.ROTATION_TYPE_NAME),
  //   ],
  // );

  // var task_2 = BackgroundTask(
  //   measures: [
  //     Measure(type: DeviceSamplingPackage.BATTERY_STATE),
  //   ],
  // );

  // // Collect IMU data
  // protocol.addTaskControls(
  //   ImmediateTrigger(),
  //   [task_1, task_2],
  //   phone,
  //   Control.Start,
  // );

  // // After a while, stop it again
  // protocol.addTaskControl(
  //   DelayedTrigger(delay: Duration(seconds: 10)),
  //   task_1,
  //   phone,
  //   Control.Stop,
  // );

  // // add a random trigger to collect device info at random times
  // protocol.addTaskControl(
  //   RandomRecurrentTrigger(
  //     startTime: TimeOfDay(hour: 07, minute: 45),
  //     endTime: TimeOfDay(hour: 22, minute: 30),
  //     minNumberOfTriggers: 2,
  //     maxNumberOfTriggers: 8,
  //   ),
  //   BackgroundTask()
  //     ..addMeasure(Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION)),
  //   phone,
  //   Control.Start,
  // );

  // // add a ConditionalPeriodicTrigger to check periodically
  // protocol.addTaskControl(
  //     ConditionalPeriodicTrigger(
  //         period: Duration(seconds: 20),
  //         triggerCondition: () => ('jakob'.length == 5)),
  //     BackgroundTask()
  //       ..addMeasure(Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION)),
  //     phone,
  //     Control.Start);

  // // Collect device info after 30 secs
  // protocol.addTaskControl(
  //   ElapsedTimeTrigger(elapsedTime: IsoDuration(seconds: 30)),
  //   BackgroundTask(
  //     measures: [
  //       Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION),
  //     ],
  //   ),
  //   phone,
  // );

  // Add two app tasks with notifications.
  //
  // These App Tasks are added for demo purpose and you should see notifications
  // on the phone. However, nothing will happen when you click on it.
  // See the PulmonaryMonitor demo app for a full-scale example of how to use
  // the App Task model.

  // Add a task 1 minute after deployment and make a notification.
  protocol.addTaskControl(
    ElapsedTimeTrigger(elapsedTime: const IsoDuration(seconds: 30)),
    AppTask(
      type: BackgroundSensingUserTask.ONE_TIME_SENSING_TYPE,
      title: "Elapsed Time - App Task",
      measures: [Measure(type: DeviceSamplingPackage.TIMEZONE)],
      notification: true,
    ),
    phone,
  );

  // // Add a cron job every day at 11:45
  // protocol.addTaskControl(
  //     CronScheduledTrigger.parse(cronExpression: '45 11 * * *'),
  //     AppTask(
  //       type: BackgroundSensingUserTask.ONE_TIME_SENSING_TYPE,
  //       title: "Cron - every day at 11:45",
  //       measures: [Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION)],
  //       notification: true,
  //     ),
  //     phone);
}

// /// An example of how to use the [SamplingSchema] model.
// void samplingSchemaExample() async {
//   // creating a sampling schema focused on activity and outdoor context (weather)
//   SamplingSchema activitySchema = SamplingSchema(
//       type: SamplingSchemaType.normal,
//       name: 'Connectivity Sampling Schema',
//       powerAware: true)
//     ..measures.addEntries([
//       MapEntry(
//           SensorSamplingPackage.PEDOMETER,
//           PeriodicMeasure(
//               type: SensorSamplingPackage.PEDOMETER,
//               enabled: true,
//               frequency: const Duration(minutes: 1))),
//       MapEntry(DeviceSamplingPackage.SCREEN,
//           Measure(type: DeviceSamplingPackage.SCREEN)),
//     ]);

//   StudyProtocol protocol = StudyProtocol(
//     ownerId: 'AB',
//     name: 'Track patient movement',
//   );
//   Smartphone phone = Smartphone(roleName: 'phone');
//   protocol.addMasterDevice(phone);

//   // adding a set of specific measures from the `common` sampling schema to one overall task
//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask(name: 'Sensing Task #1')
//         ..measures = DeviceSamplingPackage().common.getMeasureList(
//           types: [
//             DeviceSamplingPackage.SCREEN,
//             DeviceSamplingPackage.BATTERY,
//           ],
//         ),
//       phone);

//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask(name: 'One Common Sensing Task')
//         ..measures = SensorSamplingPackage().common.getMeasureList(
//           types: [
//             SensorSamplingPackage.PEDOMETER,
//             SensorSamplingPackage.ACCELEROMETER,
//             SensorSamplingPackage.GYROSCOPE,
//           ],
//         ),
//       phone);

//   // adding all measure from the activity schema to one overall 'sensing' task
//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask()..measures = activitySchema.measures.values.toList(),
//       phone);

//   // adding the measures to two separate tasks, while also adding a
//   // new light measure to the 2nd task
//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask(name: 'Activity Sensing Task #1')
//         ..measures = activitySchema.getMeasureList(
//           types: [
//             SensorSamplingPackage.PEDOMETER,
//             SensorSamplingPackage.ACCELEROMETER,
//           ],
//         ),
//       phone);

//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask(name: 'Phone Sensing Task #2')
//         ..measures = activitySchema.getMeasureList(
//           types: [
//             DeviceSamplingPackage.SCREEN,
//           ],
//         )
//         ..addMeasure(PeriodicMeasure(
//           type: SensorSamplingPackage.LIGHT,
//           frequency: const Duration(seconds: 11),
//           duration: const Duration(milliseconds: 100),
//         )),
//       phone);
// }

// void samplingSchemaExample_2() {
//   StudyProtocol protocol = StudyProtocol(
//     ownerId: 'AB',
//     name: 'Track patient movement',
//   );
//   Smartphone phone = Smartphone(roleName: 'phone');
//   protocol.addMasterDevice(phone);

//   protocol.addTriggeredTask(
//       ImmediateTrigger(),
//       AutomaticTask()
//         ..measures = SamplingPackageRegistry().common.measures.values.toList(),
//       phone);
// }

// void samplingSchemaExample_3() async {
//   String studyDeploymentId = '1234';
//   String deviceRolename = 'masterphone';

//   // create and configure a client manager for this phone
//   SmartPhoneClientManager client = SmartPhoneClientManager();
//   await client.configure();

//   // create a study runtime to control this deployment
//   SmartphoneDeploymentController controller =
//       await client.addStudy(studyDeploymentId, deviceRolename);

//   // deploy the study on this phone (controller)
//   await controller.tryDeployment();

//   // configure the controller and start sampling
//   await controller.configure(
//     samplingSchema: SamplingPackageRegistry().common,
//     privacySchemaName: PrivacySchema.DEFAULT,
//   );
//   controller.start();
// }

/// Examples of different [RecurrentScheduledTrigger] configurations.
void recurrentScheduledTriggerExample() {
  // collect every day at 13:30
  RecurrentScheduledTrigger(
    type: RecurrentType.daily,
    time: const TimeOfDay(hour: 13, minute: 30),
    duration: const Duration(seconds: 1),
  );

  // collect every other day at 13:30
  RecurrentScheduledTrigger(
    type: RecurrentType.daily,
    separationCount: 1,
    time: const TimeOfDay(hour: 13, minute: 30),
    duration: const Duration(seconds: 1),
  );

  // collect every wednesday at 12:23
  RecurrentScheduledTrigger(
    type: RecurrentType.weekly,
    dayOfWeek: DateTime.wednesday,
    time: const TimeOfDay(hour: 12, minute: 23),
    duration: const Duration(seconds: 1),
  );

  // collect every 2nd monday at 12:23
  RecurrentScheduledTrigger(
    type: RecurrentType.weekly,
    dayOfWeek: DateTime.monday,
    separationCount: 1,
    time: const TimeOfDay(hour: 12, minute: 23),
    duration: const Duration(seconds: 1),
  );

  // collect monthly in the second week on a monday at 14:30
  RecurrentScheduledTrigger(
    type: RecurrentType.monthly,
    weekOfMonth: 2,
    dayOfWeek: DateTime.monday,
    time: const TimeOfDay(hour: 14, minute: 30),
    duration: const Duration(seconds: 1),
  );

  // collect quarterly on the 11th day of the first month in each quarter at 21:30
  RecurrentScheduledTrigger(
    type: RecurrentType.monthly,
    dayOfMonth: 11,
    separationCount: 2,
    time: const TimeOfDay(hour: 21, minute: 30),
    duration: const Duration(seconds: 1),
  );
}

/// An example of using the AppTask model
void appTaskExample() async {
  Smartphone phone = Smartphone(roleName: 'phone');

  StudyProtocol protocol = StudyProtocol(
    ownerId: 'user@dtu.dk',
    name: 'Tracking',
  )
    // collect device info as an app task
    ..addTaskControl(
      ImmediateTrigger(),
      AppTask(
        type: BackgroundSensingUserTask.ONE_TIME_SENSING_TYPE,
        title: 'Device',
        description: 'Collect device info',
      )..addMeasure(Measure(type: DeviceSamplingPackage.DEVICE_INFORMATION)),
      phone,
      Control.Start,
    )
    // start collecting screen events as an app task
    ..addTaskControl(
      ImmediateTrigger(),
      AppTask(
        type: BackgroundSensingUserTask.SENSING_TYPE,
        title: 'Screen',
        description: 'Collect screen events',
      )..addMeasure(Measure(type: DeviceSamplingPackage.SCREEN_EVENT)),
      phone,
      Control.Start,
    );

  print(protocol);
}

/// An example of how to listen to different [UserTask] event in the
/// [AppTaskController].
void appTaskControllerExample() async {
  AppTaskController ctrl = AppTaskController();

  ctrl.userTaskEvents.listen((userTask) {
    AppTask task = (userTask.executor.task as AppTask);
    print('Task: ${task.title}');
    switch (userTask.state) {
      case UserTaskState.initialized:
        //
        break;
      case UserTaskState.enqueued:
        //
        break;
      case UserTaskState.dequeued:
        //
        break;
      case UserTaskState.started:
        userTask.executor.start();
        break;
      case UserTaskState.canceled:
        //
        break;
      case UserTaskState.done:
        userTask.executor.stop();
        break;
      default:
        //
        break;
    }
  });
}
