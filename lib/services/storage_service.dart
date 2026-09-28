import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadCourseBytes({
    required String courseId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final safeName = _safeFileName(fileName);

    final ref = _storage
        .ref()
        .child('courses')
        .child(courseId)
        .child(safeName);

    final metadata = SettableMetadata(
      contentType: contentType,
    );

    await ref.putData(
      bytes,
      metadata,
    );

    return await ref.getDownloadURL();
  }

  String _safeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_');
  }
}