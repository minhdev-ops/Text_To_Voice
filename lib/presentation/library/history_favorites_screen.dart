import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show RoutePaths;
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/models/document.dart' show DocumentSource, DocumentStatus, DocumentSortBy, Document;
import '../common/brief_error_label.dart';
import '../common/empty_state.dart';

/// Reading history screen — shows documents ordered by last opened.
class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  static const String location = '/history';
  static const String navLabel = 'Lịch sử đọc';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(navLabel)),
      body: FutureBuilder<List<Document>>(
        future: repo.getDocuments(
          sortBy: DocumentSortBy.lastOpenedAt,
          ascending: false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(context, snapshot.error!);
          }
          final documents = snapshot.data ?? [];
          final historyDocs = documents.where((d) => d.lastOpenedAt != null).toList();

          if (historyDocs.isEmpty) {
            return EmptyState(
              title: 'Lịch sử đọc',
              message: 'Chưa có lịch sử đọc nào. Mở một tài liệu để bắt đầu.',
              primaryAction: FilledButton.icon(
                onPressed: () => context.go(RoutePaths.library),
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Đến Thư viện'),
              ),
            );
          }

          return ListView.separated(
            itemCount: historyDocs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).semanticColors.border,
            ),
            itemBuilder: (context, index) => _HistoryRow(document: historyDocs[index]),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Lỗi tải lịch sử', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(briefErrorLabel(error), style: Theme.of(context).utility, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Row for history screen.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return ListTile(
      leading: _DocumentIcon(document: document),
      title: Text(document.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        _subtitle(document),
        style: theme.utility.copyWith(color: semantic.textSubtle),
      ),
      trailing: Text(
        _formatDateTime(document.lastOpenedAt!),
        style: theme.utility.copyWith(color: semantic.textSubtle),
      ),
      onTap: () {
        // Navigate to read aloud with this document
        // The router will handle the documentId parameter
      },
    );
  }

  String _subtitle(Document document) {
    final parts = <String>[];
    if (document.source != DocumentSource.typedText) {
      parts.add(_sourceLabel(document.source));
    }
    if (document.extractedText != null && document.extractedText!.isNotEmpty) {
      parts.add('Có văn bản');
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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: semantic.accentInk, size: 22),
    );
  }
}

/// Favorites screen — shows only favorite documents.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static const String location = '/favorites';
  static const String navLabel = 'Yêu thích';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(navLabel)),
      body: FutureBuilder<List<Document>>(
        future: repo.getDocuments(
          isFavorite: true,
          sortBy: DocumentSortBy.updatedAt,
          ascending: false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(context, snapshot.error!);
          }
          final documents = snapshot.data ?? [];

          if (documents.isEmpty) {
            return EmptyState(
              title: 'Yêu thích',
              message: 'Chưa có tài liệu yêu thích nào. Giữ tap vào tài liệu để thêm vào yêu thích.',
              primaryAction: FilledButton.icon(
                onPressed: () => context.go(RoutePaths.library),
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Đến Thư viện'),
              ),
            );
          }

          return ListView.separated(
            itemCount: documents.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).semanticColors.border,
            ),
            itemBuilder: (context, index) => _FavoriteRow(document: documents[index]),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Lỗi tải yêu thích', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(briefErrorLabel(error), style: Theme.of(context).utility, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Row for favorites screen.
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return ListTile(
      leading: _DocumentIcon(document: document),
      title: Text(document.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        _subtitle(document),
        style: theme.utility.copyWith(color: semantic.textSubtle),
      ),
      trailing: Icon(Icons.star, size: 20, color: semantic.warning),
      onTap: () {
        // Navigate to read aloud
      },
    );
  }

  String _subtitle(Document document) {
    final parts = <String>[];
    if (document.source != DocumentSource.typedText) {
      parts.add(_sourceLabel(document.source));
    }
    if (document.extractedText != null && document.extractedText!.isNotEmpty) {
      parts.add('Có văn bản');
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
}