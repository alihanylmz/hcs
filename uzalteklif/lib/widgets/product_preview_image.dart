import 'dart:io';

import 'package:flutter/material.dart';

/// `Product.image_path`: yerel dosya yolu veya Supabase public URL.
class ProductPreviewImage extends StatelessWidget {
  const ProductPreviewImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheSize,
    this.errorIconSize = 24,
  });

  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Piksel cinsinden decode tavanı (bellek); ornegin 180 ~ 62dp @ 3x.
  final int? cacheSize;
  final double errorIconSize;

  static bool isRemotePath(String raw) {
    final t = raw.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath.trim();
    if (path.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    if (isRemotePath(path)) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheSize,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          size: errorIconSize,
          color: const Color(0xFF17304C),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return Icon(
        Icons.broken_image_outlined,
        size: errorIconSize,
        color: const Color(0xFF17304C),
      );
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheSize,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.broken_image_outlined,
        size: errorIconSize,
        color: const Color(0xFF17304C),
      ),
    );
  }
}
