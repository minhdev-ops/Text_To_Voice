import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show RoutePaths;
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import 'capture_providers.dart';
import 'ocr_review_pane.dart';

/// Review and correct what OCR read (UX spec §4 → OCR Review).
///
/// The screen owns the review state — which line is selected, whether the user is
/// editing, which image they are looking at — and the pane below it is purely
/// presentational. That split is what makes the pane testable with an exact state
/// instead of approximated taps.
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({super.key});

  static const String location = '/capture/review';
  static const String title = 'Kiểm tra chữ nhận dạng';

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  ReviewSelection? _selection;
  bool _editing = false;
  bool _showOriginal = false;
  double _imageFraction = 0.42;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    final page = state.page;
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    if (page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(ScanReviewScreen.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.s24),
            child: Text(
              'Không còn trang nào để kiểm tra.',
              style: theme.utility.copyWith(color: semantic.textSubtle),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.pages.length > 1
              ? '${ScanReviewScreen.title} · Trang ${page.index + 1}/'
                  '${state.pages.length}'
              : ScanReviewScreen.title,
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: state.isWorking
                ? null
                : () => controller.rescanCurrentPage(),
            icon: const Icon(Icons.refresh),
            label: const Text('Quét lại'),
          ),
          const SizedBox(width: Spacing.s8),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (page.lowConfidenceCount > 0) _LowConfidenceBanner(count: page.lowConfidenceCount),
          if (page.failureMessage != null)
            _FailureBanner(
              message: page.failureMessage!,
              onDismiss: controller.clearFailure,
            ),
          if (state.lastScanNote != null)
            _ScanNote(note: state.lastScanNote!),
          if (state.isWorking)
            LinearProgressIndicator(
              value: state.progress == 0 ? null : state.progress,
              minHeight: 2,
            ),
          Expanded(
            child: OcrReviewPane(
              page: page,
              selectedLine: _editing ? null : _selection,
              editing: _editing,
              showOriginal: _showOriginal,
              imageFraction: _imageFraction,
              onLineSelected: (selection) =>
                  setState(() => _selection = selection),
              onImageFractionChanged: (fraction) =>
                  setState(() => _imageFraction = fraction),
              onTextChanged: controller.updateText,
            ),
          ),
          _ActionBar(
            showOriginal: _showOriginal,
            editing: _editing,
            canCopy: (page.text ?? '').trim().isNotEmpty,
            working: state.isWorking,
            onToggleImage: () =>
                setState(() => _showOriginal = !_showOriginal),
            onToggleEditing: () => setState(() => _editing = !_editing),
            onCopy: () => _copy(page.text ?? ''),
            onKeep: () => _keep(context, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Đã sao chép văn bản.')));
  }

  void _keep(BuildContext context, CaptureController controller) {
    // Leaving edit mode first, so the text the user is looking at is the text
    // that gets stored even if the field has not committed yet.
    setState(() => _editing = false);
    controller.keep();
    context.go(RoutePaths.library);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Đã lưu tài liệu. Mở Thư viện để đọc thành tiếng.'),
      ));
  }
}

/// `N dòng cần kiểm tra` — the honest count the UX spec asks for, with the
/// `warning` tone and no alarm.
class _LowConfidenceBanner extends StatelessWidget {
  const _LowConfidenceBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: semantic.warning)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.s16,
        vertical: Spacing.s8,
      ),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 20, color: semantic.warning),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Text(
              '$count dòng cần kiểm tra',
              style: theme.utility.copyWith(color: semantic.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: semantic.danger)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.s16,
        vertical: Spacing.s8,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: theme.utility.copyWith(color: semantic.danger),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Đóng')),
        ],
      ),
    );
  }
}

/// What the enhancement pass actually did. Folded away by default: it is a
/// receipt, not a headline, but it must be available — a user whose deskew did
/// nothing deserves to know why rather than wonder if the toggle works.
class _ScanNote extends StatelessWidget {
  const _ScanNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(
        'Xử lý ảnh',
        style: theme.utility.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
      childrenPadding: const EdgeInsets.fromLTRB(
        Spacing.s16,
        0,
        Spacing.s16,
        Spacing.s12,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          note,
          style: theme.utility.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.showOriginal,
    required this.editing,
    required this.canCopy,
    required this.working,
    required this.onToggleImage,
    required this.onToggleEditing,
    required this.onCopy,
    required this.onKeep,
  });

  final bool showOriginal;
  final bool editing;
  final bool canCopy;
  final bool working;
  final VoidCallback onToggleImage;
  final VoidCallback onToggleEditing;
  final VoidCallback onCopy;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.s16,
        vertical: Spacing.s12,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: onToggleImage,
              isSelected: showOriginal,
              tooltip: showOriginal ? 'Xem bản đã xử lý' : 'Xem ảnh gốc',
              icon: const Icon(Icons.compare_outlined),
            ),
            IconButton(
              onPressed: onToggleEditing,
              isSelected: editing,
              tooltip: editing ? 'Xong chỉnh sửa' : 'Sửa văn bản',
              icon: Icon(editing ? Icons.check : Icons.edit_outlined),
            ),
            IconButton(
              onPressed: canCopy ? onCopy : null,
              tooltip: 'Sao chép văn bản',
              icon: const Icon(Icons.copy_all_outlined),
            ),
            const Spacer(),
            FilledButton(
              onPressed: working ? null : onKeep,
              child: const Text('Giữ văn bản'),
            ),
          ],
        ),
      ),
    );
  }
}
