import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/models/model_install_service.dart';
import '../../ai/models/vieneu_model_manifest.dart';
import '../../core/theme/tokens.dart';
import 'model_providers.dart';

/// Third destination: the model inventory (SRS FR-20).
///
/// Six states, one ruled row, and one rule that is not negotiable: the license
/// line is always visible on the row (§47 — different VieNeu checkpoints carry
/// different terms, so the app states which one it is about to install rather
/// than implying "VieNeu" is one license).
class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  static const String location = '/models';
  static const String navLabel = 'Mô hình';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelInstallControllerProvider);
    final controller = ref.read(modelInstallControllerProvider.notifier);
    final palette = AppPalette.of(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(title: const Text(navLabel)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.s32),
        children: <Widget>[
          _InstrumentStrip(state: state, palette: palette),
          const Divider(height: 1),
          _ModelRow(
            state: state,
            palette: palette,
            onInstall: controller.install,
            onCancel: controller.cancel,
            onVerify: controller.verify,
            onDelete: () => _confirmDelete(context, ref, state),
          ),
          if (state.failure != null) _FailureNote(state: state, palette: palette),
          if (!VieNeuModelManifest.shipsPhonemizerLibrary('android'))
            _PhonemizerNote(palette: palette),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ModelInstallState state,
  ) async {
    final size = VieNeuModelManifest.formatBytes(state.installedBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa model?'),
        content: Text(
          'Giải phóng $size. Cần mạng để tải lại và giọng đọc sẽ tạm dừng hoạt động.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(modelInstallControllerProvider.notifier).delete();
    }
  }
}

/// Installed · Available · on-disk size. The strip is the summary; the row below
/// is the detail, and the two must agree because both read one state value.
class _InstrumentStrip extends StatelessWidget {
  const _InstrumentStrip({required this.state, required this.palette});

  final ModelInstallState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final installed = state.stage == ModelInstallStage.installed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.gutter,
        Spacing.s16,
        Spacing.gutter,
        Spacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _Figure(
            label: 'Đã tải',
            value: installed ? VieNeuModelManifest.formatBytes(state.installedBytes) : '—',
            palette: palette,
          ),
          const SizedBox(width: Spacing.s24),
          _Figure(
            label: 'Cần tải',
            value: installed
                ? '0 MB'
                : VieNeuModelManifest.formatBytes(state.totalBytes),
            palette: palette,
          ),
          const Spacer(),
          if (state.stage == ModelInstallStage.downloading)
            Text(
              '${(state.progress * 100).round()}%',
              style: TextStyle(
                fontFamily: FontFamilies.body,
                fontSize: TypeScale.bodyLarge,
                fontWeight: FontWeight.w600,
                color: palette.accentInk,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.palette});

  final String label;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamily: FontFamilies.body,
            fontSize: TypeScale.caption,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          value,
          style: TextStyle(
            fontFamily: FontFamilies.display,
            fontSize: TypeScale.title,
            color: palette.text,
          ),
        ),
      ],
    );
  }
}

/// One ruled model row: name, size, sample rate, status word, action — and the
/// license, always.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.state,
    required this.palette,
    required this.onInstall,
    required this.onCancel,
    required this.onVerify,
    required this.onDelete,
  });

  final ModelInstallState state;
  final AppPalette palette;
  final Future<void> Function() onInstall;
  final void Function() onCancel;
  final Future<void> Function() onVerify;
  final void Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final platformLabel = switch (state.stage) {
      ModelInstallStage.notInstalled => 'Chưa cài',
      ModelInstallStage.downloading => 'Đang tải',
      ModelInstallStage.verifying => 'Đang kiểm tra…',
      ModelInstallStage.installed => 'Đã cài',
      ModelInstallStage.corrupt => 'Model hỏng',
      ModelInstallStage.error => 'Lỗi mạng',
    };
    final statusColor = switch (state.stage) {
      ModelInstallStage.installed => palette.success,
      ModelInstallStage.corrupt || ModelInstallStage.error => palette.danger,
      _ => palette.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.gutter,
        Spacing.s16,
        Spacing.gutter,
        Spacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      VieNeuModelManifest.checkpointName,
                      style: TextStyle(
                        fontFamily: FontFamilies.display,
                        fontSize: TypeScale.reading,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: Spacing.s4),
                    Text(
                      '${VieNeuModelManifest.quantization} · '
                      '${VieNeuModelManifest.sampleRate ~/ 1000} kHz · '
                      '${VieNeuModelManifest.formatBytes(state.totalBytes)}',
                      style: TextStyle(
                        fontFamily: FontFamilies.body,
                        fontSize: TypeScale.label,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s12),
              Text(
                platformLabel,
                style: TextStyle(
                  fontFamily: FontFamilies.body,
                  fontSize: TypeScale.label,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (state.stage == ModelInstallStage.downloading) ...<Widget>[
            const SizedBox(height: Spacing.s12),
            ClipRRect(
              borderRadius: RadiusTokens.smBorder,
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 4,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
              ),
            ),
            const SizedBox(height: Spacing.s4),
            Text(
              '${VieNeuModelManifest.formatBytes(state.receivedBytes)} / '
              '${VieNeuModelManifest.formatBytes(state.totalBytes)}'
              '${state.currentFile == null ? '' : ' · ${state.currentFile}'}',
              style: TextStyle(
                fontFamily: FontFamilies.body,
                fontSize: TypeScale.caption,
                color: palette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: Spacing.s12),
          // The license line is part of the row, not a detail sheet: §47 asks
          // for the exact string to be visible wherever a checkpoint is offered.
          Text(
            '${VieNeuModelManifest.license} · ${VieNeuModelManifest.licenseSource}',
            style: TextStyle(
              fontFamily: FontFamilies.body,
              fontSize: TypeScale.caption,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: Spacing.s16),
          _Actions(
            state: state,
            onInstall: onInstall,
            onCancel: onCancel,
            onVerify: onVerify,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.onInstall,
    required this.onCancel,
    required this.onVerify,
    required this.onDelete,
  });

  final ModelInstallState state;
  final Future<void> Function() onInstall;
  final void Function() onCancel;
  final Future<void> Function() onVerify;
  final void Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    switch (state.stage) {
      case ModelInstallStage.notInstalled:
        children.add(_primary('Tải về', onInstall));
      case ModelInstallStage.downloading:
        children.add(_secondary('Hủy', onCancel));
      case ModelInstallStage.verifying:
        children.add(const SizedBox.shrink());
      case ModelInstallStage.installed:
        children.add(_secondary('Kiểm tra', onVerify));
        children.add(const SizedBox(width: Spacing.s8));
        children.add(_secondary('Xóa', onDelete));
      case ModelInstallStage.corrupt:
        children.add(_primary('Tải lại', onInstall));
      case ModelInstallStage.error:
        children.add(_primary('Thử lại', onInstall));
    }

    return Row(children: children);
  }

  Widget _primary(String label, Future<void> Function() action) => SizedBox(
        height: Layout.minTouchTarget,
        child: FilledButton(onPressed: () => action(), child: Text(label)),
      );

  Widget _secondary(String label, void Function() action) => SizedBox(
        height: Layout.minTouchTarget,
        child: OutlinedButton(onPressed: action, child: Text(label)),
      );
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.state, required this.palette});

  final ModelInstallState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.gutter),
      padding: const EdgeInsets.all(Spacing.s12),
      decoration: BoxDecoration(
        border: Border.all(color: palette.danger, width: 1),
        borderRadius: RadiusTokens.mdBorder,
      ),
      child: Text(
        state.failure!.message,
        style: TextStyle(
          fontFamily: FontFamilies.body,
          fontSize: TypeScale.body,
          color: palette.danger,
        ),
      ),
    );
  }
}

/// The one limitation a user can hit on Android, stated where they will hit it.
///
/// Upstream sea-g2p publishes no Android library, so the dictionary can be
/// downloaded but the phonemizer still needs a build step. Saying so is the
/// difference between a missing feature and a mystery.
class _PhonemizerNote extends StatelessWidget {
  const _PhonemizerNote({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.gutter,
        Spacing.s24,
        Spacing.gutter,
        Spacing.s8,
      ),
      child: Text(
        'Trên Android, thư viện chuyển ngữ âm tiếng Việt (sea-g2p) chưa có bản '
        'dựng sẵn từ nhà phát hành. Cần dựng bằng tool/build_g2p.sh rồi đặt vào '
        'android/app/src/main/jniLibs/ để đọc được văn bản trên thiết bị.',
        style: TextStyle(
          fontFamily: FontFamilies.body,
          fontSize: TypeScale.caption,
          color: palette.textMuted,
        ),
      ),
    );
  }
}
