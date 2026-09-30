import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show RoutePaths;
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/models/tts.dart' show TtsOptions, SpeechFormat, VoicePreset;
import '../library/library_providers.dart';
import 'theme_mode_provider.dart';

/// Fourth destination: defaults, storage, about and the privacy statement.
///
/// Phase 5 adds default voice/speed, low-memory mode, storage usage, privacy.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String location = '/settings';
  static const String navLabel = 'Cài đặt';

  static const List<(ThemeMode, String)> _themeOptions =
      <(ThemeMode, String)>[
    (ThemeMode.system, 'Theo hệ thống'),
    (ThemeMode.light, 'Sáng'),
    (ThemeMode.dark, 'Tối'),
  ];

  static const List<(double, String)> speedOptions =
      <(double, String)>[
    (0.5, '0.5x'),
    (0.75, '0.75x'),
    (1.0, '1.0x'),
    (1.25, '1.25x'),
    (1.5, '1.5x'),
    (2.0, '2.0x'),
  ];

  static const List<(SpeechFormat, String)> formatOptions =
      <(SpeechFormat, String)>[
    (SpeechFormat.wav, 'WAV (chất lượng cao, không nén)'),
    (SpeechFormat.mp3, 'MP3 (cần bộ mã hóa trên máy)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;
    final semantic = Theme.of(context).semanticColors;
    final repo = ref.watch(documentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(navLabel)),
      body: ListView(
        children: [
          // Theme
          _buildSectionHeader(context, 'Giao diện'),
          for (final (mode, label) in _themeOptions)
            ListTile(
              title: Text(label),
              trailing: mode == themeMode
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => ref.read(themeModeProvider.notifier).select(mode),
            ),

          const Divider(),

          // Default TTS settings
          _buildSectionHeader(context, 'Đọc thành tiếng mặc định'),
          _DefaultVoiceTile(),
          _DefaultSpeedTile(),
          _DefaultVolumeTile(),
          _DefaultFormatTile(),

          const Divider(),

          // Low-memory mode
          _buildSectionHeader(context, 'Hiệu năng'),
          _LowMemoryModeTile(),

          const Divider(),

          // Storage
          _StorageUsageTile(),

          const Divider(),

          // Data management
          _buildSectionHeader(context, 'Dữ liệu'),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: semantic.danger),
            title: const Text('Dọn dẹp file rác'),
            subtitle: const Text('Xóa file tạm, audio cache cũ, tác vụ đã hoàn thành'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCleanupDialog(context, ref),
          ),

          const Divider(),

          // Privacy
          _buildSectionHeader(context, 'Quyền riêng tư'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Cam kết quyền riêng tư'),
            subtitle: const Text('Xem cam kết chi tiết về cách ứng dụng xử lý dữ liệu của bạn'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacyDialog(context),
          ),

          const Divider(),

          // About
          _buildSectionHeader(context, 'Về ứng dụng'),
          const ListTile(
            title: Text('VietDoc AI'),
            subtitle: Text(
              'Đọc tài liệu và đọc thành tiếng, chạy hoàn toàn '
              'trên máy. Tài liệu không được gửi lên máy chủ.',
            ),
          ),
          ListTile(
            title: const Text('Phiên bản'),
            subtitle: const Text('1.0.0 (Phase 5)'),
          ),
          ListTile(
            title: const Text('Giấy phép mã nguồn mở'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicensesDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  void _showCleanupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dọn dẹp bộ nhớ'),
        content: const Text(
          'Thao tác này sẽ xóa:\n'
          '• File tạm trong thư mục temp\n'
          '• Audio cache cũ hơn 30 ngày\n'
          '• Các tác vụ xử lý đã hoàn thành quá 7 ngày\n\n'
          'Tài liệu và cài đặt của bạn sẽ không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final storage = appStorage;
              final repo = ref.read(documentRepositoryProvider);

              // Show progress
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang dọn dẹp...')),
              );

              final freedTemp = await storage.cleanTemp();
              final freedJobs = await repo.cleanupOldJobs(maxAgeDays: 7);
              final freedAudio = await repo.cleanupAudioCache(maxAgeDays: 30);
              final freedOrphans = await repo.cleanupOrphanFiles();

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã dọn dẹp: ${_formatBytes(freedTemp + freedOrphans.freedBytes)} '
                    '(temp: ${_formatBytes(freedTemp)}, '
                    'audio cache: $freedAudio entries, '
                    'jobs: $freedJobs, '
                    'orphan files: ${freedOrphans.deletedImages})',
                  ),
                ),
              );
            },
            child: const Text('Dọn dẹp'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cam kết quyền riêng tư'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'VietDoc AI cam kết bảo vệ quyền riêng tư của bạn:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _privacyBullet('Tất cả tài liệu, hình ảnh, âm thanh và mô hình AI được lưu trữ **chỉ trong bộ nhớ riêng của ứng dụng** trên thiết bị của bạn.'),
              _privacyBullet('Không có dữ liệu nào được gửi đến máy chủ, đám mây hoặc bên thứ ba nào.'),
              _privacyBullet('Kết nối mạng **chỉ** được sử dụng để tải xuống mô hình TTS (khi bạn chọn cài đặt) — và chỉ khi bạn đồng ý.'),
              _privacyBullet('OCR sử dụng Google ML Kit, có thể gửi dữ liệu đo lường ẩn danh (kích thước ảnh, độ trễ, phiên bản) đến Google. Nội dung ảnh và văn bản **không** được gửi.'),
              _privacyBullet('Bạn có toàn quyền xóa mọi dữ liệu bất kỳ lúc nào qua tính năng "Dọn dẹp" hoặc xóa tài liệu.'),
              _privacyBullet('Không theo dõi, không quảng cáo, không phân tích hành vi người dùng.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _privacyBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showLicensePage(context: context, applicationName: 'VietDoc AI');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Default voice selector tile.
class _DefaultVoiceTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<VoicePreset?>(
      future: repo.getActiveModel(),
      builder: (context, snapshot) {
        final activeModel = snapshot.data;
        return ListTile(
          title: const Text('Giọng đọc mặc định'),
          subtitle: Text(activeModel?.label ?? 'Chưa chọn (sẽ dùng giọng đầu tiên có sẵn)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(RoutePaths.models),
        );
      },
    );
  }
}

/// Default speed selector tile.
class _DefaultSpeedTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<String?>(
      future: repo.getSetting('default_speed'),
      builder: (context, snapshot) {
        final speed = double.tryParse(snapshot.data ?? '1.0') ?? 1.0;
        return ListTile(
          title: const Text('Tốc độ mặc định'),
          subtitle: Text('${speed}x'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showSpeedPicker(context, ref, speed),
        );
      },
    );
  }

  void _showSpeedPicker(BuildContext context, WidgetRef ref, double current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn tốc độ mặc định')),
            ...SettingsScreen.speedOptions.map((opt) => RadioListTile<double>(
                  value: opt.$1,
                  groupValue: current,
                  title: Text(opt.$2),
                  onChanged: (value) async {
                    if (value != null) {
                      await ref.read(documentRepositoryProvider).setSetting('default_speed', value.toString());
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}

/// Default volume selector tile.
class _DefaultVolumeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<String?>(
      future: repo.getSetting('default_volume'),
      builder: (context, snapshot) {
        final volume = double.tryParse(snapshot.data ?? '1.0') ?? 1.0;
        return ListTile(
          title: const Text('Âm lượng mặc định'),
          subtitle: Text('${(volume * 100).round()}%'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showVolumePicker(context, ref, volume),
        );
      },
    );
  }

  void _showVolumePicker(BuildContext context, WidgetRef ref, double current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn âm lượng mặc định')),
            for (int i = 0; i <= 10; i++)
              RadioListTile<double>(
                value: i / 10,
                groupValue: current,
                title: Text('${i * 10}%'),
                onChanged: (value) async {
                  if (value != null) {
                    await ref.read(documentRepositoryProvider).setSetting('default_volume', value.toString());
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Default format selector tile.
class _DefaultFormatTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<String?>(
      future: repo.getSetting('default_format'),
      builder: (context, snapshot) {
        final format = SpeechFormat.values.byName(snapshot.data ?? 'wav');
        return ListTile(
          title: const Text('Định dạng âm thanh'),
          subtitle: Text(format == SpeechFormat.wav ? 'WAV (chất lượng cao)' : 'MP3 (nén)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showFormatPicker(context, ref, format),
        );
      },
    );
  }

  void _showFormatPicker(BuildContext context, WidgetRef ref, SpeechFormat current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn định dạng âm thanh')),
            ...SettingsScreen.formatOptions.map((opt) => RadioListTile<SpeechFormat>(
                  value: opt.$1,
                  groupValue: current,
                  title: Text(opt.$2),
                  onChanged: (value) async {
                    if (value != null) {
                      await ref.read(documentRepositoryProvider).setSetting('default_format', value.name);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}

/// Low-memory mode toggle tile.
class _LowMemoryModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<String?>(
      future: repo.getSetting('low_memory_mode'),
      builder: (context, snapshot) {
        final enabled = snapshot.data == 'true';
        return SwitchListTile(
          title: const Text('Chế độ tiết kiệm bộ nhớ'),
          subtitle: const Text(
            'Giảm bộ nhớ đệm, xử lý từng trang, không giữ toàn bộ tài liệu trong RAM. '
            'Phù hợp cho thiết bị cấu hình thấp.',
          ),
          value: enabled,
          onChanged: (value) async {
            await ref.read(documentRepositoryProvider).setSetting('low_memory_mode', value.toString());
          },
        );
      },
    );
  }
}

/// Storage usage tile.
class _StorageUsageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageUsageAsync = ref.watch(storageUsageProvider);

    return storageUsageAsync.when(
      data: (bytes) => ListTile(
        leading: const Icon(Icons.storage_outlined),
        title: const Text('Dung lượng đã dùng'),
        subtitle: Text(_formatBytes(bytes)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showStorageBreakdown(context, ref),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.storage_outlined),
        title: Text('Dung lượng đã dùng'),
        subtitle: Text('Đang tính...'),
      ),
      error: (_, __) => ListTile(
        leading: Icon(Icons.storage_outlined, color: Theme.of(context).colorScheme.error),
        title: const Text('Dung lượng đã dùng'),
        subtitle: Text('Lỗi', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  void _showStorageBreakdown(BuildContext context, WidgetRef ref) {
    final repo = ref.read(documentRepositoryProvider);
    final storage = appStorage;

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<int>(
        future: storage.getModelsSize(),
        builder: (context, modelsSnapshot) {
          final modelsSize = modelsSnapshot.data ?? 0;
          return FutureBuilder<int>(
            future: storage.getAudioCacheSize(),
            builder: (context, audioSnapshot) {
              final audioSize = audioSnapshot.data ?? 0;
              return FutureBuilder<int>(
                future: repo.getStorageUsage(),
                builder: (context, docsSnapshot) {
                  final docsSize = docsSnapshot.data ?? 0;
                  final total = docsSize + audioSize + modelsSize;

                  return AlertDialog(
                    title: const Text('Chi tiết dung lượng'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StorageRow('Tài liệu', docsSize),
                        _StorageRow('Audio cache', audioSize),
                        _StorageRow('Mô hình TTS', modelsSize),
                        const Divider(),
                        _StorageRow('Tổng cộng', total, isTotal: true),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow(this.label, this.bytes, {this.isTotal = false});

  final String label;
  final int bytes;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = isTotal ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            _formatBytes(bytes),
            style: style?.copyWith(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}