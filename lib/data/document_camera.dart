import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// What taking a photo came to.
sealed class PhotoResult {
  const PhotoResult();
}

/// A photo: its bytes (a JPEG, at most [DocumentCamera.maxSide] px on its
/// long side).
class PhotoTaken extends PhotoResult {
  final Uint8List bytes;

  const PhotoTaken(this.bytes);
}

/// The camera closed without one.
class PhotoCancelled extends PhotoResult {
  const PhotoCancelled();
}

/// The camera couldn't open: not allowed (in Android's settings), or no
/// camera app.
class PhotoUnavailable extends PhotoResult {
  const PhotoUnavailable();
}

/// The camera and the gallery, for the Documents page's pictures (spec:
/// storage). A photo or a pick is copied by the picker to a staging file,
/// read, and that copy deleted; the gallery's original is never touched.
abstract interface class DocumentCamera {
  /// Pictures are resized to this on their long side.
  static const maxSide = 2000.0;
  static const quality = 85;

  Future<PhotoResult> takePhoto();

  /// Pictures picked from the gallery (none if cancelled).
  Future<List<Uint8List>> pickFromGallery();
}

/// [DocumentCamera] through image_picker (Android's camera app and photo
/// picker: no permission of the app's own needed).
class SystemDocumentCamera implements DocumentCamera {
  const SystemDocumentCamera();

  static final _picker = ImagePicker();

  /// [file]'s bytes; its staging copy deleted.
  static Future<Uint8List> _take(XFile file) async {
    final bytes = await file.readAsBytes();
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // Already gone, or the picker's own: nothing to clean.
    }
    return bytes;
  }

  @override
  Future<PhotoResult> takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: DocumentCamera.maxSide,
        maxHeight: DocumentCamera.maxSide,
        imageQuality: DocumentCamera.quality,
      );
      if (file == null) return const PhotoCancelled();
      return PhotoTaken(await _take(file));
    } on PlatformException {
      return const PhotoUnavailable();
    }
  }

  @override
  Future<List<Uint8List>> pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: DocumentCamera.maxSide,
        maxHeight: DocumentCamera.maxSide,
        imageQuality: DocumentCamera.quality,
      );
      return [for (final f in files) await _take(f)];
    } on PlatformException {
      return const [];
    }
  }
}

final documentCameraProvider = Provider<DocumentCamera>(
  (ref) => const SystemDocumentCamera(),
);

/// The phone's gallery, for Download: a copy of a picture saved there
/// (in Pictures/The App), outside the app's protection, by choice.
abstract interface class PhotoGallery {
  /// Saves [bytes] as [name]; false if it couldn't.
  Future<bool> save(Uint8List bytes, String name);
}

/// [PhotoGallery] through the app's own Android code (MainActivity).
class AndroidPhotoGallery implements PhotoGallery {
  const AndroidPhotoGallery();

  static const _channel = MethodChannel('the_app/gallery');

  @override
  Future<bool> save(Uint8List bytes, String name) async {
    try {
      return await _channel
              .invokeMethod<bool>('save', {'bytes': bytes, 'name': name}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final photoGalleryProvider = Provider<PhotoGallery>(
  (ref) => const AndroidPhotoGallery(),
);
