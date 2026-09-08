import 'package:flutter/material.dart';

class QuoteEditorProductCatalogEmptyState extends StatelessWidget {
  const QuoteEditorProductCatalogEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
