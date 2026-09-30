import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart' show StateProvider;

import '../../data/providers.dart';
import '../../domain/import/import_service.dart';
import '../../domain/models/document.dart' show Document, DocumentStatus, DocumentSource, DocumentSortBy;
import '../../domain/ocr/ocr_structurer.dart';
import '../capture/capture_providers.dart'
    show documentScannerProvider, ocrEngineProvider;

/// The import pipeline: validate → extract → structure, with OCR wired in.
///
/// The OCR **engine** and the **scanner** are shared with the camera flow, so an
/// import and a capture of the same page go through one pipeline: the same
/// recognizer, the same page preparation, the same structurer. The **structurer**
/// is not shared — it remembers running headers across pages, and that memory
/// belongs to exactly one document. A new instance per import is what stops a
/// previous document's headers from being "detected" in this one.
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    ocr: ref.watch(ocrEngineProvider),
    structurer: OcrStructurer(),
    scanner: ref.watch(documentScannerProvider),
  );
});

/// Current search query for the library.
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Current filter status for the library.
final libraryFilterStatusProvider = StateProvider<DocumentStatus?>((ref) => null);

/// Current filter source for the library.
final libraryFilterSourceProvider = StateProvider<DocumentSource?>((ref) => null);

/// Current favorite filter for the library.
final libraryFilterFavoriteProvider = StateProvider<bool?>((ref) => null);

/// Current category filter for the library.
final libraryFilterCategoryProvider = StateProvider<String?>((ref) => null);

/// Current sort option for the library.
final librarySortByProvider = StateProvider<DocumentSortBy>((ref) => DocumentSortBy.updatedAt);

/// Current sort order for the library.
final librarySortAscendingProvider = StateProvider<bool>((ref) => false);

/// Current page for pagination.
final libraryPageProvider = StateProvider<int>((ref) => 0);

/// Documents per page.
const int libraryPageSize = 50;

/// Filtered and sorted documents stream.
final libraryDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final query = ref.watch(librarySearchQueryProvider);
  final status = ref.watch(libraryFilterStatusProvider);
  final source = ref.watch(libraryFilterSourceProvider);
  final isFavorite = ref.watch(libraryFilterFavoriteProvider);
  final category = ref.watch(libraryFilterCategoryProvider);
  final sortBy = ref.watch(librarySortByProvider);
  final ascending = ref.watch(librarySortAscendingProvider);

  final repo = ref.watch(documentRepositoryProvider);
  return repo.watchDocuments(
    query: query.isEmpty ? null : query,
    status: status,
    source: source,
    isFavorite: isFavorite,
    category: category?.isEmpty ?? true ? null : category,
    sortBy: sortBy,
    ascending: ascending,
  );
});

/// Document count for the current filter.
final libraryDocumentCountProvider = FutureProvider<int>((ref) async {
  final query = ref.watch(librarySearchQueryProvider);
  final status = ref.watch(libraryFilterStatusProvider);
  final source = ref.watch(libraryFilterSourceProvider);
  final isFavorite = ref.watch(libraryFilterFavoriteProvider);
  final category = ref.watch(libraryFilterCategoryProvider);

  final repo = ref.watch(documentRepositoryProvider);
  // For count we don't need sorting
  final docs = await repo.getDocuments(
    query: query.isEmpty ? null : query,
    status: status,
    source: source,
    isFavorite: isFavorite,
    category: category?.isEmpty ?? true ? null : category,
  );
  return docs.length;
});

/// Storage usage.
final storageUsageProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getStorageUsage();
});

/// Categories used by documents.
final libraryCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  final docs = await repo.getDocuments();
  final categories = <String>{};
  for (final doc in docs) {
    if (doc.category != null && doc.category!.isNotEmpty) {
      categories.add(doc.category!);
    }
  }
  return categories.toList()..sort();
});