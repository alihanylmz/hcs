import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../theme/app_colors.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String pdfFileName;
  final Future<Uint8List> Function() pdfGenerator;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.pdfFileName,
    required this.pdfGenerator,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  Uint8List? _cachedPdfBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final bytes = await widget.pdfGenerator();
      print('PdfViewerPage: PDF bytes yüklendi: ${bytes.length} byte');

      if (bytes.isEmpty) {
        throw Exception('PDF oluşturulamadı: Dosya boş');
      }

      if (bytes.length < 4 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
        print('PdfViewerPage: UYARI - PDF başlığı geçersiz görünüyor');
        print(
          'PdfViewerPage: İlk 20 byte: ${bytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
      }

      if (mounted) {
        setState(() {
          _cachedPdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('PdfViewerPage: PDF yükleme hatası: $e');
      print('PdfViewerPage: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.pdfFileName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.corporateNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.corporateNavy),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.corporateNavy),
            SizedBox(height: 16),
            Text(
              'Belge Hazırlanıyor...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Belge Görüntülenemedi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.corporateNavy,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadPdf,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeniden dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Geri Dön'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_cachedPdfBytes == null) {
      return const Center(
        child: Text(
          'PDF yüklenemedi',
          style: TextStyle(fontSize: 16, color: AppColors.textLight),
        ),
      );
    }

    return PdfPreview(
      build: (format) {
        print('PdfPreview: build çağrıldı, format: $format');
        final bytesCopy = Uint8List.fromList(_cachedPdfBytes!);
        return Future.value(bytesCopy);
      },
      pdfFileName: widget.pdfFileName,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowSharing: true,
      allowPrinting: true,
      loadingWidget: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.corporateNavy),
            SizedBox(height: 16),
            Text(
              'Belge Hazırlanıyor...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      onError:
          (context, error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Belge Görüntülenemedi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.corporateNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Geri Dön'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      scrollViewDecoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
    );
  }
}
