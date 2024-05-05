/*
 * Copyright 2020 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of survey;

/// A [UserTask] that contains a survey.
///
/// A [SurveyUserTask] is enqueued on the [AppTaskController]'s [userTaskQueue]
/// and can be accessed from here. When a user starts this user task, the
/// [onStart] method should be called.
///
/// The survey page to show in the app is available as the [widget].
class SurveyUserTask extends UserTask {
  //
  // A set if predefined commonly used task types.
  static const String SURVEY_TYPE = 'survey';
  static const String COGNITIVE_ASSESSMENT_TYPE = 'cognition';
  static const String HEALTH_ASSESSMENT_TYPE = 'health';
  static const String AUDIO_TYPE = 'audio';
  static const String VIDEO_TYPE = 'video';
  static const String IMAGE_TYPE = 'image';
  static const String INFORMED_CONSENT_TYPE = 'informed_consent';

  /// The [RPAppTask] from which this user task originates from.
  RPAppTask get rpAppTask => task as RPAppTask;

  @override
  bool get hasWidget => true;

  SurveyUserTask(super.executor);

  @override
  Widget? get widget => SurveyPage(
        task: rpAppTask.rpTask,
        resultCallback: _onSurveySubmit,
        onSurveyCancel: _onSurveyCancel,
      );

  @override
  void onStart() {
    super.onStart();
    executor.start();
  }

  void _onSurveySubmit(RPTaskResult result) {
    // when we have the survey result, add it to the measurement stream
    var data = RPTaskResultData(result);
    executor.addMeasurement(Measurement.fromData(data));
    // and then stop the background executor
    executor.stop();
    super.onDone(result: data);
  }

  void _onSurveyCancel([RPTaskResult? result]) {
    // also saved result even though it was canceled by the user
    executor.addMeasurement(Measurement.fromData(RPTaskResultData(result)));
    executor.stop();
    super.onCancel();
  }
}

class SurveyUserTaskFactory implements UserTaskFactory {
  @override
  List<String> types = [
    SurveyUserTask.INFORMED_CONSENT_TYPE,
    SurveyUserTask.SURVEY_TYPE,
    SurveyUserTask.COGNITIVE_ASSESSMENT_TYPE,
  ];

  // always create a [SurveyUserTask]
  @override
  UserTask create(AppTaskExecutor executor) => SurveyUserTask(executor);
}
