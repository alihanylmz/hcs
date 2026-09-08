import 'package:flutter/material.dart';

class QuoteEditorLineTable extends StatelessWidget {
  const QuoteEditorLineTable({
    super.key,
    required this.header,
    required this.rows,
  });

  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
      child: Column(
        children: [
          header,
          const SizedBox(height: 6),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 1),
            rows[index],
          ],
        ],
      ),
    );
  }
}
