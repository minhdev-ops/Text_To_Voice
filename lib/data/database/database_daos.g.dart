// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_daos.dart';

// ignore_for_file: type=lint
mixin _$DatabaseDaosMixin on DatabaseAccessor<AppDatabase> {
  $DocumentsTable get documents => attachedDatabase.documents;
  $DocumentPagesTable get documentPages => attachedDatabase.documentPages;
  $DocumentBlocksTable get documentBlocks => attachedDatabase.documentBlocks;
  $DocumentImagesTable get documentImages => attachedDatabase.documentImages;
  $TtsAudioTable get ttsAudio => attachedDatabase.ttsAudio;
  $ReadingProgressTable get readingProgress => attachedDatabase.readingProgress;
  $SettingsTable get settings => attachedDatabase.settings;
  $ModelsTable get models => attachedDatabase.models;
  $ProcessingJobsTable get processingJobs => attachedDatabase.processingJobs;
  DatabaseDaosManager get managers => DatabaseDaosManager(this);
}

class DatabaseDaosManager {
  final _$DatabaseDaosMixin _db;
  DatabaseDaosManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db.attachedDatabase, _db.documents);
  $$DocumentPagesTableTableManager get documentPages =>
      $$DocumentPagesTableTableManager(_db.attachedDatabase, _db.documentPages);
  $$DocumentBlocksTableTableManager get documentBlocks =>
      $$DocumentBlocksTableTableManager(
        _db.attachedDatabase,
        _db.documentBlocks,
      );
  $$DocumentImagesTableTableManager get documentImages =>
      $$DocumentImagesTableTableManager(
        _db.attachedDatabase,
        _db.documentImages,
      );
  $$TtsAudioTableTableManager get ttsAudio =>
      $$TtsAudioTableTableManager(_db.attachedDatabase, _db.ttsAudio);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(
        _db.attachedDatabase,
        _db.readingProgress,
      );
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db.attachedDatabase, _db.models);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(
        _db.attachedDatabase,
        _db.processingJobs,
      );
}
