import 'package:carp_serializable/carp_serializable.dart';
import 'package:carp_core/carp_core.dart';
import 'package:carp_mobile_sensing/carp_mobile_sensing.dart';
import 'package:carp_webservices/carp_auth/carp_auth.dart';
import 'package:carp_webservices/carp_services/carp_services.dart';
import 'package:flutter/cupertino.dart';
import 'package:test/test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_credentials.dart';
import '_carp_properties.dart';

/// This test suite tests the [CarpParticipationService].
///
/// The main focus is to test
///  - getting the participation invitations
///  - setting & getting expected participation data
///
/// A special protocol for a 3-person family is used for testing expected
/// participation data for each family member.
void main() {
  CarpUser? user;
  String? ownerId;
  late StudyProtocol protocol;

  Settings().debugLevel = DebugLevel.debug;
  SharedPreferences.setMockInitialValues({});
  WidgetsFlutterBinding.ensureInitialized();
  CarpMobileSensing.ensureInitialized();

  /// Configure CARP and authenticate.
  setUpAll(() async {
    await CarpAuthService().configure(CarpProperties().authProperties);
    CarpService().configure(CarpProperties().app);

    user = await CarpAuthService().authenticateWithUsernamePassword(
      username: username,
      password: password,
    );
    CarpParticipationService().configureFrom(CarpService());

    ownerId = CarpAuthService().currentUser.id;
    const father = 'Father';
    const mother = 'Mother';
    const child = 'Child';

    // a study protocol testing misc input data types for a family
    protocol = StudyProtocol(
        ownerId: ownerId!,
        name: 'Input Data Types',
        description: 'Collect mics. input from study participants.');

    // add participant roles
    protocol
      ..addParticipantRole(ParticipantRole(father))
      ..addParticipantRole(ParticipantRole(mother))
      ..addParticipantRole(ParticipantRole(child));

    // define and assign the primary devices for each family member
    final fatherPhone = Smartphone(roleName: "$father's Phone");
    final motherPhone = Smartphone(roleName: "$mother's Phone");
    final childPhone = Smartphone(roleName: "$child's Phone");
    protocol
      ..addPrimaryDevice(fatherPhone)
      ..addPrimaryDevice(motherPhone)
      ..addPrimaryDevice(childPhone);

    protocol
      ..changeDeviceAssignment(fatherPhone, AssignedTo(roleNames: {father}))
      ..changeDeviceAssignment(motherPhone, AssignedTo(roleNames: {mother}))
      ..changeDeviceAssignment(childPhone, AssignedTo(roleNames: {child}));

    // add expected participant data which can be set by ALL participants
    protocol.addExpectedParticipantData(ExpectedParticipantData(
        attribute: ParticipantAttribute(inputDataType: AddressInput.type)));

    // add expected participant data for specific participants
    protocol
      ..addExpectedParticipantData(ExpectedParticipantData(
          attribute: ParticipantAttribute(inputDataType: FullNameInput.type),
          assignedTo: AssignedTo(roleNames: {father, mother, child})))
      ..addExpectedParticipantData(ExpectedParticipantData(
          attribute: ParticipantAttribute(inputDataType: SexInput.type),
          assignedTo: AssignedTo(roleNames: {father, mother, child})))
      ..addExpectedParticipantData(ExpectedParticipantData(
          attribute:
              ParticipantAttribute(inputDataType: InformedConsentInput.type),
          assignedTo: AssignedTo(roleNames: {father, mother})));

    // add measures (not really used in this test)
    protocol
      ..addTaskControl(
          ImmediateTrigger(),
          BackgroundTask(measures: [
            Measure(type: SensorSamplingPackage.STEP_COUNT),
            Measure(type: SensorSamplingPackage.AMBIENT_LIGHT),
          ]),
          fatherPhone)
      ..addTaskControl(
          ImmediateTrigger(),
          BackgroundTask(measures: [
            Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
            Measure(type: DeviceSamplingPackage.FREE_MEMORY),
          ]),
          motherPhone)
      ..addTaskControl(
          ImmediateTrigger(),
          BackgroundTask(measures: [
            Measure(type: DeviceSamplingPackage.SCREEN_EVENT),
            Measure(type: DeviceSamplingPackage.BATTERY_STATE),
          ]),
          childPhone);
  });

  tearDownAll(() {});

  group("Base services", () {
    test('- authentication', () async {
      debugPrint('CarpService : ${CarpService().app}');
      debugPrint(" - signed in as: $user");

      debugPrint('${CarpAuthService().manager?.discoveryDocument}');
    }, skip: false);
  });

  group("Define Protocol", () {
    test(
      '- define',
      () async {
        debugPrint(toJsonString(protocol));
      },
    );
  });

  group("Participation", () {
    test(
      '- get invitations for this user',
      () async {
        List<ActiveParticipationInvitation> invitations =
            await CarpParticipationService()
                .getActiveParticipationInvitations();

        expect(invitations, isNotNull);
        debugPrint(toJsonString(invitations));
      },
      skip: false,
    );

    test(
      '- get participant data',
      () async {
        ParticipationReference participation =
            CarpParticipationService().participation(testDeploymentId);

        ParticipantData data = await participation.getParticipantData();
        debugPrint(toJsonString(data));
      },
      skip: false,
    );

    test(
      '- set participant data',
      () async {
        ParticipationReference participation =
            CarpParticipationService().participation(testDeploymentId);

        ParticipantData data = await participation.setParticipantData(
          {SexInput.type: SexInput(value: Sex.Male)},
          'Participant',
        );
        debugPrint(toJsonString(data));

        // expect();

        // ParticipantData data = await participation.getParticipantData();
        // debugPrint(toJsonString(data));
        // assert(data != null);
      },
      skip: false,
    );
  });
}
