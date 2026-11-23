import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/document_camera.dart';
import 'package:the_app/providers/documents_provider.dart';

/// What adding pictures came to: the new pictures' ids (none if
/// cancelled), and whether the camera couldn't open.
typedef PicturesAdded = ({List<String> ids, bool unavailable});

/// The Documents page's camera, gallery and Download: pictures taken or
/// picked are stored at once ([DocumentsNotifier.addPicture]).
class DocumentPictures {
  final Ref _ref;

  DocumentPictures(this._ref);

  DocumentsNotifier get _documents => _ref.read(documentsProvider.notifier);

  Future<PicturesAdded> takePhoto() async {
    switch (await _ref.read(documentCameraProvider).takePhoto()) {
      case PhotoTaken(:final bytes):
        return (ids: [await _documents.addPicture(bytes)], unavailable: false);
      case PhotoCancelled():
        return (ids: const <String>[], unavailable: false);
      case PhotoUnavailable():
        return (ids: const <String>[], unavailable: true);
    }
  }

  Future<PicturesAdded> pickFromGallery() async {
    final picked = await _ref.read(documentCameraProvider).pickFromGallery();
    return (
      ids: [for (final bytes in picked) await _documents.addPicture(bytes)],
      unavailable: false,
    );
  }

  /// A copy of picture [id] saved to the phone's gallery as [name]; false
  /// if it couldn't be.
  Future<bool> download(String id, String name) async {
    final bytes = await _documents.readPicture(id);
    if (bytes == null) return false;
    return _ref.read(photoGalleryProvider).save(bytes, name);
  }
}

final documentPicturesProvider = Provider<DocumentPictures>(
  DocumentPictures.new,
);
