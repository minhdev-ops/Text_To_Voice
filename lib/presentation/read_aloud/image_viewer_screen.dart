import 'dart:io' show File;

import 'package:flutter/material.dart';

/// A page image, full screen and zoomable.
///
/// Built on [InteractiveViewer] rather than a photo-view package: pinch, pan and
/// double-tap are all the viewer needs, and every dependency in this app has to
/// earn its bytes in the store listing.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.filePath,
    this.heroTag,
    this.title,
  });

  final String filePath;

  /// Ties the thumbnail to this screen, so opening an image grows out of the
  /// page it came from.
  final String? heroTag;

  final String? title;

  /// Pushes the viewer over everything, dimmed to black.
  static Future<void> show(
    BuildContext context, {
    required String filePath,
    String? heroTag,
    String? title,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => ImageViewerScreen(
          filePath: filePath,
          heroTag: heroTag,
          title: title,
        ),
      ),
    );
  }

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transform = TransformationController();

  /// `true` after a double tap zoomed in, so the next one zooms back out.
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
    } else {
      const scale = 2.5;
      final position = details.localPosition;
      _transform.value = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    }
    setState(() => _zoomed = !_zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.title == null
            ? null
            : Text(widget.title!, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
        ),
      ),
      body: Center(
        child: GestureDetector(
          onDoubleTapDown: _toggleZoom,
          // Claimed so the double-tap-down above is not eaten by the gesture
          // arena on the first tap.
          onDoubleTap: () {},
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 8,
            child: widget.heroTag == null
                ? _image(file)
                : Hero(tag: widget.heroTag!, child: _image(file)),
          ),
        ),
      ),
    );
  }

  Widget _image(File file) => Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không mở được ảnh này.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
}
