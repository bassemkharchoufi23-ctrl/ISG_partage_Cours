import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String scriptUrl =
      ''
      'https://script.google.com/macros/s/AKfycbyFaLFKpeS5Rz6tjjI3V0kfkiL424qJpizCLuBwJyvI18OznM07N7oXd3Ai85H3IpNLzg/exec';

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  Future<DriveFileResult> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final client = http.Client();

    try {
      final body = jsonEncode({
        'fileName': fileName,
        'mimeType': mimeType,
        'file': base64Encode(bytes),
      });

      final request = http.Request(
        'POST',
        Uri.parse(scriptUrl),
      );

      request.headers['Content-Type'] = 'application/json';
      request.body = body;

      // مهم جداً:
      // لا نخلي http يتعامل مع 302 تلقائياً.
      request.followRedirects = false;

      final streamedResponse = await client.send(request);

      final response =
      await http.Response.fromStream(streamedResponse);

      _log('======================================');
      _log('Google Apps Script');
      _log('POST status: ${response.statusCode}');
      _log('POST location: ${response.headers['location']}');
      _log('POST body: ${response.body}');
      _log('======================================');

      // ==========================================================
      // CAS NORMAL
      // ==========================================================

      if (response.statusCode == 200) {
        return _parseResponse(
          response.body,
          fileName,
        );
      }

      // ==========================================================
      // GOOGLE APPS SCRIPT 302
      // ==========================================================

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        final location = response.headers['location'];

        if (location == null || location.isEmpty) {
          throw Exception(
            'Google Apps Script a retourné ${response.statusCode} '
                'mais aucun lien de redirection.',
          );
        }

        _log('Redirection Google:');
        _log(location);

        // Google Apps Script redirige la réponse vers
        // script.googleusercontent.com.
        //
        // Le fichier a déjà été créé dans Drive.
        // On récupère maintenant la réponse JSON
        // depuis l'URL de redirection.

        final redirectResponse = await client.get(
          Uri.parse(location),
        );

        _log('======================================');
        _log('GET REDIRECT');
        _log('status: ${redirectResponse.statusCode}');
        _log('body: ${redirectResponse.body}');
        _log('======================================');

        if (redirectResponse.statusCode != 200) {
          throw Exception(
            'Erreur après redirection Google Apps Script: '
                '${redirectResponse.statusCode}',
          );
        }

        return _parseResponse(
          redirectResponse.body,
          fileName,
        );
      }

      throw Exception(
        'Google Apps Script HTTP ${response.statusCode}\n'
            '${response.body}',
      );
    } finally {
      client.close();
    }
  }

  DriveFileResult _parseResponse(
      String body,
      String originalFileName,
      ) {
    if (body.trim().isEmpty) {
      throw Exception(
        'Google Apps Script a retourné une réponse vide.',
      );
    }

    dynamic data;

    try {
      data = jsonDecode(body);
    } catch (e) {
      throw Exception(
        'Réponse Google Apps Script non JSON:\n$body',
      );
    }

    if (data is! Map) {
      throw Exception(
        'Réponse Google Apps Script invalide.',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ??
            data['message']?.toString() ??
            'Erreur inconnue Google Drive.',
      );
    }

    final fileId =
        data['fileId']?.toString() ?? '';

    final fileName =
        data['fileName']?.toString() ??
            originalFileName;

    String fileUrl =
        data['fileUrl']?.toString() ?? '';

    // Si Apps Script ne renvoie pas fileUrl,
    // on peut construire le lien Google Drive.
    if (fileUrl.isEmpty && fileId.isNotEmpty) {
      fileUrl =
      'https://drive.google.com/file/d/$fileId/view';
    }

    _log('======================================');
    _log('GOOGLE DRIVE UPLOAD OK');
    _log('fileId: $fileId');
    _log('fileName: $fileName');
    _log('fileUrl: $fileUrl');
    _log('======================================');

    return DriveFileResult(
      fileId: fileId,
      fileName: fileName,
      fileUrl: fileUrl,
    );
  }
}

class DriveFileResult {
  final String fileId;
  final String fileName;
  final String fileUrl;

  DriveFileResult({
    required this.fileId,
    required this.fileName,
    required this.fileUrl,
  });
}