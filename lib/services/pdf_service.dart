import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service class that handles PDF download, storage, and management
/// for job notification PDFs.
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      responseType: ResponseType.bytes,
    ),
  );

  /// Directory name where PDFs are stored within the app's documents directory.
  static const String _pdfDirectoryName = 'downloaded_pdfs';

  // ─────────────────────────────────────────────────────────────────────────
  // DOWNLOAD
  // ─────────────────────────────────────────────────────────────────────────

  /// Downloads a PDF from [url] and saves it with the given [filename].
  ///
  /// Returns the full path to the downloaded file.
  ///
  /// Optionally provides download progress via [onProgress] callback
  /// which receives the percentage (0.0 to 1.0).
  ///
  /// Throws [PdfServiceException] if download fails.
  Future<String> downloadPdf(
    String url,
    String filename, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final directory = await _getPdfDirectory();
      final sanitizedFilename = _sanitizeFilename(filename);
      final filePath = path.join(directory.path, sanitizedFilename);

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      // Download the file
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      if (response.data == null || response.data!.isEmpty) {
        throw PdfServiceException('Downloaded file is empty');
      }

      // Write to file
      await file.writeAsBytes(response.data!);

      return filePath;
    } on DioException catch (e) {
      throw PdfServiceException(
        'Failed to download PDF: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to download PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIST DOWNLOADED
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a list of all downloaded PDF files.
  ///
  /// Files are sorted by last modified date (newest first).
  Future<List<File>> getDownloadedPdfs() async {
    try {
      final directory = await _getPdfDirectory();

      if (!await directory.exists()) {
        return [];
      }

      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.toLowerCase().endsWith('.pdf'))
          .toList();

      // Sort by last modified date (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      throw PdfServiceException('Failed to list downloaded PDFs: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes the PDF file at the given [filePath].
  ///
  /// Throws [PdfServiceException] if deletion fails or file doesn't exist.
  Future<void> deletePdf(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw PdfServiceException('File not found: $filePath');
      }

      await file.delete();
    } catch (e) {
      if (e is PdfServiceException) rethrow;
      throw PdfServiceException('Failed to delete PDF: $e');
    }
  }

  /// Deletes all downloaded PDFs.
  Future<void> deleteAllPdfs() async {
    try {
      final directory = await _getPdfDirectory();

      if (await directory.exists()) {
        final files = directory.listSync().whereType<File>();
        for (final file in files) {
          await file.delete();
        }
      }
    } catch (e) {
      throw PdfServiceException('Failed to delete all PDFs: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILE INFO
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the total size of all downloaded PDFs in bytes.
  Future<int> getTotalDownloadSize() async {
    try {
      final files = await getDownloadedPdfs();
      int totalSize = 0;
      for (final file in files) {
        totalSize += await file.length();
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if a PDF with the given [filename] has already been downloaded.
  Future<bool> isDownloaded(String filename) async {
    final directory = await _getPdfDirectory();
    final sanitizedFilename = _sanitizeFilename(filename);
    final file = File(path.join(directory.path, sanitizedFilename));
    return file.exists();
  }

  /// Returns the file path for a given filename if it exists.
  Future<String?> getFilePath(String filename) async {
    final directory = await _getPdfDirectory();
    final sanitizedFilename = _sanitizeFilename(filename);
    final filePath = path.join(directory.path, sanitizedFilename);
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the directory where PDFs are stored, creating it if necessary.
  Future<Directory> _getPdfDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(path.join(appDir.path, _pdfDirectoryName));

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    return pdfDir;
  }

  /// Sanitizes a filename to remove invalid characters.
  String _sanitizeFilename(String filename) {
    // Ensure .pdf extension
    if (!filename.toLowerCase().endsWith('.pdf')) {
      filename = '$filename.pdf';
    }

    // Replace invalid characters
    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    // Trim whitespace and dots from ends
    filename = filename.trim().replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');

    return filename.isEmpty ? 'download_${DateTime.now().millisecondsSinceEpoch}.pdf' : filename;
  }
}

/// Custom exception class for PdfService errors.
class PdfServiceException implements Exception {
  final String message;
  final int? statusCode;

  PdfServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'PdfServiceException: $message (status: $statusCode)';
}
