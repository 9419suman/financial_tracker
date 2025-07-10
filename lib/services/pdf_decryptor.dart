import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfDecryptor {
  // Remove password from PDF using Syncfusion PDF library
  static Future<Uint8List?> removePasswordFromPdf(Uint8List pdfData, String password) async {
    try {
      print('PdfDecryptor: Starting password removal process');
      
      // Method 1: Direct approach - load with password and save without security
      try {
        print('PdfDecryptor: Trying direct save approach');
        final PdfDocument document = PdfDocument(
          inputBytes: pdfData,
          password: password,
        );
        
        // Attempt to disable security
        document.security.userPassword = '';
        document.security.ownerPassword = '';
        
        // Save the document without password
        final List<int> bytes = document.saveSync();
        document.dispose();
        
        print('PdfDecryptor: Decrypted using direct save approach (${bytes.length} bytes)');
        return Uint8List.fromList(bytes);
      } catch (e) {
        print('PdfDecryptor: Direct save approach failed: $e');
        // Continue to next method
      }
      
      // Method 2: Extract and recreate text approach
      try {
        print('PdfDecryptor: Trying text extraction approach');
        
        // Load the encrypted PDF
        final PdfDocument sourcePdf = PdfDocument(
          inputBytes: pdfData,
          password: password,
        );
        
        // Create a new PDF document (without encryption)
        final PdfDocument newPdf = PdfDocument();
        
        // Process each page
        for (int i = 0; i < sourcePdf.pages.count; i++) {
          // Extract text from the source page
          PdfTextExtractor extractor = PdfTextExtractor(sourcePdf);
          String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          
          // Add a new page
          PdfPage newPage = newPdf.pages.add();
          
          // Add text to the new page
          if (pageText.isNotEmpty) {
            final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 10);
            final PdfStringFormat format = PdfStringFormat();
            format.alignment = PdfTextAlignment.left;
            
            newPage.graphics.drawString(
              pageText,
              font,
              brush: PdfSolidBrush(PdfColor(0, 0, 0)),
              format: format,
            );
          }
          
          print('PdfDecryptor: Processed page ${i + 1} using text extraction');
        }
        
        // Save the new PDF without encryption
        final List<int> bytes = newPdf.saveSync();
        
        // Clean up
        sourcePdf.dispose();
        newPdf.dispose();
        
        print('PdfDecryptor: Decrypted using text extraction (${bytes.length} bytes)');
        return Uint8List.fromList(bytes);
      } catch (e) {
        print('PdfDecryptor: Text extraction approach failed: $e');
        return null;
      }
    } catch (e) {
      print('PdfDecryptor: All decryption methods failed: $e');
      return null;
    }
  }
  
  // Save PDF to Downloads directory
  static Future<String?> savePdfToDownloads(Uint8List pdfData, String filename) async {
    try {
      print('PdfDecryptor: Starting save to Downloads process');
      
      // Request storage permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
      
      bool hasStoragePermission = statuses[Permission.storage]!.isGranted || 
                                 statuses[Permission.manageExternalStorage]!.isGranted;
      
      if (!hasStoragePermission) {
        print('PdfDecryptor: Storage permission denied');
        throw Exception('Storage permission denied');
      }
      
      // Try to get the downloads directory
      Directory? downloadsDir;
      
      // For Android
      if (Platform.isAndroid) {
        // Try multiple approaches to get Downloads directory
        try {
          print('PdfDecryptor: Attempting to access standard Download directories');
          
          // First attempt - standard Downloads path
          final standardPaths = [
            '/storage/emulated/0/Download',
            '/sdcard/Download',
            '/storage/emulated/0/Downloads',
            '/sdcard/Downloads',
          ];
          
          for (final path in standardPaths) {
            final dir = Directory(path);
            if (await dir.exists()) {
              downloadsDir = dir;
              print('PdfDecryptor: Found Downloads directory at: ${dir.path}');
              break;
            }
          }
          
          // Try using getExternalStorageDirectory as fallback
          if (downloadsDir == null) {
            print('PdfDecryptor: Standard Download directories not accessible, trying getExternalStorageDirectory');
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // Use the external storage
              downloadsDir = externalDir;
              print('PdfDecryptor: Using external storage directory: ${externalDir.path}');
            }
          }
        } catch (e) {
          print('PdfDecryptor: Could not access Android Downloads directory: $e');
          downloadsDir = null;
        }
      }
      
      // Fallback to documents directory if downloads not available
      if (downloadsDir == null) {
        print('PdfDecryptor: Using fallback directory');
        final docsDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(docsDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      }
      
      print('PdfDecryptor: Using directory: ${downloadsDir.path}');
      
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = filename
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('.', '_');
      final safeFilename = '${safeName}_decrypted_$timestamp.pdf';
      
      // Full path for the file
      final savePath = path.join(downloadsDir.path, safeFilename);
      
      print('PdfDecryptor: Saving decrypted PDF to: $savePath');
      
      // Save the file
      final file = File(savePath);
      await file.writeAsBytes(pdfData);
      
      print('PdfDecryptor: PDF saved successfully to: $savePath');
      return savePath;
    } catch (e) {
      print('PdfDecryptor: Error saving PDF to Downloads: $e');
      return null;
    }
  }
} 