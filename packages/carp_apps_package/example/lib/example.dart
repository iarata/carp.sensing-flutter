import 'package:carp_core/carp_core.dart';
import 'package:carp_apps_package/apps.dart';
import 'package:carp_mobile_sensing/carp_mobile_sensing.dart';

/// This is a very simple example of how this sampling package is used with
/// CARP Mobile Sensing (CAMS).
/// NOTE, however, that the code below will not run.
/// See the documentation on how to use CAMS: https://github.com/cph-cachet/carp.sensing-flutter/wiki
void main() async {
  // register this sampling package before using its measures
  SamplingPackageRegistry().register(AppsSamplingPackage());

  // Create a study protocol
  StudyProtocol protocol = StudyProtocol(
    ownerId: 'owner@dtu.dk',
    name: 'Context Sensing Example',
  );

  // define which devices are used for data collection
  // in this case, its only this smartphone
  Smartphone phone = Smartphone();
  protocol.addMasterDevice(phone);

  // Add an automatic task that immediately starts collecting connectivity,
  // nearby bluetooth devices, and wifi information.
  protocol.addTriggeredTask(
      ImmediateTrigger(),
      AutomaticTask()
        ..addMeasures(SensorSamplingPackage().common.getMeasureList(
          types: [
            AppsSamplingPackage.APPS,
            AppsSamplingPackage.APP_USAGE,
          ],
        )),
      phone);

  // deploy this protocol using the on-phone deployment service
  StudyDeploymentStatus status =
      await SmartphoneDeploymentService().createStudyDeployment(protocol);

  String studyDeploymentId = status.studyDeploymentId;
  String deviceRolename = status.masterDeviceStatus.device.roleName;

  // create and configure a client manager for this phone
  SmartPhoneClientManager client = SmartPhoneClientManager();
  await client.configure();

  // create a study runtime to control this deployment
  StudyDeploymentController controller =
      await client.addStudy(studyDeploymentId, deviceRolename);

  // configure the controller and resume sampling
  await controller.configure();
  controller.resume();

  // listening and print all data events from the study
  controller.data.forEach(print);
}
