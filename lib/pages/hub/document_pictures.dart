import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/providers/documents_provider.dart';

/// A document's picture, turned as it's set, filling its box (cropped to
/// it); a placeholder while it's read, or if it's missing.
class DocThumb extends ConsumerWidget {
  final DocPicture picture;

  /// Its decoded width, to keep memory low (a thumbnail needs little).
  final int cacheWidth;
  final BoxFit fit;

  /// The placeholder's colour while it's read, or null for the theme's
  /// background with an icon. On a barcode's white page, white (the
  /// theme's dark background flashed black there).
  final Color? background;

  const DocThumb({
    super.key,
    required this.picture,
    this.cacheWidth = 240,
    this.fit = BoxFit.cover,
    this.background,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final placeholder = ColoredBox(
      key: const Key('docThumbPlaceholder'),
      color: background ?? colors.background,
      child: background != null
          ? const SizedBox.expand()
          : Center(child: Icon(Icons.image_outlined, color: colors.textHint)),
    );
    final bytes = ref.watch(documentPictureProvider(picture.id)).valueOrNull;
    if (bytes == null) return placeholder;
    return RotatedBox(
      quarterTurns: picture.turns,
      child: Image.memory(
        bytes,
        cacheWidth: cacheWidth,
        fit: fit,
        gaplessPlayback: true,
        // Read but not yet decoded: the placeholder still, then the
        // picture fades in (no empty gap between them).
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (frame == null) Positioned.fill(child: placeholder),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (_, __, ___) => ColoredBox(
          color: colors.background,
          child: Icon(Icons.broken_image_outlined, color: colors.textHint),
        ),
      ),
    );
  }
}

/// A document's pictures, full screen: swiped between, pinched to zoom,
/// turned as they're set. Opens on [initial].
class DocumentViewer extends StatefulWidget {
  final List<DocPicture> pictures;
  final int initial;
  final String title;

  const DocumentViewer({
    super.key,
    required this.pictures,
    this.initial = 0,
    this.title = '',
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _at = widget.initial;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.pictures.length;
    return Scaffold(
      backgroundColor: ViewerColours.background,
      appBar: AppBar(
        backgroundColor: ViewerColours.background,
        foregroundColor: ViewerColours.foreground,
        title: Text(
          count > 1 ? '${_at + 1} of $count' : widget.title,
          key: const Key('documentViewerTitle'),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: count,
        // Zoomed in, a drag moves the picture, not to the next one.
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (i) => setState(() => _at = i),
        itemBuilder: (context, i) => _Zoomable(
          key: Key('documentViewer-${widget.pictures[i].id}'),
          onZoomed: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
          child: Center(
            child: DocThumb(
              picture: widget.pictures[i],
              cacheWidth: 2000,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// A picture pinched to zoom; dragged only while zoomed in (else the drag
/// is the viewer's swipe). Tells [onZoomed] when that changes.
class _Zoomable extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onZoomed;

  const _Zoomable({super.key, required this.child, required this.onZoomed});

  @override
  State<_Zoomable> createState() => _ZoomableState();
}

class _ZoomableState extends State<_Zoomable> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _check() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomed(zoomed);
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        transformationController: _transform,
        maxScale: 6,
        panEnabled: _zoomed,
        onInteractionUpdate: (_) => _check(),
        onInteractionEnd: (_) => _check(),
        child: widget.child,
      );
}
