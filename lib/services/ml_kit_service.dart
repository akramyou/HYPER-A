import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  const OcrResult({required this.text, required this.blocks});
  final String text;
  final int blocks;
}

class BarcodeResult {
  const BarcodeResult({required this.value, required this.format, required this.displayValue});
  final String value;
  final String format;
  final String displayValue;
}

class LabelResult {
  const LabelResult({required this.label, required this.confidence});
  final String label;
  final double confidence;
}

class MlKitService {
  Future<OcrResult> recognizeText(String filePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(filePath);
      final result = await recognizer.processImage(image);
      return OcrResult(text: result.text, blocks: result.blocks.length);
    } finally {
      await recognizer.close();
    }
  }

  Future<List<BarcodeResult>> scanBarcodes(String filePath) async {
    final scanner = BarcodeScanner(formats: const [BarcodeFormat.all]);
    try {
      final result = await scanner.processImage(InputImage.fromFilePath(filePath));
      return result.where((b) => (b.rawValue ?? '').trim().isNotEmpty).map((b) => BarcodeResult(
            value: b.rawValue!.trim(),
            format: b.format.name,
            displayValue: b.displayValue ?? b.rawValue!.trim(),
          )).toList();
    } finally {
      await scanner.close();
    }
  }

  Future<List<LabelResult>> labelImage(String filePath) async {
    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.40));
    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(filePath));
      return labels.map((label) => LabelResult(label: label.label, confidence: label.confidence)).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
    } finally {
      await labeler.close();
    }
  }
}
