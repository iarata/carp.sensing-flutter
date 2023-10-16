/*
 * Copyright 2022 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of data_managers;

class SQLiteDataManagerFactory implements DataManagerFactory {
  @override
  String get type => DataEndPointTypes.SQLITE;

  @override
  DataManager create() => SQLiteDataManager();
}

/// Stores meta data about the running [SmartphoneDeployment] and all
/// collected [Measurement] json objects in an SQLite database on the device's
/// local storage media.
///
/// Meta data is stored in the `deployment` table and measurements are stored
/// in the `measurements` table.
///
/// The path and filename format is
///
///   `~/carp-data.db`
///
/// where `~` is the folder where SQLite places it database files.
///
/// On iOS, this is the `NSDocumentsDirectory` and the files can be accessed via
/// the MacOS Finder.
///
/// On Android, Flutter files are stored in the `databases` directory, which is
/// located in the `data/data/<package_name>/databases/` folder.
/// Files can be accessed via AndroidStudio.
class SQLiteDataManager extends AbstractDataManager {
  static const String DATABASE_NAME = 'carp-data';

  static const String MEASUREMENT_TABLE_NAME = 'measurements';
  static const String ID_COLUMN = 'id';
  static const String UPLOADED_COLUMN = 'uploaded';
  static const String DEPLOYMENT_ID_COLUMN = 'deployment_id';
  static const String TRIGGER_ID_COLUMN = 'trigger_id';
  static const String ROLE_NAME_COLUMN = 'device_rolename';
  static const String DATATYPE_COLUMN = 'data_type';
  static const String MEASUREMENT_COLUMN = 'measurement';

  String? _databasePath;

  /// Full path and name of the database.
  String get databaseName => '$_databasePath/$DATABASE_NAME.db';

  Database? database;

  @override
  String get type => DataEndPointTypes.SQLITE;

  @override
  Future<void> initialize(
    DataEndPoint dataEndPoint,
    SmartphoneDeployment deployment,
    Stream<Measurement> measurements,
  ) async {
    assert(dataEndPoint is SQLiteDataEndPoint);
    await super.initialize(dataEndPoint, deployment, measurements);

    info('Initializing $runtimeType...');

    _databasePath ??= await getDatabasesPath();

    // Open the database - make sure to use the same database across app (re)start
    database = await openDatabase(
      databaseName,
      version: 1,
      singleInstance: true,
      onCreate: (Database db, int version) async {
        // when creating the database, create the measurements table
        debug("$runtimeType - Creating '$MEASUREMENT_TABLE_NAME' table");
        await db.execute('CREATE TABLE $MEASUREMENT_TABLE_NAME ('
            '$ID_COLUMN INTEGER PRIMARY KEY AUTOINCREMENT, '
            // SQLite does not have a separate Boolean storage class. Instead,
            // boolean values are stored as integers 0 (false) and 1 (true).
            '$UPLOADED_COLUMN INTEGER, '
            '$DEPLOYMENT_ID_COLUMN TEXT, '
            '$TRIGGER_ID_COLUMN INTEGER, '
            '$ROLE_NAME_COLUMN TEXT, '
            '$DATATYPE_COLUMN TEXT, '
            '$MEASUREMENT_COLUMN TEXT)');

        debug("$runtimeType - '$databaseName' DB created");
      },
    );
  }

  @override
  Future<void> onMeasurement(Measurement measurement) async {
    final Map<String, dynamic> map = {
      UPLOADED_COLUMN: 0,
      DEPLOYMENT_ID_COLUMN: deployment.studyDeploymentId,
      TRIGGER_ID_COLUMN: measurement.taskControl?.triggerId ?? 0,
      ROLE_NAME_COLUMN: measurement.taskControl?.targetDevice?.roleName ??
          deployment.deviceConfiguration.roleName,
      DATATYPE_COLUMN: measurement.dataType.toString(),
      MEASUREMENT_COLUMN: jsonEncode(measurement),
    };
    int? id = await database?.insert(
      MEASUREMENT_TABLE_NAME,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debug(
        '$runtimeType - wrote measurement to SQLite - id: $id, type: ${measurement.data.format}');
  }

  @override
  Future<void> onDone() async {
    await database?.close();
    await super.close();
  }

  @override
  Future<void> close() async {
    await database?.close();
    await super.close();
  }
}
