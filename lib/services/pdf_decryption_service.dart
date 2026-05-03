import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class PdfDecryptionService {
  // Returns ordered list of password candidates to try for a given bank.
  // First candidate is the most likely correct one.
  static List<String> getPasswordCandidates(String bankId, UserProfile profile) {
    final first4 = profile.firstName.length >= 4
        ? profile.firstName.substring(0, 4).toUpperCase()
        : profile.firstName.toUpperCase();

    final ddmm = '${profile.dd}${profile.mm}';
    final ddmmyyyy = '${profile.dd}${profile.mm}${profile.yyyy}';
    final ddmmyy = '${profile.dd}${profile.mm}${profile.yy}';
    final pan = profile.pan.toUpperCase();
    final panFirst5 = pan.length >= 5 ? pan.substring(0, 5) : pan;

    switch (bankId) {
      case 'hdfc':
        // HDFC: password is Customer ID (stored in .env)
        final customerId = dotenv.env['HDFC_PDF_PASSWORD'] ?? '';
        return [
          if (customerId.isNotEmpty) customerId,
          '$first4$ddmm',
          ddmmyyyy,
        ];

      case 'sbi':
        return [ddmmyyyy, ddmmyy, ddmm];

      case 'icici':
        return [ddmmyyyy, ddmmyy, '$first4$ddmm'];

      case 'axis':
        return [ddmmyyyy, ddmmyy, '$first4$ddmm'];

      case 'kotak':
        return [ddmmyyyy, ddmmyy, '$first4$ddmm'];

      case 'rbl':
        return ['$panFirst5$ddmm', ddmmyyyy, '$first4$ddmm'];

      case 'idfc':
        return [
          '${profile.firstName.toLowerCase()}$ddmmyyyy',
          ddmmyyyy,
          '$first4$ddmm',
        ];

      default:
        return [ddmmyyyy, '$first4$ddmm', ddmmyy];
    }
  }

  static bool isHdfcBankStatement(String filename, String sender) {
    return sender.toLowerCase().contains('hdfc') &&
        filename.toLowerCase().endsWith('.pdf');
  }

  static Future<String?> savePdfToFile({
    required Uint8List pdfData,
    required String filename,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = filename.replaceAll(' ', '_').replaceAll('/', '_');
      final filePath =
          '${tempDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);
      return filePath;
    } catch (e) {
      return null;
    }
  }
}
