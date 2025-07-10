import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PdfDecryptionService {
  // HDFC Bank statement password
  static const String defaultPassword = '114210210';

  // Save PDF data to a file so it can be opened
  static Future<String?> savePdfToFile({
    required Uint8List pdfData,
    required String filename,
  }) async {
    try {
      print('Saving PDF to file: $filename (${pdfData.length} bytes)');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final safeName = filename.replaceAll(' ', '_').replaceAll('/', '_');
      final filePath = '${tempDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      print('PDF will be saved to: $filePath');
      
      // Write data to file
      final file = File(filePath);
      await file.writeAsBytes(pdfData);
      
      print('PDF saved successfully');
      return filePath;
    } catch (e) {
      print('Error saving PDF to file: $e');
      return null;
    }
  }
  
  // Get the password for bank statement PDFs
  static String getDefaultPassword() {
    return defaultPassword;
  }
  
  // Check if a filename is likely a PDF from HDFC Bank
  static bool isHdfcBankStatement(String filename, String sender) {
    final isFromHdfc = sender.toLowerCase().contains('hdfc');
    final isPdfFile = filename.toLowerCase().endsWith('.pdf');
    
    return isFromHdfc && isPdfFile;
  }
} 