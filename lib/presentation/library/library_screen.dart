import 'dart:async' show unawaited;

import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show RoutePaths;
import '../../core/share/share_intent.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/result/result.dart' show AppFailure, Failure, Result, Success;
import '../../data/providers.dart';
import '../../domain/engines/progress.dart' show JobStage, ProgressCallback;
import '../../domain/import/document_importer.dart' show DocumentImporter, ImportDocumentResult;
import '../../domain/models/document.dart' show DocumentSource, DocumentStatus, DocumentSortBy, Document;
import '../common/brief_error_label.dart';
import '../common/empty_state.dart';
import 'library_providers.dart';
import 'resume_strip.dart';

/// First of the four destinations (FR-01, FR-18).
///
/// Phase 5: persisted library with search, sort, filter, favorite, rename, delete.
/// The list is a **ruled list**, not cards (DESIGN.md).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  static const String location = '/library';
  static const String navLabel = 'Thư viện';

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Side effect on arrival only: handle shared files
    ref.listen(sharedFilesProvider, (previous, next) {
      final file = switch (next) {
        AsyncData<SharedFile?>(:final value) => value,
        _ => null,
      };
      final previousFile = switch (previous) {
        AsyncData<SharedFile?>(:final value) => value,
        _ => null,
      };
      if (file == null || file == previousFile) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Đã nhận "${file.name}".')));
    });

    final documentsAsync = ref.watch(libraryDocumentsProvider);
    final countAsync = ref.watch(libraryDocumentCountProvider);
    final categoriesAsync = ref.watch(libraryCategoriesProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    // Filter/sort state is watched inside libraryDocumentsProvider and
    // libraryDocumentCountProvider — watching again here would only duplicate
    // the rebuilds without reading the values.

    return Scaffold(
      appBar: _buildAppBar(context, ref, searchQuery),
      body: Column(
        children: [
          const ResumeStrip(),
          if (_showSearch) _buildSearchBar(context, ref),
          if (_showFilters) _buildFilterBar(context, ref, categoriesAsync),
          Expanded(
            child: documentsAsync.when(
              data: (documents) => _buildDocumentList(context, ref, documents, countAsync),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(context, e),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _importDocument,
            tooltip: 'Nhập tài liệu',
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Nhập tệp'),
          ),
          const SizedBox(height: Spacing.s12),
          FloatingActionButton(
            onPressed: () => context.push(RoutePaths.capture),
            tooltip: 'Chụp tài liệu',
            child: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, String searchQuery) {
    final hasActiveFilters = ref.watch(libraryFilterStatusProvider) != null ||
        ref.watch(libraryFilterSourceProvider) != null ||
        ref.watch(libraryFilterFavoriteProvider) != null ||
        (ref.watch(libraryFilterCategoryProvider)?.isNotEmpty ?? false);

    return AppBar(
      title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm tài liệu...',
                border: InputBorder.none,
              ),
              onChanged: (value) => ref.read(librarySearchQueryProvider.notifier).state = value,
              onSubmitted: (_) => _toggleSearch(),
            )
          : Text(
              searchQuery.isNotEmpty
                  ? 'Kết quả: "$searchQuery"'
                  : LibraryScreen.navLabel,
            ),
      leading: _showSearch
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _toggleSearch,
            )
          : null,
      actions: [
        if (!_showSearch) ...[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: hasActiveFilters ? Theme.of(context).colorScheme.primary : null),
            tooltip: _showFilters ? 'Ẩn bộ lọc' : 'Bộ lọc',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          PopupMenuButton<DocumentSortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sắp xếp',
            onSelected: (value) => ref.read(librarySortByProvider.notifier).state = value,
            itemBuilder: (context) => [
              const PopupMenuItem(value: DocumentSortBy.updatedAt, child: Text('Cập nhật gần nhất')),
              const PopupMenuItem(value: DocumentSortBy.createdAt, child: Text('Ngày tạo')),
              const PopupMenuItem(value: DocumentSortBy.name, child: Text('Tên')),
              const PopupMenuItem(value: DocumentSortBy.fileSize, child: Text('Kích thước')),
              const PopupMenuItem(value: DocumentSortBy.lastOpenedAt, child: Text('Mở gần đây')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Thêm',
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importDocument();
                  break;
                case 'history':
                  context.push(RoutePaths.history);
                  break;
                case 'favorites':
                  context.push(RoutePaths.favorites);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_outlined, size: 20),
                    SizedBox(width: Spacing.s8),
                    Text('Nhập tài liệu'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'history', child: Text('Lịch sử đọc')),
              const PopupMenuItem(value: 'favorites', child: Text('Yêu thích')),
            ],
          ),
          IconButton(
            icon: Icon(
              ref.watch(librarySortAscendingProvider) ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            tooltip: ref.watch(librarySortAscendingProvider) ? 'Tăng dần' : 'Giảm dần',
            onPressed: () =>
                ref.read(librarySortAscendingProvider.notifier).state = !ref.read(librarySortAscendingProvider),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Xóa tìm kiếm',
            onPressed: () {
              _searchController.clear();
              ref.read(librarySearchQueryProvider.notifier).state = '';
            },
          ),
        ],
      ],
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        ref.read(librarySearchQueryProvider.notifier).state = '';
      }
    });
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.gutter, 0, Spacing.gutter, Spacing.s12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tài liệu...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(librarySearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => ref.read(librarySearchQueryProvider.notifier).state = value,
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, AsyncValue<List<String>> categoriesAsync) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final filterCategory = ref.watch(libraryFilterCategoryProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.gutter, 0, Spacing.gutter, Spacing.s12),
      child: Wrap(
        spacing: Spacing.s8,
        runSpacing: Spacing.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Bộ lọc:', style: theme.utility.copyWith(color: semantic.textSubtle)),
          FilterChip(
            label: const Text('Yêu thích'),
            selected: ref.watch(libraryFilterFavoriteProvider) == true,
            onSelected: (selected) =>
                ref.read(libraryFilterFavoriteProvider.notifier).state = selected ? true : null,
          ),
          FilterChip(
            label: const Text('Sẵn sàng'),
            selected: ref.watch(libraryFilterStatusProvider) == DocumentStatus.ready,
            onSelected: (selected) =>
                ref.read(libraryFilterStatusProvider.notifier).state = selected ? DocumentStatus.ready : null,
          ),
          FilterChip(
            label: const Text('Đang xử lý'),
            selected: ref.watch(libraryFilterStatusProvider) != null &&
                ref.watch(libraryFilterStatusProvider) != DocumentStatus.ready &&
                ref.watch(libraryFilterStatusProvider) != DocumentStatus.failed,
            onSelected: (selected) =>
                ref.read(libraryFilterStatusProvider.notifier).state = selected ? DocumentStatus.extracting : null,
          ),
          FilterChip(
            label: const Text('Lỗi'),
            selected: ref.watch(libraryFilterStatusProvider) == DocumentStatus.failed,
            onSelected: (selected) =>
                ref.read(libraryFilterStatusProvider.notifier).state = selected ? DocumentStatus.failed : null,
          ),
          categoriesAsync.when(
            data: (categories) => PopupMenuButton<String?>(
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Danh mục',
              onSelected: (value) =>
                  ref.read(libraryFilterCategoryProvider.notifier).state = value?.isEmpty ?? true ? null : value,
              itemBuilder: (context) => [
                const PopupMenuItem<String?>(value: null, child: Text('Tất cả')),
                ...categories.map((c) => PopupMenuItem(value: c, child: Text(c))),
              ],
              child: Chip(
                label: Text(filterCategory ?? 'Danh mục'),
                avatar: filterCategory != null ? const Icon(Icons.category, size: 16) : null,
                onDeleted: filterCategory != null
                    ? () => ref.read(libraryFilterCategoryProvider.notifier).state = null
                    : null,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(libraryFilterStatusProvider.notifier).state = null;
              ref.read(libraryFilterSourceProvider.notifier).state = null;
              ref.read(libraryFilterFavoriteProvider.notifier).state = null;
              ref.read(libraryFilterCategoryProvider.notifier).state = null;
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Xóa bộ lọc'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(
    BuildContext context,
    WidgetRef ref,
    List<Document> documents,
    AsyncValue<int> countAsync,
  ) {
    if (documents.isEmpty) {
      return EmptyState(
        title: 'Thư viện',
        message: ref.watch(librarySearchQueryProvider).isNotEmpty
            ? 'Không tìm thấy tài liệu nào khớp với "${ref.watch(librarySearchQueryProvider)}".'
            : 'Chưa có tài liệu nào. Chụp ảnh trang giấy hoặc nhập PDF, ảnh, tệp văn bản để bắt đầu.',
        primaryAction: FilledButton.icon(
          onPressed: () => context.push(RoutePaths.capture),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp tài liệu'),
        ),
        secondaryAction: OutlinedButton(
          onPressed: _importDocument,
          child: const Text('Nhập tài liệu'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(libraryDocumentsProvider);
        ref.invalidate(libraryDocumentCountProvider);
      },
      child: ListView.separated(
        itemCount: documents.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).semanticColors.border,
        ),
        itemBuilder: (context, index) => _DocumentRow(
          document: documents[index],
          onTap: () => _onDocumentTap(context, ref, documents[index]),
          onLongPress: () => _showDocumentMenu(context, ref, documents[index]),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: Spacing.s16),
          Text('Lỗi tải thư viện', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.s8),
          Text(briefErrorLabel(error), style: Theme.of(context).utility, textAlign: TextAlign.center),
          const SizedBox(height: Spacing.s16),
          FilledButton(
            onPressed: () => ref.invalidate(libraryDocumentsProvider),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _onDocumentTap(BuildContext context, WidgetRef ref, Document document) {
    ref.read(documentRepositoryProvider).markOpened(document.id);
    context.go('${RoutePaths.readAloud}?documentId=${document.id}');
  }

  void _showDocumentMenu(BuildContext context, WidgetRef ref, Document document) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _DocumentMenuSheet(document: document),
    );
  }

  /// Picks a file, then shows progress for the extraction.
  ///
  /// The picker runs **before** the progress dialog on purpose: a dialog that
  /// opens a system file chooser on top of itself makes the chooser look like
  /// the dialog's own error state, and cancelling it would have to be reported
  /// as a failure. Cancelling is simply returning.
  Future<void> _importDocument() async {
    // The OCR engine is the same one the camera uses, so an import and a
    // capture of the same page produce the same blocks.
    final importer = DocumentImporter(
      importService: ref.read(importServiceProvider),
    );
    final PlatformFile? picked = await importer.pick();
    if (picked == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ImportProgressDialog(
        job: (onProgress) => importer.importFile(
          platformFile: picked,
          onProgress: onProgress,
        ),
        onComplete: (result) {
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          // The screen context, not the dialog's — the one above is popped.
          unawaited(_saveImportedDocument(result));
        },
        onError: (failure) {
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
        },
      ),
    );
  }

  /// Persists an extracted document and opens it.
  ///
  /// Reached from [State.context], never from the progress dialog's context —
  /// that one is popped by the time this runs.
  Future<void> _saveImportedDocument(ImportDocumentResult result) async {
    if (!mounted) return;
    final repository = ref.read(documentRepositoryProvider);

    try {
      await repository.createDocument(
        id: result.documentId,
        name: result.name,
        source: result.source,
        mimeType: _mimeTypeFromSource(result.source),
        fileSize: result.fileSize,
        extractedText: result.extractedText,
        // Extraction already finished by the time the row is created, so the
        // document is `ready` — not `queued`, which would show it as
        // "Đang xử lý" forever and refuse to open it.
        status: DocumentStatus.ready,
        blocks: [
          for (final block in result.blocks)
            block.toDocumentBlock(
              id: '${result.documentId}-b${block.order}',
              documentId: result.documentId,
            ),
        ],
        metadata: <String, Object?>{
          if (result.pageCount > 0) 'page_count': result.pageCount,
          if (result.ocrEngineId != null) 'ocr_engine': result.ocrEngineId,
          // Persisted so the library can label the document without reloading
          // every block, and so the warning survives until the user looks at it.
          'ocr_low_confidence_blocks': result.lowConfidenceCount,
        },
      );

      ref
        ..invalidate(libraryDocumentsProvider)
        ..invalidate(libraryDocumentCountProvider)
        ..invalidate(libraryCategoriesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          // An import whose OCR was unsure says so here rather than waiting for
          // the user to notice nonsense text in the reader.
          result.needsReview
              ? SnackBar(
                  content: Text(
                    'Đã nhập "${result.name}", nhưng ${result.lowConfidenceCount} '
                    'dòng nhận dạng không chắc chắn. Nên kiểm tra lại.',
                  ),
                  duration: const Duration(seconds: 6),
                )
              : SnackBar(content: Text('Đã nhập "${result.name}" thành công!')),
        );

      context.go('${RoutePaths.readAloud}?documentId=${result.documentId}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Lỗi khi lưu tài liệu: $error')));
    }
  }

  String _mimeTypeFromSource(DocumentSource source) {
    switch (source) {
      case DocumentSource.pdf:
        return 'application/pdf';
      case DocumentSource.textFile:
        return 'text/plain';
      case DocumentSource.markdown:
        return 'text/markdown';
      case DocumentSource.epub:
        return 'application/epub+zip';
      case DocumentSource.image:
      case DocumentSource.camera:
        return 'image/jpeg';
      case DocumentSource.typedText:
        return 'text/plain';
    }
  }
}

/// Progress dialog shown while a picked file is being extracted.
class _ImportProgressDialog extends ConsumerStatefulWidget {
  const _ImportProgressDialog({
    required this.job,
    required this.onComplete,
    required this.onError,
  });

  /// The extraction to run, given a progress reporter.
  final Future<Result<ImportDocumentResult>> Function(ProgressCallback?) job;

  final ValueChanged<ImportDocumentResult> onComplete;
  final ValueChanged<AppFailure> onError;

  @override
  ConsumerState<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends ConsumerState<_ImportProgressDialog> {
  double _progress = 0;
  String _stage = JobStage.queued;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    final result = await widget.job((progress, stage) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _stage = stage;
      });
    });

    if (!mounted) return;

    switch (result) {
      case Success<ImportDocumentResult>(:final value):
        widget.onComplete(value);
      case Failure<ImportDocumentResult>(:final failure):
        widget.onError(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Đang nhập tài liệu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_stage, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.s16),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: Spacing.s8),
          Text(
            _progress > 0 ? '${(_progress * 100).round()}%' : 'Đang xử lý…',
            style: theme.utility.copyWith(color: theme.semanticColors.textSubtle),
          ),
        ],
      ),
    );
  }
}

/// Document row in the library list.
class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({
    required this.document,
    required this.onTap,
    required this.onLongPress,
  });

  final Document document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final isProcessing = document.isProcessing;
    final hasText = document.hasText;

    return InkWell(
      onTap: hasText && !isProcessing ? onTap : null,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.gutter, vertical: Spacing.s12),
        child: Row(
          children: [
            _DocumentIcon(document: document),
            const SizedBox(width: Spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: hasText && !isProcessing
                                ? theme.colorScheme.onSurface
                                : semantic.textSubtle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (document.isFavorite)
                        Icon(Icons.star, size: 16, color: semantic.warning),
                    ],
                  ),
                  const SizedBox(height: Spacing.s2),
                  Text(
                    _buildSubtitle(document),
                    style: theme.utility.copyWith(color: semantic.textSubtle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _StatusBadge(document: document),
            const SizedBox(width: Spacing.s8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: semantic.textSubtle),
              onSelected: (value) => _handleMenuAction(context, ref, document, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  enabled: !isProcessing,
                  child: const Row(
                    children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Đổi tên')],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(document.isFavorite ? Icons.star : Icons.star_border, size: 20),
                      const SizedBox(width: 8),
                      Text(document.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'category',
                  enabled: !isProcessing,
                  child: const Row(
                    children: [Icon(Icons.category_outlined, size: 20), SizedBox(width: 8), Text('Danh mục')],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !isProcessing,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: semantic.danger),
                      const SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: semantic.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, Document document, String action) {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, ref, document);
        break;
      case 'favorite':
        ref.read(documentRepositoryProvider).toggleFavorite(document.id, !document.isFavorite);
        break;
      case 'category':
        _showCategoryDialog(context, ref, document);
        break;
      case 'delete':
        _confirmDelete(context, ref, document);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Document document) {
    final controller = TextEditingController(text: document.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên tài liệu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên mới'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != document.name) {
                ref.read(documentRepositoryProvider).renameDocument(document.id, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, Document document) {
    final controller = TextEditingController(text: document.category ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt danh mục'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Danh mục (để trống để xóa)'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final category = controller.text.trim();
              ref.read(documentRepositoryProvider).setCategory(document.id, category.isEmpty ? null : category);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Document document) async {
    final size = await ref.read(documentRepositoryProvider).getDocumentSize(document.id);
    final sizeStr = _formatBytes(size);

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: Text('Xóa "${document.name}" ($sizeStr)? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).semanticColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(documentRepositoryProvider).deleteDocument(document.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "${document.name}"')),
        );
      }
    }
  }

  String _buildSubtitle(Document document) {
    final parts = <String>[];
    if (document.source != DocumentSource.typedText) {
      parts.add(_sourceLabel(document.source));
    }
    if (document.fileSize > 0) {
      parts.add(_formatBytes(document.fileSize));
    }
    if (document.extractedText != null && document.extractedText!.isNotEmpty) {
      parts.add('Có văn bản');
    }
    if (document.failureMessage != null) {
      parts.add('Lỗi: ${document.failureMessage}');
    }
    return parts.join(' · ');
  }

  String _sourceLabel(DocumentSource source) {
    switch (source) {
      case DocumentSource.camera:
        return 'Camera';
      case DocumentSource.image:
        return 'Ảnh';
      case DocumentSource.pdf:
        return 'PDF';
      case DocumentSource.textFile:
        return 'Văn bản';
      case DocumentSource.markdown:
        return 'Markdown';
      case DocumentSource.epub:
        return 'EPUB';
      case DocumentSource.typedText:
        return 'Gõ tay';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Document icon based on source.
class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    IconData icon;
    switch (document.source) {
      case DocumentSource.camera:
        icon = Icons.photo_camera_outlined;
        break;
      case DocumentSource.image:
        icon = Icons.image_outlined;
        break;
      case DocumentSource.pdf:
        icon = Icons.picture_as_pdf_outlined;
        break;
      case DocumentSource.textFile:
      case DocumentSource.markdown:
        icon = Icons.description_outlined;
        break;
      case DocumentSource.epub:
        icon = Icons.menu_book_outlined;
        break;
      case DocumentSource.typedText:
        icon = Icons.edit_note_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: semantic.accentWash,
        borderRadius: BorderRadius.circular(RadiusTokens.sm),
      ),
      child: Icon(icon, color: semantic.accentInk, size: 22),
    );
  }
}

/// Status badge with word + shape.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    String label;
    Color color;
    bool isCircle;

    switch (document.status) {
      case DocumentStatus.queued:
      case DocumentStatus.extracting:
      case DocumentStatus.ocr:
        label = 'Đang xử lý';
        color = semantic.warning;
        isCircle = false;
        break;
      case DocumentStatus.ready:
        label = 'Sẵn sàng';
        color = semantic.success;
        isCircle = true;
        break;
      case DocumentStatus.failed:
        label = 'Lỗi';
        color = semantic.danger;
        isCircle = false;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: Spacing.s8),
        Text(label, style: theme.utility.copyWith(color: color)),
        if (document.needsOcrReview) ...<Widget>[
          // The document is finished, not wrong. A separate marker is what stops
          // the two from being confused: the row still opens, and the number is
          // how many lines a person still has to look at.
          const SizedBox(width: Spacing.s8),
          Icon(Icons.warning_amber_rounded,
              size: 14, color: semantic.warning),
          const SizedBox(width: 4),
          Text(
            '${document.lowConfidenceCount} dòng cần kiểm tra',
            style: theme.utility.copyWith(color: semantic.warning),
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet menu for document actions.
class _DocumentMenuSheet extends ConsumerWidget {
  const _DocumentMenuSheet({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final isProcessing = document.isProcessing;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: semantic.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: isProcessing ? semantic.textSubtle : null),
            title: Text('Đổi tên', style: TextStyle(color: isProcessing ? semantic.textSubtle : null)),
            enabled: !isProcessing,
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref);
            },
          ),
          ListTile(
            leading: Icon(document.isFavorite ? Icons.star : Icons.star_border),
            title: Text(document.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích'),
            onTap: () {
              Navigator.pop(context);
              ref.read(documentRepositoryProvider).toggleFavorite(document.id, !document.isFavorite);
            },
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Danh mục'),
            enabled: !isProcessing,
            onTap: () {
              Navigator.pop(context);
              _showCategoryDialog(context, ref);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: semantic.danger),
            title: Text('Xóa', style: TextStyle(color: semantic.danger)),
            enabled: !isProcessing,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, ref);
            },
          ),
          const SizedBox(height: Spacing.s16),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: document.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên tài liệu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên mới'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != document.name) {
                ref.read(documentRepositoryProvider).renameDocument(document.id, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: document.category ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt danh mục'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Danh mục (để trống để xóa)'),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final category = controller.text.trim();
              ref.read(documentRepositoryProvider).setCategory(document.id, category.isEmpty ? null : category);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final semantic = Theme.of(context).semanticColors;
    final size = await ref.read(documentRepositoryProvider).getDocumentSize(document.id);
    final sizeStr = _formatBytes(size);

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: Text('Xóa "${document.name}" ($sizeStr)? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: semantic.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(documentRepositoryProvider).deleteDocument(document.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "${document.name}"')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}