// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalFileNameMeta = const VerificationMeta(
    'originalFileName',
  );
  @override
  late final GeneratedColumn<String> originalFileName = GeneratedColumn<String>(
    'original_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _extractedTextMeta = const VerificationMeta(
    'extractedText',
  );
  @override
  late final GeneratedColumn<String> extractedText = GeneratedColumn<String>(
    'extracted_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureMessageMeta = const VerificationMeta(
    'failureMessage',
  );
  @override
  late final GeneratedColumn<String> failureMessage = GeneratedColumn<String>(
    'failure_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    name,
    source,
    mimeType,
    originalFileName,
    fileSize,
    filePath,
    status,
    extractedText,
    isFavorite,
    category,
    createdAt,
    updatedAt,
    lastOpenedAt,
    failureMessage,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('original_file_name')) {
      context.handle(
        _originalFileNameMeta,
        originalFileName.isAcceptableOrUnknown(
          data['original_file_name']!,
          _originalFileNameMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('extracted_text')) {
      context.handle(
        _extractedTextMeta,
        extractedText.isAcceptableOrUnknown(
          data['extracted_text']!,
          _extractedTextMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('failure_message')) {
      context.handle(
        _failureMessageMeta,
        failureMessage.isAcceptableOrUnknown(
          data['failure_message']!,
          _failureMessageMeta,
        ),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      originalFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_file_name'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      extractedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_text'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      failureMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_message'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final int id;
  final String uuid;
  final String name;
  final String source;
  final String mimeType;
  final String? originalFileName;
  final int fileSize;
  final String? filePath;
  final String status;
  final String? extractedText;
  final bool isFavorite;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final String? failureMessage;
  final String metadata;
  const Document({
    required this.id,
    required this.uuid,
    required this.name,
    required this.source,
    required this.mimeType,
    this.originalFileName,
    required this.fileSize,
    this.filePath,
    required this.status,
    this.extractedText,
    required this.isFavorite,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.failureMessage,
    required this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['source'] = Variable<String>(source);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || originalFileName != null) {
      map['original_file_name'] = Variable<String>(originalFileName);
    }
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || extractedText != null) {
      map['extracted_text'] = Variable<String>(extractedText);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    if (!nullToAbsent || failureMessage != null) {
      map['failure_message'] = Variable<String>(failureMessage);
    }
    map['metadata'] = Variable<String>(metadata);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      source: Value(source),
      mimeType: Value(mimeType),
      originalFileName: originalFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFileName),
      fileSize: Value(fileSize),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      status: Value(status),
      extractedText: extractedText == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedText),
      isFavorite: Value(isFavorite),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      failureMessage: failureMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(failureMessage),
      metadata: Value(metadata),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      source: serializer.fromJson<String>(json['source']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      originalFileName: serializer.fromJson<String?>(json['originalFileName']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      status: serializer.fromJson<String>(json['status']),
      extractedText: serializer.fromJson<String?>(json['extractedText']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      category: serializer.fromJson<String?>(json['category']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      failureMessage: serializer.fromJson<String?>(json['failureMessage']),
      metadata: serializer.fromJson<String>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'source': serializer.toJson<String>(source),
      'mimeType': serializer.toJson<String>(mimeType),
      'originalFileName': serializer.toJson<String?>(originalFileName),
      'fileSize': serializer.toJson<int>(fileSize),
      'filePath': serializer.toJson<String?>(filePath),
      'status': serializer.toJson<String>(status),
      'extractedText': serializer.toJson<String?>(extractedText),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'category': serializer.toJson<String?>(category),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'failureMessage': serializer.toJson<String?>(failureMessage),
      'metadata': serializer.toJson<String>(metadata),
    };
  }

  Document copyWith({
    int? id,
    String? uuid,
    String? name,
    String? source,
    String? mimeType,
    Value<String?> originalFileName = const Value.absent(),
    int? fileSize,
    Value<String?> filePath = const Value.absent(),
    String? status,
    Value<String?> extractedText = const Value.absent(),
    bool? isFavorite,
    Value<String?> category = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    Value<String?> failureMessage = const Value.absent(),
    String? metadata,
  }) => Document(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    source: source ?? this.source,
    mimeType: mimeType ?? this.mimeType,
    originalFileName: originalFileName.present
        ? originalFileName.value
        : this.originalFileName,
    fileSize: fileSize ?? this.fileSize,
    filePath: filePath.present ? filePath.value : this.filePath,
    status: status ?? this.status,
    extractedText: extractedText.present
        ? extractedText.value
        : this.extractedText,
    isFavorite: isFavorite ?? this.isFavorite,
    category: category.present ? category.value : this.category,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    failureMessage: failureMessage.present
        ? failureMessage.value
        : this.failureMessage,
    metadata: metadata ?? this.metadata,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      originalFileName: data.originalFileName.present
          ? data.originalFileName.value
          : this.originalFileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      status: data.status.present ? data.status.value : this.status,
      extractedText: data.extractedText.present
          ? data.extractedText.value
          : this.extractedText,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      category: data.category.present ? data.category.value : this.category,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      failureMessage: data.failureMessage.present
          ? data.failureMessage.value
          : this.failureMessage,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('mimeType: $mimeType, ')
          ..write('originalFileName: $originalFileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('extractedText: $extractedText, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    name,
    source,
    mimeType,
    originalFileName,
    fileSize,
    filePath,
    status,
    extractedText,
    isFavorite,
    category,
    createdAt,
    updatedAt,
    lastOpenedAt,
    failureMessage,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.source == this.source &&
          other.mimeType == this.mimeType &&
          other.originalFileName == this.originalFileName &&
          other.fileSize == this.fileSize &&
          other.filePath == this.filePath &&
          other.status == this.status &&
          other.extractedText == this.extractedText &&
          other.isFavorite == this.isFavorite &&
          other.category == this.category &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.failureMessage == this.failureMessage &&
          other.metadata == this.metadata);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> source;
  final Value<String> mimeType;
  final Value<String?> originalFileName;
  final Value<int> fileSize;
  final Value<String?> filePath;
  final Value<String> status;
  final Value<String?> extractedText;
  final Value<bool> isFavorite;
  final Value<String?> category;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<String?> failureMessage;
  final Value<String> metadata;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.originalFileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.filePath = const Value.absent(),
    this.status = const Value.absent(),
    this.extractedText = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.metadata = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    required String source,
    required String mimeType,
    this.originalFileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.filePath = const Value.absent(),
    this.status = const Value.absent(),
    this.extractedText = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.metadata = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name),
       source = Value(source),
       mimeType = Value(mimeType);
  static Insertable<Document> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? source,
    Expression<String>? mimeType,
    Expression<String>? originalFileName,
    Expression<int>? fileSize,
    Expression<String>? filePath,
    Expression<String>? status,
    Expression<String>? extractedText,
    Expression<bool>? isFavorite,
    Expression<String>? category,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<String>? failureMessage,
    Expression<String>? metadata,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (mimeType != null) 'mime_type': mimeType,
      if (originalFileName != null) 'original_file_name': originalFileName,
      if (fileSize != null) 'file_size': fileSize,
      if (filePath != null) 'file_path': filePath,
      if (status != null) 'status': status,
      if (extractedText != null) 'extracted_text': extractedText,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (category != null) 'category': category,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (failureMessage != null) 'failure_message': failureMessage,
      if (metadata != null) 'metadata': metadata,
    });
  }

  DocumentsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? name,
    Value<String>? source,
    Value<String>? mimeType,
    Value<String?>? originalFileName,
    Value<int>? fileSize,
    Value<String?>? filePath,
    Value<String>? status,
    Value<String?>? extractedText,
    Value<bool>? isFavorite,
    Value<String?>? category,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<String?>? failureMessage,
    Value<String>? metadata,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      source: source ?? this.source,
      mimeType: mimeType ?? this.mimeType,
      originalFileName: originalFileName ?? this.originalFileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      extractedText: extractedText ?? this.extractedText,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      failureMessage: failureMessage ?? this.failureMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (originalFileName.present) {
      map['original_file_name'] = Variable<String>(originalFileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (extractedText.present) {
      map['extracted_text'] = Variable<String>(extractedText.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (failureMessage.present) {
      map['failure_message'] = Variable<String>(failureMessage.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('mimeType: $mimeType, ')
          ..write('originalFileName: $originalFileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('extractedText: $extractedText, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }
}

class $DocumentPagesTable extends DocumentPages
    with TableInfo<$DocumentPagesTable, DocumentPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    documentId,
    pageNumber,
    sourceType,
    imagePath,
    width,
    height,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentPage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_pageNumberMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentPage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DocumentPagesTable createAlias(String alias) {
    return $DocumentPagesTable(attachedDatabase, alias);
  }
}

class DocumentPage extends DataClass implements Insertable<DocumentPage> {
  final int id;
  final String uuid;
  final String documentId;
  final int pageNumber;
  final String sourceType;
  final String? imagePath;
  final int width;
  final int height;
  final DateTime createdAt;
  const DocumentPage({
    required this.id,
    required this.uuid,
    required this.documentId,
    required this.pageNumber,
    required this.sourceType,
    this.imagePath,
    required this.width,
    required this.height,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['document_id'] = Variable<String>(documentId);
    map['page_number'] = Variable<int>(pageNumber);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DocumentPagesCompanion toCompanion(bool nullToAbsent) {
    return DocumentPagesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      documentId: Value(documentId),
      pageNumber: Value(pageNumber),
      sourceType: Value(sourceType),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      width: Value(width),
      height: Value(height),
      createdAt: Value(createdAt),
    );
  }

  factory DocumentPage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentPage(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageNumber: serializer.fromJson<int>(json['pageNumber']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'documentId': serializer.toJson<String>(documentId),
      'pageNumber': serializer.toJson<int>(pageNumber),
      'sourceType': serializer.toJson<String>(sourceType),
      'imagePath': serializer.toJson<String?>(imagePath),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DocumentPage copyWith({
    int? id,
    String? uuid,
    String? documentId,
    int? pageNumber,
    String? sourceType,
    Value<String?> imagePath = const Value.absent(),
    int? width,
    int? height,
    DateTime? createdAt,
  }) => DocumentPage(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    documentId: documentId ?? this.documentId,
    pageNumber: pageNumber ?? this.pageNumber,
    sourceType: sourceType ?? this.sourceType,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    width: width ?? this.width,
    height: height ?? this.height,
    createdAt: createdAt ?? this.createdAt,
  );
  DocumentPage copyWithCompanion(DocumentPagesCompanion data) {
    return DocumentPage(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentPage(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sourceType: $sourceType, ')
          ..write('imagePath: $imagePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    documentId,
    pageNumber,
    sourceType,
    imagePath,
    width,
    height,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentPage &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.documentId == this.documentId &&
          other.pageNumber == this.pageNumber &&
          other.sourceType == this.sourceType &&
          other.imagePath == this.imagePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.createdAt == this.createdAt);
}

class DocumentPagesCompanion extends UpdateCompanion<DocumentPage> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> documentId;
  final Value<int> pageNumber;
  final Value<String> sourceType;
  final Value<String?> imagePath;
  final Value<int> width;
  final Value<int> height;
  final Value<DateTime> createdAt;
  const DocumentPagesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DocumentPagesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String documentId,
    required int pageNumber,
    required String sourceType,
    this.imagePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : uuid = Value(uuid),
       documentId = Value(documentId),
       pageNumber = Value(pageNumber),
       sourceType = Value(sourceType);
  static Insertable<DocumentPage> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? documentId,
    Expression<int>? pageNumber,
    Expression<String>? sourceType,
    Expression<String>? imagePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (documentId != null) 'document_id': documentId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (sourceType != null) 'source_type': sourceType,
      if (imagePath != null) 'image_path': imagePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DocumentPagesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? documentId,
    Value<int>? pageNumber,
    Value<String>? sourceType,
    Value<String?>? imagePath,
    Value<int>? width,
    Value<int>? height,
    Value<DateTime>? createdAt,
  }) {
    return DocumentPagesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      sourceType: sourceType ?? this.sourceType,
      imagePath: imagePath ?? this.imagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentPagesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sourceType: $sourceType, ')
          ..write('imagePath: $imagePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DocumentBlocksTable extends DocumentBlocks
    with TableInfo<$DocumentBlocksTable, DocumentBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftMeta = const VerificationMeta('left');
  @override
  late final GeneratedColumn<double> left = GeneratedColumn<double>(
    'left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topMeta = const VerificationMeta('top');
  @override
  late final GeneratedColumn<double> top = GeneratedColumn<double>(
    'top',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    documentId,
    pageId,
    type,
    level,
    content,
    order,
    left,
    top,
    width,
    height,
    confidence,
    createdAt,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    if (data.containsKey('left')) {
      context.handle(
        _leftMeta,
        left.isAcceptableOrUnknown(data['left']!, _leftMeta),
      );
    }
    if (data.containsKey('top')) {
      context.handle(
        _topMeta,
        top.isAcceptableOrUnknown(data['top']!, _topMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      )!,
      left: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}left'],
      ),
      top: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
    );
  }

  @override
  $DocumentBlocksTable createAlias(String alias) {
    return $DocumentBlocksTable(attachedDatabase, alias);
  }
}

class DocumentBlock extends DataClass implements Insertable<DocumentBlock> {
  final int id;
  final String uuid;
  final String documentId;
  final String? pageId;
  final String type;
  final int level;
  final String content;
  final int order;
  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final double? confidence;
  final DateTime createdAt;
  final String metadata;
  const DocumentBlock({
    required this.id,
    required this.uuid,
    required this.documentId,
    this.pageId,
    required this.type,
    required this.level,
    required this.content,
    required this.order,
    this.left,
    this.top,
    this.width,
    this.height,
    this.confidence,
    required this.createdAt,
    required this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['document_id'] = Variable<String>(documentId);
    if (!nullToAbsent || pageId != null) {
      map['page_id'] = Variable<String>(pageId);
    }
    map['type'] = Variable<String>(type);
    map['level'] = Variable<int>(level);
    map['content'] = Variable<String>(content);
    map['order'] = Variable<int>(order);
    if (!nullToAbsent || left != null) {
      map['left'] = Variable<double>(left);
    }
    if (!nullToAbsent || top != null) {
      map['top'] = Variable<double>(top);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<double>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<double>(height);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['metadata'] = Variable<String>(metadata);
    return map;
  }

  DocumentBlocksCompanion toCompanion(bool nullToAbsent) {
    return DocumentBlocksCompanion(
      id: Value(id),
      uuid: Value(uuid),
      documentId: Value(documentId),
      pageId: pageId == null && nullToAbsent
          ? const Value.absent()
          : Value(pageId),
      type: Value(type),
      level: Value(level),
      content: Value(content),
      order: Value(order),
      left: left == null && nullToAbsent ? const Value.absent() : Value(left),
      top: top == null && nullToAbsent ? const Value.absent() : Value(top),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      createdAt: Value(createdAt),
      metadata: Value(metadata),
    );
  }

  factory DocumentBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentBlock(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageId: serializer.fromJson<String?>(json['pageId']),
      type: serializer.fromJson<String>(json['type']),
      level: serializer.fromJson<int>(json['level']),
      content: serializer.fromJson<String>(json['content']),
      order: serializer.fromJson<int>(json['order']),
      left: serializer.fromJson<double?>(json['left']),
      top: serializer.fromJson<double?>(json['top']),
      width: serializer.fromJson<double?>(json['width']),
      height: serializer.fromJson<double?>(json['height']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      metadata: serializer.fromJson<String>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'documentId': serializer.toJson<String>(documentId),
      'pageId': serializer.toJson<String?>(pageId),
      'type': serializer.toJson<String>(type),
      'level': serializer.toJson<int>(level),
      'content': serializer.toJson<String>(content),
      'order': serializer.toJson<int>(order),
      'left': serializer.toJson<double?>(left),
      'top': serializer.toJson<double?>(top),
      'width': serializer.toJson<double?>(width),
      'height': serializer.toJson<double?>(height),
      'confidence': serializer.toJson<double?>(confidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'metadata': serializer.toJson<String>(metadata),
    };
  }

  DocumentBlock copyWith({
    int? id,
    String? uuid,
    String? documentId,
    Value<String?> pageId = const Value.absent(),
    String? type,
    int? level,
    String? content,
    int? order,
    Value<double?> left = const Value.absent(),
    Value<double?> top = const Value.absent(),
    Value<double?> width = const Value.absent(),
    Value<double?> height = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    DateTime? createdAt,
    String? metadata,
  }) => DocumentBlock(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    documentId: documentId ?? this.documentId,
    pageId: pageId.present ? pageId.value : this.pageId,
    type: type ?? this.type,
    level: level ?? this.level,
    content: content ?? this.content,
    order: order ?? this.order,
    left: left.present ? left.value : this.left,
    top: top.present ? top.value : this.top,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    confidence: confidence.present ? confidence.value : this.confidence,
    createdAt: createdAt ?? this.createdAt,
    metadata: metadata ?? this.metadata,
  );
  DocumentBlock copyWithCompanion(DocumentBlocksCompanion data) {
    return DocumentBlock(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      type: data.type.present ? data.type.value : this.type,
      level: data.level.present ? data.level.value : this.level,
      content: data.content.present ? data.content.value : this.content,
      order: data.order.present ? data.order.value : this.order,
      left: data.left.present ? data.left.value : this.left,
      top: data.top.present ? data.top.value : this.top,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentBlock(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageId: $pageId, ')
          ..write('type: $type, ')
          ..write('level: $level, ')
          ..write('content: $content, ')
          ..write('order: $order, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    documentId,
    pageId,
    type,
    level,
    content,
    order,
    left,
    top,
    width,
    height,
    confidence,
    createdAt,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentBlock &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.documentId == this.documentId &&
          other.pageId == this.pageId &&
          other.type == this.type &&
          other.level == this.level &&
          other.content == this.content &&
          other.order == this.order &&
          other.left == this.left &&
          other.top == this.top &&
          other.width == this.width &&
          other.height == this.height &&
          other.confidence == this.confidence &&
          other.createdAt == this.createdAt &&
          other.metadata == this.metadata);
}

class DocumentBlocksCompanion extends UpdateCompanion<DocumentBlock> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> documentId;
  final Value<String?> pageId;
  final Value<String> type;
  final Value<int> level;
  final Value<String> content;
  final Value<int> order;
  final Value<double?> left;
  final Value<double?> top;
  final Value<double?> width;
  final Value<double?> height;
  final Value<double?> confidence;
  final Value<DateTime> createdAt;
  final Value<String> metadata;
  const DocumentBlocksCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageId = const Value.absent(),
    this.type = const Value.absent(),
    this.level = const Value.absent(),
    this.content = const Value.absent(),
    this.order = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.metadata = const Value.absent(),
  });
  DocumentBlocksCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String documentId,
    this.pageId = const Value.absent(),
    required String type,
    this.level = const Value.absent(),
    required String content,
    required int order,
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.metadata = const Value.absent(),
  }) : uuid = Value(uuid),
       documentId = Value(documentId),
       type = Value(type),
       content = Value(content),
       order = Value(order);
  static Insertable<DocumentBlock> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? documentId,
    Expression<String>? pageId,
    Expression<String>? type,
    Expression<int>? level,
    Expression<String>? content,
    Expression<int>? order,
    Expression<double>? left,
    Expression<double>? top,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? confidence,
    Expression<DateTime>? createdAt,
    Expression<String>? metadata,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (documentId != null) 'document_id': documentId,
      if (pageId != null) 'page_id': pageId,
      if (type != null) 'type': type,
      if (level != null) 'level': level,
      if (content != null) 'content': content,
      if (order != null) 'order': order,
      if (left != null) 'left': left,
      if (top != null) 'top': top,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (confidence != null) 'confidence': confidence,
      if (createdAt != null) 'created_at': createdAt,
      if (metadata != null) 'metadata': metadata,
    });
  }

  DocumentBlocksCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? documentId,
    Value<String?>? pageId,
    Value<String>? type,
    Value<int>? level,
    Value<String>? content,
    Value<int>? order,
    Value<double?>? left,
    Value<double?>? top,
    Value<double?>? width,
    Value<double?>? height,
    Value<double?>? confidence,
    Value<DateTime>? createdAt,
    Value<String>? metadata,
  }) {
    return DocumentBlocksCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      documentId: documentId ?? this.documentId,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      level: level ?? this.level,
      content: content ?? this.content,
      order: order ?? this.order,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (left.present) {
      map['left'] = Variable<double>(left.value);
    }
    if (top.present) {
      map['top'] = Variable<double>(top.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentBlocksCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageId: $pageId, ')
          ..write('type: $type, ')
          ..write('level: $level, ')
          ..write('content: $content, ')
          ..write('order: $order, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }
}

class $DocumentImagesTable extends DocumentImages
    with TableInfo<$DocumentImagesTable, DocumentImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    documentId,
    pageId,
    pageNumber,
    sourceType,
    filePath,
    format,
    width,
    height,
    fileSize,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DocumentImagesTable createAlias(String alias) {
    return $DocumentImagesTable(attachedDatabase, alias);
  }
}

class DocumentImage extends DataClass implements Insertable<DocumentImage> {
  final int id;
  final String uuid;
  final String documentId;
  final String? pageId;
  final int? pageNumber;
  final String sourceType;
  final String filePath;
  final String format;
  final int width;
  final int height;
  final int fileSize;
  final DateTime createdAt;
  const DocumentImage({
    required this.id,
    required this.uuid,
    required this.documentId,
    this.pageId,
    this.pageNumber,
    required this.sourceType,
    required this.filePath,
    required this.format,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['document_id'] = Variable<String>(documentId);
    if (!nullToAbsent || pageId != null) {
      map['page_id'] = Variable<String>(pageId);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    map['source_type'] = Variable<String>(sourceType);
    map['file_path'] = Variable<String>(filePath);
    map['format'] = Variable<String>(format);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['file_size'] = Variable<int>(fileSize);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DocumentImagesCompanion toCompanion(bool nullToAbsent) {
    return DocumentImagesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      documentId: Value(documentId),
      pageId: pageId == null && nullToAbsent
          ? const Value.absent()
          : Value(pageId),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      sourceType: Value(sourceType),
      filePath: Value(filePath),
      format: Value(format),
      width: Value(width),
      height: Value(height),
      fileSize: Value(fileSize),
      createdAt: Value(createdAt),
    );
  }

  factory DocumentImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentImage(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageId: serializer.fromJson<String?>(json['pageId']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      filePath: serializer.fromJson<String>(json['filePath']),
      format: serializer.fromJson<String>(json['format']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'documentId': serializer.toJson<String>(documentId),
      'pageId': serializer.toJson<String?>(pageId),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'sourceType': serializer.toJson<String>(sourceType),
      'filePath': serializer.toJson<String>(filePath),
      'format': serializer.toJson<String>(format),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'fileSize': serializer.toJson<int>(fileSize),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DocumentImage copyWith({
    int? id,
    String? uuid,
    String? documentId,
    Value<String?> pageId = const Value.absent(),
    Value<int?> pageNumber = const Value.absent(),
    String? sourceType,
    String? filePath,
    String? format,
    int? width,
    int? height,
    int? fileSize,
    DateTime? createdAt,
  }) => DocumentImage(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    documentId: documentId ?? this.documentId,
    pageId: pageId.present ? pageId.value : this.pageId,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    sourceType: sourceType ?? this.sourceType,
    filePath: filePath ?? this.filePath,
    format: format ?? this.format,
    width: width ?? this.width,
    height: height ?? this.height,
    fileSize: fileSize ?? this.fileSize,
    createdAt: createdAt ?? this.createdAt,
  );
  DocumentImage copyWithCompanion(DocumentImagesCompanion data) {
    return DocumentImage(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      format: data.format.present ? data.format.value : this.format,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentImage(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageId: $pageId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sourceType: $sourceType, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    documentId,
    pageId,
    pageNumber,
    sourceType,
    filePath,
    format,
    width,
    height,
    fileSize,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentImage &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.documentId == this.documentId &&
          other.pageId == this.pageId &&
          other.pageNumber == this.pageNumber &&
          other.sourceType == this.sourceType &&
          other.filePath == this.filePath &&
          other.format == this.format &&
          other.width == this.width &&
          other.height == this.height &&
          other.fileSize == this.fileSize &&
          other.createdAt == this.createdAt);
}

class DocumentImagesCompanion extends UpdateCompanion<DocumentImage> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> documentId;
  final Value<String?> pageId;
  final Value<int?> pageNumber;
  final Value<String> sourceType;
  final Value<String> filePath;
  final Value<String> format;
  final Value<int> width;
  final Value<int> height;
  final Value<int> fileSize;
  final Value<DateTime> createdAt;
  const DocumentImagesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DocumentImagesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String documentId,
    this.pageId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    required String sourceType,
    required String filePath,
    required String format,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : uuid = Value(uuid),
       documentId = Value(documentId),
       sourceType = Value(sourceType),
       filePath = Value(filePath),
       format = Value(format);
  static Insertable<DocumentImage> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? documentId,
    Expression<String>? pageId,
    Expression<int>? pageNumber,
    Expression<String>? sourceType,
    Expression<String>? filePath,
    Expression<String>? format,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? fileSize,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (documentId != null) 'document_id': documentId,
      if (pageId != null) 'page_id': pageId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (sourceType != null) 'source_type': sourceType,
      if (filePath != null) 'file_path': filePath,
      if (format != null) 'format': format,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'file_size': fileSize,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DocumentImagesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? documentId,
    Value<String?>? pageId,
    Value<int?>? pageNumber,
    Value<String>? sourceType,
    Value<String>? filePath,
    Value<String>? format,
    Value<int>? width,
    Value<int>? height,
    Value<int>? fileSize,
    Value<DateTime>? createdAt,
  }) {
    return DocumentImagesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      documentId: documentId ?? this.documentId,
      pageId: pageId ?? this.pageId,
      pageNumber: pageNumber ?? this.pageNumber,
      sourceType: sourceType ?? this.sourceType,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentImagesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('documentId: $documentId, ')
          ..write('pageId: $pageId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sourceType: $sourceType, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TtsAudioTable extends TtsAudio
    with TableInfo<$TtsAudioTable, TtsAudioData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsAudioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _textHashMeta = const VerificationMeta(
    'textHash',
  );
  @override
  late final GeneratedColumn<String> textHash = GeneratedColumn<String>(
    'text_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _voiceIdMeta = const VerificationMeta(
    'voiceId',
  );
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
    'voice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(24000),
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    textHash,
    voiceId,
    speed,
    format,
    filePath,
    durationMs,
    sampleRate,
    channels,
    createdAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_audio';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsAudioData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('text_hash')) {
      context.handle(
        _textHashMeta,
        textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta),
      );
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('voice_id')) {
      context.handle(
        _voiceIdMeta,
        voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    } else if (isInserting) {
      context.missing(_speedMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsAudioData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsAudioData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      textHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_hash'],
      )!,
      voiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_id'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      )!,
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channels'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $TtsAudioTable createAlias(String alias) {
    return $TtsAudioTable(attachedDatabase, alias);
  }
}

class TtsAudioData extends DataClass implements Insertable<TtsAudioData> {
  final int id;
  final String textHash;
  final String? voiceId;
  final double speed;
  final String format;
  final String filePath;
  final int durationMs;
  final int sampleRate;
  final int channels;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  const TtsAudioData({
    required this.id,
    required this.textHash,
    this.voiceId,
    required this.speed,
    required this.format,
    required this.filePath,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    required this.createdAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['text_hash'] = Variable<String>(textHash);
    if (!nullToAbsent || voiceId != null) {
      map['voice_id'] = Variable<String>(voiceId);
    }
    map['speed'] = Variable<double>(speed);
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    map['duration_ms'] = Variable<int>(durationMs);
    map['sample_rate'] = Variable<int>(sampleRate);
    map['channels'] = Variable<int>(channels);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  TtsAudioCompanion toCompanion(bool nullToAbsent) {
    return TtsAudioCompanion(
      id: Value(id),
      textHash: Value(textHash),
      voiceId: voiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceId),
      speed: Value(speed),
      format: Value(format),
      filePath: Value(filePath),
      durationMs: Value(durationMs),
      sampleRate: Value(sampleRate),
      channels: Value(channels),
      createdAt: Value(createdAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory TtsAudioData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsAudioData(
      id: serializer.fromJson<int>(json['id']),
      textHash: serializer.fromJson<String>(json['textHash']),
      voiceId: serializer.fromJson<String?>(json['voiceId']),
      speed: serializer.fromJson<double>(json['speed']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sampleRate: serializer.fromJson<int>(json['sampleRate']),
      channels: serializer.fromJson<int>(json['channels']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'textHash': serializer.toJson<String>(textHash),
      'voiceId': serializer.toJson<String?>(voiceId),
      'speed': serializer.toJson<double>(speed),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'durationMs': serializer.toJson<int>(durationMs),
      'sampleRate': serializer.toJson<int>(sampleRate),
      'channels': serializer.toJson<int>(channels),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  TtsAudioData copyWith({
    int? id,
    String? textHash,
    Value<String?> voiceId = const Value.absent(),
    double? speed,
    String? format,
    String? filePath,
    int? durationMs,
    int? sampleRate,
    int? channels,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) => TtsAudioData(
    id: id ?? this.id,
    textHash: textHash ?? this.textHash,
    voiceId: voiceId.present ? voiceId.value : this.voiceId,
    speed: speed ?? this.speed,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    durationMs: durationMs ?? this.durationMs,
    sampleRate: sampleRate ?? this.sampleRate,
    channels: channels ?? this.channels,
    createdAt: createdAt ?? this.createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  TtsAudioData copyWithCompanion(TtsAudioCompanion data) {
    return TtsAudioData(
      id: data.id.present ? data.id.value : this.id,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      speed: data.speed.present ? data.speed.value : this.speed,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      channels: data.channels.present ? data.channels.value : this.channels,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsAudioData(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('voiceId: $voiceId, ')
          ..write('speed: $speed, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    textHash,
    voiceId,
    speed,
    format,
    filePath,
    durationMs,
    sampleRate,
    channels,
    createdAt,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsAudioData &&
          other.id == this.id &&
          other.textHash == this.textHash &&
          other.voiceId == this.voiceId &&
          other.speed == this.speed &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.durationMs == this.durationMs &&
          other.sampleRate == this.sampleRate &&
          other.channels == this.channels &&
          other.createdAt == this.createdAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class TtsAudioCompanion extends UpdateCompanion<TtsAudioData> {
  final Value<int> id;
  final Value<String> textHash;
  final Value<String?> voiceId;
  final Value<double> speed;
  final Value<String> format;
  final Value<String> filePath;
  final Value<int> durationMs;
  final Value<int> sampleRate;
  final Value<int> channels;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAccessedAt;
  const TtsAudioCompanion({
    this.id = const Value.absent(),
    this.textHash = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.speed = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  TtsAudioCompanion.insert({
    this.id = const Value.absent(),
    required String textHash,
    this.voiceId = const Value.absent(),
    required double speed,
    required String format,
    required String filePath,
    required int durationMs,
    this.sampleRate = const Value.absent(),
    this.channels = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  }) : textHash = Value(textHash),
       speed = Value(speed),
       format = Value(format),
       filePath = Value(filePath),
       durationMs = Value(durationMs);
  static Insertable<TtsAudioData> custom({
    Expression<int>? id,
    Expression<String>? textHash,
    Expression<String>? voiceId,
    Expression<double>? speed,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<int>? durationMs,
    Expression<int>? sampleRate,
    Expression<int>? channels,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textHash != null) 'text_hash': textHash,
      if (voiceId != null) 'voice_id': voiceId,
      if (speed != null) 'speed': speed,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (channels != null) 'channels': channels,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  TtsAudioCompanion copyWith({
    Value<int>? id,
    Value<String>? textHash,
    Value<String?>? voiceId,
    Value<double>? speed,
    Value<String>? format,
    Value<String>? filePath,
    Value<int>? durationMs,
    Value<int>? sampleRate,
    Value<int>? channels,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastAccessedAt,
  }) {
    return TtsAudioCompanion(
      id: id ?? this.id,
      textHash: textHash ?? this.textHash,
      voiceId: voiceId ?? this.voiceId,
      speed: speed ?? this.speed,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsAudioCompanion(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('voiceId: $voiceId, ')
          ..write('speed: $speed, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channels: $channels, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceIndexMeta = const VerificationMeta(
    'sentenceIndex',
  );
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
    'sentence_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    pageNumber,
    blockId,
    sentenceIndex,
    positionMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
        _sentenceIndexMeta,
        sentenceIndex.isAcceptableOrUnknown(
          data['sentence_index']!,
          _sentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      ),
      sentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_index'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final int id;
  final String documentId;
  final int? pageNumber;
  final String? blockId;
  final int sentenceIndex;
  final int positionMs;
  final DateTime updatedAt;
  const ReadingProgressData({
    required this.id,
    required this.documentId,
    this.pageNumber,
    this.blockId,
    required this.sentenceIndex,
    required this.positionMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['document_id'] = Variable<String>(documentId);
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    map['sentence_index'] = Variable<int>(sentenceIndex);
    map['position_ms'] = Variable<int>(positionMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      id: Value(id),
      documentId: Value(documentId),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      sentenceIndex: Value(sentenceIndex),
      positionMs: Value(positionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      id: serializer.fromJson<int>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      sentenceIndex: serializer.fromJson<int>(json['sentenceIndex']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'documentId': serializer.toJson<String>(documentId),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'blockId': serializer.toJson<String?>(blockId),
      'sentenceIndex': serializer.toJson<int>(sentenceIndex),
      'positionMs': serializer.toJson<int>(positionMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressData copyWith({
    int? id,
    String? documentId,
    Value<int?> pageNumber = const Value.absent(),
    Value<String?> blockId = const Value.absent(),
    int? sentenceIndex,
    int? positionMs,
    DateTime? updatedAt,
  }) => ReadingProgressData(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    blockId: blockId.present ? blockId.value : this.blockId,
    sentenceIndex: sentenceIndex ?? this.sentenceIndex,
    positionMs: positionMs ?? this.positionMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('blockId: $blockId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    pageNumber,
    blockId,
    sentenceIndex,
    positionMs,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageNumber == this.pageNumber &&
          other.blockId == this.blockId &&
          other.sentenceIndex == this.sentenceIndex &&
          other.positionMs == this.positionMs &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<int> id;
  final Value<String> documentId;
  final Value<int?> pageNumber;
  final Value<String?> blockId;
  final Value<int> sentenceIndex;
  final Value<int> positionMs;
  final Value<DateTime> updatedAt;
  const ReadingProgressCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.blockId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    this.id = const Value.absent(),
    required String documentId,
    this.pageNumber = const Value.absent(),
    this.blockId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : documentId = Value(documentId);
  static Insertable<ReadingProgressData> custom({
    Expression<int>? id,
    Expression<String>? documentId,
    Expression<int>? pageNumber,
    Expression<String>? blockId,
    Expression<int>? sentenceIndex,
    Expression<int>? positionMs,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (blockId != null) 'block_id': blockId,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<int>? id,
    Value<String>? documentId,
    Value<int?>? pageNumber,
    Value<String?>? blockId,
    Value<int>? sentenceIndex,
    Value<int>? positionMs,
    Value<DateTime>? updatedAt,
  }) {
    return ReadingProgressCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      blockId: blockId ?? this.blockId,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('blockId: $blockId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final String key;
  final String value;
  final DateTime updatedAt;
  const Setting({
    required this.id,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({
    int? id,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => Setting(
    id: id ?? this.id,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ModelsTable extends Models with TableInfo<$ModelsTable, Model> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _engineIdMeta = const VerificationMeta(
    'engineId',
  );
  @override
  late final GeneratedColumn<String> engineId = GeneratedColumn<String>(
    'engine_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointNameMeta = const VerificationMeta(
    'checkpointName',
  );
  @override
  late final GeneratedColumn<String> checkpointName = GeneratedColumn<String>(
    'checkpoint_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isInstalledMeta = const VerificationMeta(
    'isInstalled',
  );
  @override
  late final GeneratedColumn<bool> isInstalled = GeneratedColumn<bool>(
    'is_installed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_installed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    engineId,
    checkpointName,
    version,
    license,
    sizeBytes,
    filePath,
    isInstalled,
    isActive,
    checksum,
    installedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models';
  @override
  VerificationContext validateIntegrity(
    Insertable<Model> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('engine_id')) {
      context.handle(
        _engineIdMeta,
        engineId.isAcceptableOrUnknown(data['engine_id']!, _engineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_engineIdMeta);
    }
    if (data.containsKey('checkpoint_name')) {
      context.handle(
        _checkpointNameMeta,
        checkpointName.isAcceptableOrUnknown(
          data['checkpoint_name']!,
          _checkpointNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkpointNameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    } else if (isInserting) {
      context.missing(_licenseMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('is_installed')) {
      context.handle(
        _isInstalledMeta,
        isInstalled.isAcceptableOrUnknown(
          data['is_installed']!,
          _isInstalledMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Model map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Model(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      engineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_id'],
      )!,
      checkpointName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint_name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      isInstalled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_installed'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ModelsTable createAlias(String alias) {
    return $ModelsTable(attachedDatabase, alias);
  }
}

class Model extends DataClass implements Insertable<Model> {
  final int id;
  final String uuid;
  final String engineId;
  final String checkpointName;
  final String version;
  final String license;
  final int sizeBytes;
  final String? filePath;
  final bool isInstalled;
  final bool isActive;
  final String? checksum;
  final DateTime? installedAt;
  final DateTime createdAt;
  const Model({
    required this.id,
    required this.uuid,
    required this.engineId,
    required this.checkpointName,
    required this.version,
    required this.license,
    required this.sizeBytes,
    this.filePath,
    required this.isInstalled,
    required this.isActive,
    this.checksum,
    this.installedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['engine_id'] = Variable<String>(engineId);
    map['checkpoint_name'] = Variable<String>(checkpointName);
    map['version'] = Variable<String>(version);
    map['license'] = Variable<String>(license);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['is_installed'] = Variable<bool>(isInstalled);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || installedAt != null) {
      map['installed_at'] = Variable<DateTime>(installedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ModelsCompanion toCompanion(bool nullToAbsent) {
    return ModelsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      engineId: Value(engineId),
      checkpointName: Value(checkpointName),
      version: Value(version),
      license: Value(license),
      sizeBytes: Value(sizeBytes),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      isInstalled: Value(isInstalled),
      isActive: Value(isActive),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      installedAt: installedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(installedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Model.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Model(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      engineId: serializer.fromJson<String>(json['engineId']),
      checkpointName: serializer.fromJson<String>(json['checkpointName']),
      version: serializer.fromJson<String>(json['version']),
      license: serializer.fromJson<String>(json['license']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      isInstalled: serializer.fromJson<bool>(json['isInstalled']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      installedAt: serializer.fromJson<DateTime?>(json['installedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'engineId': serializer.toJson<String>(engineId),
      'checkpointName': serializer.toJson<String>(checkpointName),
      'version': serializer.toJson<String>(version),
      'license': serializer.toJson<String>(license),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'filePath': serializer.toJson<String?>(filePath),
      'isInstalled': serializer.toJson<bool>(isInstalled),
      'isActive': serializer.toJson<bool>(isActive),
      'checksum': serializer.toJson<String?>(checksum),
      'installedAt': serializer.toJson<DateTime?>(installedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Model copyWith({
    int? id,
    String? uuid,
    String? engineId,
    String? checkpointName,
    String? version,
    String? license,
    int? sizeBytes,
    Value<String?> filePath = const Value.absent(),
    bool? isInstalled,
    bool? isActive,
    Value<String?> checksum = const Value.absent(),
    Value<DateTime?> installedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Model(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    engineId: engineId ?? this.engineId,
    checkpointName: checkpointName ?? this.checkpointName,
    version: version ?? this.version,
    license: license ?? this.license,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    filePath: filePath.present ? filePath.value : this.filePath,
    isInstalled: isInstalled ?? this.isInstalled,
    isActive: isActive ?? this.isActive,
    checksum: checksum.present ? checksum.value : this.checksum,
    installedAt: installedAt.present ? installedAt.value : this.installedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Model copyWithCompanion(ModelsCompanion data) {
    return Model(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      engineId: data.engineId.present ? data.engineId.value : this.engineId,
      checkpointName: data.checkpointName.present
          ? data.checkpointName.value
          : this.checkpointName,
      version: data.version.present ? data.version.value : this.version,
      license: data.license.present ? data.license.value : this.license,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      isInstalled: data.isInstalled.present
          ? data.isInstalled.value
          : this.isInstalled,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Model(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('engineId: $engineId, ')
          ..write('checkpointName: $checkpointName, ')
          ..write('version: $version, ')
          ..write('license: $license, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('filePath: $filePath, ')
          ..write('isInstalled: $isInstalled, ')
          ..write('isActive: $isActive, ')
          ..write('checksum: $checksum, ')
          ..write('installedAt: $installedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    engineId,
    checkpointName,
    version,
    license,
    sizeBytes,
    filePath,
    isInstalled,
    isActive,
    checksum,
    installedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.engineId == this.engineId &&
          other.checkpointName == this.checkpointName &&
          other.version == this.version &&
          other.license == this.license &&
          other.sizeBytes == this.sizeBytes &&
          other.filePath == this.filePath &&
          other.isInstalled == this.isInstalled &&
          other.isActive == this.isActive &&
          other.checksum == this.checksum &&
          other.installedAt == this.installedAt &&
          other.createdAt == this.createdAt);
}

class ModelsCompanion extends UpdateCompanion<Model> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> engineId;
  final Value<String> checkpointName;
  final Value<String> version;
  final Value<String> license;
  final Value<int> sizeBytes;
  final Value<String?> filePath;
  final Value<bool> isInstalled;
  final Value<bool> isActive;
  final Value<String?> checksum;
  final Value<DateTime?> installedAt;
  final Value<DateTime> createdAt;
  const ModelsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.engineId = const Value.absent(),
    this.checkpointName = const Value.absent(),
    this.version = const Value.absent(),
    this.license = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.isInstalled = const Value.absent(),
    this.isActive = const Value.absent(),
    this.checksum = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ModelsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String engineId,
    required String checkpointName,
    required String version,
    required String license,
    this.sizeBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.isInstalled = const Value.absent(),
    this.isActive = const Value.absent(),
    this.checksum = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : uuid = Value(uuid),
       engineId = Value(engineId),
       checkpointName = Value(checkpointName),
       version = Value(version),
       license = Value(license);
  static Insertable<Model> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? engineId,
    Expression<String>? checkpointName,
    Expression<String>? version,
    Expression<String>? license,
    Expression<int>? sizeBytes,
    Expression<String>? filePath,
    Expression<bool>? isInstalled,
    Expression<bool>? isActive,
    Expression<String>? checksum,
    Expression<DateTime>? installedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (engineId != null) 'engine_id': engineId,
      if (checkpointName != null) 'checkpoint_name': checkpointName,
      if (version != null) 'version': version,
      if (license != null) 'license': license,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (filePath != null) 'file_path': filePath,
      if (isInstalled != null) 'is_installed': isInstalled,
      if (isActive != null) 'is_active': isActive,
      if (checksum != null) 'checksum': checksum,
      if (installedAt != null) 'installed_at': installedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ModelsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? engineId,
    Value<String>? checkpointName,
    Value<String>? version,
    Value<String>? license,
    Value<int>? sizeBytes,
    Value<String?>? filePath,
    Value<bool>? isInstalled,
    Value<bool>? isActive,
    Value<String?>? checksum,
    Value<DateTime?>? installedAt,
    Value<DateTime>? createdAt,
  }) {
    return ModelsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      engineId: engineId ?? this.engineId,
      checkpointName: checkpointName ?? this.checkpointName,
      version: version ?? this.version,
      license: license ?? this.license,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      filePath: filePath ?? this.filePath,
      isInstalled: isInstalled ?? this.isInstalled,
      isActive: isActive ?? this.isActive,
      checksum: checksum ?? this.checksum,
      installedAt: installedAt ?? this.installedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (engineId.present) {
      map['engine_id'] = Variable<String>(engineId.value);
    }
    if (checkpointName.present) {
      map['checkpoint_name'] = Variable<String>(checkpointName.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (isInstalled.present) {
      map['is_installed'] = Variable<bool>(isInstalled.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('engineId: $engineId, ')
          ..write('checkpointName: $checkpointName, ')
          ..write('version: $version, ')
          ..write('license: $license, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('filePath: $filePath, ')
          ..write('isInstalled: $isInstalled, ')
          ..write('isActive: $isActive, ')
          ..write('checksum: $checksum, ')
          ..write('installedAt: $installedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTable extends ProcessingJobs
    with TableInfo<$ProcessingJobsTable, ProcessingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    type,
    documentId,
    status,
    progress,
    errorMessage,
    payload,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessingJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProcessingJobsTable createAlias(String alias) {
    return $ProcessingJobsTable(attachedDatabase, alias);
  }
}

class ProcessingJob extends DataClass implements Insertable<ProcessingJob> {
  final int id;
  final String uuid;
  final String type;
  final String? documentId;
  final String status;
  final int progress;
  final String? errorMessage;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProcessingJob({
    required this.id,
    required this.uuid,
    required this.type,
    this.documentId,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      type: Value(type),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      status: Value(status),
      progress: Value(progress),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProcessingJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJob(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      type: serializer.fromJson<String>(json['type']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'type': serializer.toJson<String>(type),
      'documentId': serializer.toJson<String?>(documentId),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProcessingJob copyWith({
    int? id,
    String? uuid,
    String? type,
    Value<String?> documentId = const Value.absent(),
    String? status,
    int? progress,
    Value<String?> errorMessage = const Value.absent(),
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProcessingJob(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    type: type ?? this.type,
    documentId: documentId.present ? documentId.value : this.documentId,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProcessingJob copyWithCompanion(ProcessingJobsCompanion data) {
    return ProcessingJob(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      type: data.type.present ? data.type.value : this.type,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJob(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('type: $type, ')
          ..write('documentId: $documentId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    type,
    documentId,
    status,
    progress,
    errorMessage,
    payload,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.type == this.type &&
          other.documentId == this.documentId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.errorMessage == this.errorMessage &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProcessingJobsCompanion extends UpdateCompanion<ProcessingJob> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> type;
  final Value<String?> documentId;
  final Value<String> status;
  final Value<int> progress;
  final Value<String?> errorMessage;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.type = const Value.absent(),
    this.documentId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProcessingJobsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String type,
    this.documentId = const Value.absent(),
    required String status,
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       type = Value(type),
       status = Value(status);
  static Insertable<ProcessingJob> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? type,
    Expression<String>? documentId,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<String>? errorMessage,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (type != null) 'type': type,
      if (documentId != null) 'document_id': documentId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (errorMessage != null) 'error_message': errorMessage,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProcessingJobsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? type,
    Value<String?>? documentId,
    Value<String>? status,
    Value<int>? progress,
    Value<String?>? errorMessage,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ProcessingJobsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      documentId: documentId ?? this.documentId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('type: $type, ')
          ..write('documentId: $documentId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $DocumentPagesTable documentPages = $DocumentPagesTable(this);
  late final $DocumentBlocksTable documentBlocks = $DocumentBlocksTable(this);
  late final $DocumentImagesTable documentImages = $DocumentImagesTable(this);
  late final $TtsAudioTable ttsAudio = $TtsAudioTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ModelsTable models = $ModelsTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documents,
    documentPages,
    documentBlocks,
    documentImages,
    ttsAudio,
    readingProgress,
    settings,
    models,
    processingJobs,
  ];
}

typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      Value<int> id,
      required String uuid,
      required String name,
      required String source,
      required String mimeType,
      Value<String?> originalFileName,
      Value<int> fileSize,
      Value<String?> filePath,
      Value<String> status,
      Value<String?> extractedText,
      Value<bool> isFavorite,
      Value<String?> category,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<String?> failureMessage,
      Value<String> metadata,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> name,
      Value<String> source,
      Value<String> mimeType,
      Value<String?> originalFileName,
      Value<int> fileSize,
      Value<String?> filePath,
      Value<String> status,
      Value<String?> extractedText,
      Value<bool> isFavorite,
      Value<String?> category,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<String?> failureMessage,
      Value<String> metadata,
    });

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get extractedText => $composableBuilder(
    column: $table.extractedText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
          Document,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String?> originalFileName = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> extractedText = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<String> metadata = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                uuid: uuid,
                name: name,
                source: source,
                mimeType: mimeType,
                originalFileName: originalFileName,
                fileSize: fileSize,
                filePath: filePath,
                status: status,
                extractedText: extractedText,
                isFavorite: isFavorite,
                category: category,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                failureMessage: failureMessage,
                metadata: metadata,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String name,
                required String source,
                required String mimeType,
                Value<String?> originalFileName = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> extractedText = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<String> metadata = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                uuid: uuid,
                name: name,
                source: source,
                mimeType: mimeType,
                originalFileName: originalFileName,
                fileSize: fileSize,
                filePath: filePath,
                status: status,
                extractedText: extractedText,
                isFavorite: isFavorite,
                category: category,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                failureMessage: failureMessage,
                metadata: metadata,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
      Document,
      PrefetchHooks Function()
    >;
typedef $$DocumentPagesTableCreateCompanionBuilder =
    DocumentPagesCompanion Function({
      Value<int> id,
      required String uuid,
      required String documentId,
      required int pageNumber,
      required String sourceType,
      Value<String?> imagePath,
      Value<int> width,
      Value<int> height,
      Value<DateTime> createdAt,
    });
typedef $$DocumentPagesTableUpdateCompanionBuilder =
    DocumentPagesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> documentId,
      Value<int> pageNumber,
      Value<String> sourceType,
      Value<String?> imagePath,
      Value<int> width,
      Value<int> height,
      Value<DateTime> createdAt,
    });

class $$DocumentPagesTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentPagesTable> {
  $$DocumentPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentPagesTable> {
  $$DocumentPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentPagesTable> {
  $$DocumentPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DocumentPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentPagesTable,
          DocumentPage,
          $$DocumentPagesTableFilterComposer,
          $$DocumentPagesTableOrderingComposer,
          $$DocumentPagesTableAnnotationComposer,
          $$DocumentPagesTableCreateCompanionBuilder,
          $$DocumentPagesTableUpdateCompanionBuilder,
          (
            DocumentPage,
            BaseReferences<_$AppDatabase, $DocumentPagesTable, DocumentPage>,
          ),
          DocumentPage,
          PrefetchHooks Function()
        > {
  $$DocumentPagesTableTableManager(_$AppDatabase db, $DocumentPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> pageNumber = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DocumentPagesCompanion(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageNumber: pageNumber,
                sourceType: sourceType,
                imagePath: imagePath,
                width: width,
                height: height,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String documentId,
                required int pageNumber,
                required String sourceType,
                Value<String?> imagePath = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DocumentPagesCompanion.insert(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageNumber: pageNumber,
                sourceType: sourceType,
                imagePath: imagePath,
                width: width,
                height: height,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentPagesTable,
      DocumentPage,
      $$DocumentPagesTableFilterComposer,
      $$DocumentPagesTableOrderingComposer,
      $$DocumentPagesTableAnnotationComposer,
      $$DocumentPagesTableCreateCompanionBuilder,
      $$DocumentPagesTableUpdateCompanionBuilder,
      (
        DocumentPage,
        BaseReferences<_$AppDatabase, $DocumentPagesTable, DocumentPage>,
      ),
      DocumentPage,
      PrefetchHooks Function()
    >;
typedef $$DocumentBlocksTableCreateCompanionBuilder =
    DocumentBlocksCompanion Function({
      Value<int> id,
      required String uuid,
      required String documentId,
      Value<String?> pageId,
      required String type,
      Value<int> level,
      required String content,
      required int order,
      Value<double?> left,
      Value<double?> top,
      Value<double?> width,
      Value<double?> height,
      Value<double?> confidence,
      Value<DateTime> createdAt,
      Value<String> metadata,
    });
typedef $$DocumentBlocksTableUpdateCompanionBuilder =
    DocumentBlocksCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> documentId,
      Value<String?> pageId,
      Value<String> type,
      Value<int> level,
      Value<String> content,
      Value<int> order,
      Value<double?> left,
      Value<double?> top,
      Value<double?> width,
      Value<double?> height,
      Value<double?> confidence,
      Value<DateTime> createdAt,
      Value<String> metadata,
    });

class $$DocumentBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pageId =>
      $composableBuilder(column: $table.pageId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<double> get left =>
      $composableBuilder(column: $table.left, builder: (column) => column);

  GeneratedColumn<double> get top =>
      $composableBuilder(column: $table.top, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$DocumentBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentBlocksTable,
          DocumentBlock,
          $$DocumentBlocksTableFilterComposer,
          $$DocumentBlocksTableOrderingComposer,
          $$DocumentBlocksTableAnnotationComposer,
          $$DocumentBlocksTableCreateCompanionBuilder,
          $$DocumentBlocksTableUpdateCompanionBuilder,
          (
            DocumentBlock,
            BaseReferences<_$AppDatabase, $DocumentBlocksTable, DocumentBlock>,
          ),
          DocumentBlock,
          PrefetchHooks Function()
        > {
  $$DocumentBlocksTableTableManager(
    _$AppDatabase db,
    $DocumentBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String?> pageId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> order = const Value.absent(),
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> metadata = const Value.absent(),
              }) => DocumentBlocksCompanion(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageId: pageId,
                type: type,
                level: level,
                content: content,
                order: order,
                left: left,
                top: top,
                width: width,
                height: height,
                confidence: confidence,
                createdAt: createdAt,
                metadata: metadata,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String documentId,
                Value<String?> pageId = const Value.absent(),
                required String type,
                Value<int> level = const Value.absent(),
                required String content,
                required int order,
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> height = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> metadata = const Value.absent(),
              }) => DocumentBlocksCompanion.insert(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageId: pageId,
                type: type,
                level: level,
                content: content,
                order: order,
                left: left,
                top: top,
                width: width,
                height: height,
                confidence: confidence,
                createdAt: createdAt,
                metadata: metadata,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentBlocksTable,
      DocumentBlock,
      $$DocumentBlocksTableFilterComposer,
      $$DocumentBlocksTableOrderingComposer,
      $$DocumentBlocksTableAnnotationComposer,
      $$DocumentBlocksTableCreateCompanionBuilder,
      $$DocumentBlocksTableUpdateCompanionBuilder,
      (
        DocumentBlock,
        BaseReferences<_$AppDatabase, $DocumentBlocksTable, DocumentBlock>,
      ),
      DocumentBlock,
      PrefetchHooks Function()
    >;
typedef $$DocumentImagesTableCreateCompanionBuilder =
    DocumentImagesCompanion Function({
      Value<int> id,
      required String uuid,
      required String documentId,
      Value<String?> pageId,
      Value<int?> pageNumber,
      required String sourceType,
      required String filePath,
      required String format,
      Value<int> width,
      Value<int> height,
      Value<int> fileSize,
      Value<DateTime> createdAt,
    });
typedef $$DocumentImagesTableUpdateCompanionBuilder =
    DocumentImagesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> documentId,
      Value<String?> pageId,
      Value<int?> pageNumber,
      Value<String> sourceType,
      Value<String> filePath,
      Value<String> format,
      Value<int> width,
      Value<int> height,
      Value<int> fileSize,
      Value<DateTime> createdAt,
    });

class $$DocumentImagesTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentImagesTable> {
  $$DocumentImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentImagesTable> {
  $$DocumentImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentImagesTable> {
  $$DocumentImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pageId =>
      $composableBuilder(column: $table.pageId, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DocumentImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentImagesTable,
          DocumentImage,
          $$DocumentImagesTableFilterComposer,
          $$DocumentImagesTableOrderingComposer,
          $$DocumentImagesTableAnnotationComposer,
          $$DocumentImagesTableCreateCompanionBuilder,
          $$DocumentImagesTableUpdateCompanionBuilder,
          (
            DocumentImage,
            BaseReferences<_$AppDatabase, $DocumentImagesTable, DocumentImage>,
          ),
          DocumentImage,
          PrefetchHooks Function()
        > {
  $$DocumentImagesTableTableManager(
    _$AppDatabase db,
    $DocumentImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String?> pageId = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DocumentImagesCompanion(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageId: pageId,
                pageNumber: pageNumber,
                sourceType: sourceType,
                filePath: filePath,
                format: format,
                width: width,
                height: height,
                fileSize: fileSize,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String documentId,
                Value<String?> pageId = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                required String sourceType,
                required String filePath,
                required String format,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DocumentImagesCompanion.insert(
                id: id,
                uuid: uuid,
                documentId: documentId,
                pageId: pageId,
                pageNumber: pageNumber,
                sourceType: sourceType,
                filePath: filePath,
                format: format,
                width: width,
                height: height,
                fileSize: fileSize,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentImagesTable,
      DocumentImage,
      $$DocumentImagesTableFilterComposer,
      $$DocumentImagesTableOrderingComposer,
      $$DocumentImagesTableAnnotationComposer,
      $$DocumentImagesTableCreateCompanionBuilder,
      $$DocumentImagesTableUpdateCompanionBuilder,
      (
        DocumentImage,
        BaseReferences<_$AppDatabase, $DocumentImagesTable, DocumentImage>,
      ),
      DocumentImage,
      PrefetchHooks Function()
    >;
typedef $$TtsAudioTableCreateCompanionBuilder =
    TtsAudioCompanion Function({
      Value<int> id,
      required String textHash,
      Value<String?> voiceId,
      required double speed,
      required String format,
      required String filePath,
      required int durationMs,
      Value<int> sampleRate,
      Value<int> channels,
      Value<DateTime> createdAt,
      Value<DateTime> lastAccessedAt,
    });
typedef $$TtsAudioTableUpdateCompanionBuilder =
    TtsAudioCompanion Function({
      Value<int> id,
      Value<String> textHash,
      Value<String?> voiceId,
      Value<double> speed,
      Value<String> format,
      Value<String> filePath,
      Value<int> durationMs,
      Value<int> sampleRate,
      Value<int> channels,
      Value<DateTime> createdAt,
      Value<DateTime> lastAccessedAt,
    });

class $$TtsAudioTableFilterComposer
    extends Composer<_$AppDatabase, $TtsAudioTable> {
  $$TtsAudioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TtsAudioTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsAudioTable> {
  $$TtsAudioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TtsAudioTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsAudioTable> {
  $$TtsAudioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<String> get voiceId =>
      $composableBuilder(column: $table.voiceId, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$TtsAudioTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsAudioTable,
          TtsAudioData,
          $$TtsAudioTableFilterComposer,
          $$TtsAudioTableOrderingComposer,
          $$TtsAudioTableAnnotationComposer,
          $$TtsAudioTableCreateCompanionBuilder,
          $$TtsAudioTableUpdateCompanionBuilder,
          (
            TtsAudioData,
            BaseReferences<_$AppDatabase, $TtsAudioTable, TtsAudioData>,
          ),
          TtsAudioData,
          PrefetchHooks Function()
        > {
  $$TtsAudioTableTableManager(_$AppDatabase db, $TtsAudioTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsAudioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsAudioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsAudioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> textHash = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sampleRate = const Value.absent(),
                Value<int> channels = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
              }) => TtsAudioCompanion(
                id: id,
                textHash: textHash,
                voiceId: voiceId,
                speed: speed,
                format: format,
                filePath: filePath,
                durationMs: durationMs,
                sampleRate: sampleRate,
                channels: channels,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String textHash,
                Value<String?> voiceId = const Value.absent(),
                required double speed,
                required String format,
                required String filePath,
                required int durationMs,
                Value<int> sampleRate = const Value.absent(),
                Value<int> channels = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
              }) => TtsAudioCompanion.insert(
                id: id,
                textHash: textHash,
                voiceId: voiceId,
                speed: speed,
                format: format,
                filePath: filePath,
                durationMs: durationMs,
                sampleRate: sampleRate,
                channels: channels,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TtsAudioTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsAudioTable,
      TtsAudioData,
      $$TtsAudioTableFilterComposer,
      $$TtsAudioTableOrderingComposer,
      $$TtsAudioTableAnnotationComposer,
      $$TtsAudioTableCreateCompanionBuilder,
      $$TtsAudioTableUpdateCompanionBuilder,
      (
        TtsAudioData,
        BaseReferences<_$AppDatabase, $TtsAudioTable, TtsAudioData>,
      ),
      TtsAudioData,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<int> id,
      required String documentId,
      Value<int?> pageNumber,
      Value<String?> blockId,
      Value<int> sentenceIndex,
      Value<int> positionMs,
      Value<DateTime> updatedAt,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<int> id,
      Value<String> documentId,
      Value<int?> pageNumber,
      Value<String?> blockId,
      Value<int> sentenceIndex,
      Value<int> positionMs,
      Value<DateTime> updatedAt,
    });

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressData,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressTable,
              ReadingProgressData
            >,
          ),
          ReadingProgressData,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int> sentenceIndex = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingProgressCompanion(
                id: id,
                documentId: documentId,
                pageNumber: pageNumber,
                blockId: blockId,
                sentenceIndex: sentenceIndex,
                positionMs: positionMs,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String documentId,
                Value<int?> pageNumber = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int> sentenceIndex = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                id: id,
                documentId: documentId,
                pageNumber: pageNumber,
                blockId: blockId,
                sentenceIndex: sentenceIndex,
                positionMs: positionMs,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressData,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData
        >,
      ),
      ReadingProgressData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      required String key,
      required String value,
      Value<DateTime> updatedAt,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                key: key,
                value: value,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                key: key,
                value: value,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ModelsTableCreateCompanionBuilder =
    ModelsCompanion Function({
      Value<int> id,
      required String uuid,
      required String engineId,
      required String checkpointName,
      required String version,
      required String license,
      Value<int> sizeBytes,
      Value<String?> filePath,
      Value<bool> isInstalled,
      Value<bool> isActive,
      Value<String?> checksum,
      Value<DateTime?> installedAt,
      Value<DateTime> createdAt,
    });
typedef $$ModelsTableUpdateCompanionBuilder =
    ModelsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> engineId,
      Value<String> checkpointName,
      Value<String> version,
      Value<String> license,
      Value<int> sizeBytes,
      Value<String?> filePath,
      Value<bool> isInstalled,
      Value<bool> isActive,
      Value<String?> checksum,
      Value<DateTime?> installedAt,
      Value<DateTime> createdAt,
    });

class $$ModelsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpointName => $composableBuilder(
    column: $table.checkpointName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInstalled => $composableBuilder(
    column: $table.isInstalled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpointName => $composableBuilder(
    column: $table.checkpointName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInstalled => $composableBuilder(
    column: $table.isInstalled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get engineId =>
      $composableBuilder(column: $table.engineId, builder: (column) => column);

  GeneratedColumn<String> get checkpointName => $composableBuilder(
    column: $table.checkpointName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<bool> get isInstalled => $composableBuilder(
    column: $table.isInstalled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ModelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelsTable,
          Model,
          $$ModelsTableFilterComposer,
          $$ModelsTableOrderingComposer,
          $$ModelsTableAnnotationComposer,
          $$ModelsTableCreateCompanionBuilder,
          $$ModelsTableUpdateCompanionBuilder,
          (Model, BaseReferences<_$AppDatabase, $ModelsTable, Model>),
          Model,
          PrefetchHooks Function()
        > {
  $$ModelsTableTableManager(_$AppDatabase db, $ModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> engineId = const Value.absent(),
                Value<String> checkpointName = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> license = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<bool> isInstalled = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<DateTime?> installedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ModelsCompanion(
                id: id,
                uuid: uuid,
                engineId: engineId,
                checkpointName: checkpointName,
                version: version,
                license: license,
                sizeBytes: sizeBytes,
                filePath: filePath,
                isInstalled: isInstalled,
                isActive: isActive,
                checksum: checksum,
                installedAt: installedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String engineId,
                required String checkpointName,
                required String version,
                required String license,
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<bool> isInstalled = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<DateTime?> installedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ModelsCompanion.insert(
                id: id,
                uuid: uuid,
                engineId: engineId,
                checkpointName: checkpointName,
                version: version,
                license: license,
                sizeBytes: sizeBytes,
                filePath: filePath,
                isInstalled: isInstalled,
                isActive: isActive,
                checksum: checksum,
                installedAt: installedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelsTable,
      Model,
      $$ModelsTableFilterComposer,
      $$ModelsTableOrderingComposer,
      $$ModelsTableAnnotationComposer,
      $$ModelsTableCreateCompanionBuilder,
      $$ModelsTableUpdateCompanionBuilder,
      (Model, BaseReferences<_$AppDatabase, $ModelsTable, Model>),
      Model,
      PrefetchHooks Function()
    >;
typedef $$ProcessingJobsTableCreateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<int> id,
      required String uuid,
      required String type,
      Value<String?> documentId,
      required String status,
      Value<int> progress,
      Value<String?> errorMessage,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ProcessingJobsTableUpdateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> type,
      Value<String?> documentId,
      Value<String> status,
      Value<int> progress,
      Value<String?> errorMessage,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ProcessingJobsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProcessingJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProcessingJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProcessingJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessingJobsTable,
          ProcessingJob,
          $$ProcessingJobsTableFilterComposer,
          $$ProcessingJobsTableOrderingComposer,
          $$ProcessingJobsTableAnnotationComposer,
          $$ProcessingJobsTableCreateCompanionBuilder,
          $$ProcessingJobsTableUpdateCompanionBuilder,
          (
            ProcessingJob,
            BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob>,
          ),
          ProcessingJob,
          PrefetchHooks Function()
        > {
  $$ProcessingJobsTableTableManager(
    _$AppDatabase db,
    $ProcessingJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProcessingJobsCompanion(
                id: id,
                uuid: uuid,
                type: type,
                documentId: documentId,
                status: status,
                progress: progress,
                errorMessage: errorMessage,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String type,
                Value<String?> documentId = const Value.absent(),
                required String status,
                Value<int> progress = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProcessingJobsCompanion.insert(
                id: id,
                uuid: uuid,
                type: type,
                documentId: documentId,
                status: status,
                progress: progress,
                errorMessage: errorMessage,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProcessingJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessingJobsTable,
      ProcessingJob,
      $$ProcessingJobsTableFilterComposer,
      $$ProcessingJobsTableOrderingComposer,
      $$ProcessingJobsTableAnnotationComposer,
      $$ProcessingJobsTableCreateCompanionBuilder,
      $$ProcessingJobsTableUpdateCompanionBuilder,
      (
        ProcessingJob,
        BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob>,
      ),
      ProcessingJob,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$DocumentPagesTableTableManager get documentPages =>
      $$DocumentPagesTableTableManager(_db, _db.documentPages);
  $$DocumentBlocksTableTableManager get documentBlocks =>
      $$DocumentBlocksTableTableManager(_db, _db.documentBlocks);
  $$DocumentImagesTableTableManager get documentImages =>
      $$DocumentImagesTableTableManager(_db, _db.documentImages);
  $$TtsAudioTableTableManager get ttsAudio =>
      $$TtsAudioTableTableManager(_db, _db.ttsAudio);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
}
