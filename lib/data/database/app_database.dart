import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// SRS §30 `documents`.
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get source => text().withLength(min: 1, max: 32)();
  TextColumn get mimeType => text().withLength(min: 1, max: 128)();
  TextColumn get originalFileName => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get status => text().withLength(min: 1, max: 32).withDefault(const Constant('queued'))();
  TextColumn get extractedText => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  TextColumn get failureMessage => text().nullable()();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
}

/// SRS §30 `document_pages`.
class DocumentPages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get documentId => text().withLength(min: 1, max: 36)();
  IntColumn get pageNumber => integer()();
  TextColumn get sourceType => text().withLength(min: 1, max: 32)();
  TextColumn get imagePath => text().nullable()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// SRS §30 `document_blocks`.
class DocumentBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get documentId => text().withLength(min: 1, max: 36)();
  TextColumn get pageId => text().withLength(min: 1, max: 36).nullable()();
  TextColumn get type => text().withLength(min: 1, max: 32)();
  IntColumn get level => integer().withDefault(const Constant(0))();
  TextColumn get content => text()();
  IntColumn get order => integer()();
  RealColumn get left => real().nullable()();
  RealColumn get top => real().nullable()();
  RealColumn get width => real().nullable()();
  RealColumn get height => real().nullable()();
  RealColumn get confidence => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
}

/// SRS §31 `document_images`.
class DocumentImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get documentId => text().withLength(min: 1, max: 36)();
  TextColumn get pageId => text().withLength(min: 1, max: 36).nullable()();
  IntColumn get pageNumber => integer().nullable()();
  TextColumn get sourceType => text().withLength(min: 1, max: 32)();
  TextColumn get filePath => text()();
  TextColumn get format => text().withLength(min: 1, max: 16)();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// SRS §32 `tts_audio`.
class TtsAudio extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get textHash => text().withLength(min: 1, max: 64).unique()();
  TextColumn get voiceId => text().nullable()();
  RealColumn get speed => real()();
  TextColumn get format => text().withLength(min: 1, max: 16)();
  TextColumn get filePath => text()();
  IntColumn get durationMs => integer()();
  IntColumn get sampleRate => integer().withDefault(const Constant(24000))();
  IntColumn get channels => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAccessedAt => dateTime().withDefault(currentDateAndTime)();
}

/// SRS §33 `reading_progress`.
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get documentId => text().withLength(min: 1, max: 36).unique()();
  IntColumn get pageNumber => integer().nullable()();
  TextColumn get blockId => text().withLength(min: 1, max: 36).nullable()();
  IntColumn get sentenceIndex => integer().withDefault(const Constant(0))();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// SRS §34 `settings`.
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().withLength(min: 1, max: 64).unique()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// SRS §35 `models`.
class Models extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get engineId => text().withLength(min: 1, max: 64)();
  TextColumn get checkpointName => text().withLength(min: 1, max: 255)();
  TextColumn get version => text().withLength(min: 1, max: 64)();
  TextColumn get license => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  BoolColumn get isInstalled => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  TextColumn get checksum => text().nullable()();
  DateTimeColumn get installedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Processing queue jobs that survive process death.
class ProcessingJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 1, max: 36).unique()();
  TextColumn get type => text().withLength(min: 1, max: 32)();
  TextColumn get documentId => text().withLength(min: 1, max: 36).nullable()();
  TextColumn get status => text().withLength(min: 1, max: 32)();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Documents,
  DocumentPages,
  DocumentBlocks,
  DocumentImages,
  TtsAudio,
  ReadingProgress,
  Settings,
  Models,
  ProcessingJobs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here
      },
    );
  }
}