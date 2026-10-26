import 'dart:io';

import '../utils/expiry_parser.dart';
import 'ml_kit_service.dart';

/// Backward-compatible wrapper for older screens that still import OcrService.
/// It uses the current specialized ML Kit package through MlKitService and does
/// not depend on the removed umbrella package `google_ml_kit`.
class OcrService {
  final MlKitService _mlKit = MlKitService();

  Future<String?> extractExpiryDate(File imageFile) async {
    final text = await extractAllText(imageFile);
    final date = ExpiryParser.parse(text);
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<String> extractAllText(File imageFile) async {
    if (!await imageFile.exists()) {
      throw ArgumentError.value(imageFile.path, 'imageFile', 'Image file does not exist.');
    }
    final result = await _mlKit.recognizeText(imageFile.path);
    return result.text;
  }

  /// MlKitService creates and closes its recognizer per operation, so no
  /// persistent native resource remains to release here.
  void dispose() {}
}
