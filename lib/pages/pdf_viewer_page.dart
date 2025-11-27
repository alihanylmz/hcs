import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfViewerPage extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() pdfGenerator;

  const PdfViewerPage({
    super.key, 
    required this.title, 
    required this.pdfGenerator,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) => pdfGenerator(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
        // PdfPreview otomatik olarak kaydet/indir/yazdır butonlarını sağlar
      ),
    );
  }
}

