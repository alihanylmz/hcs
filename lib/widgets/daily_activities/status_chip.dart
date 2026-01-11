import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum ActivityStatus { todo, inProgress, done }

class StatusChip extends StatelessWidget {
  final ActivityStatus status;
  final bool dense;

  const StatusChip({
    super.key,
    required this.status,
    this.dense = true,
  });

  String get _label {
    switch (status) {
      case ActivityStatus.todo:
        return 'Yapılacak';
      case ActivityStatus.inProgress:
        return 'Devam';
      case ActivityStatus.done:
        return 'Bitti';
    }
  }

  IconData get _icon {
    switch (status) {
      case ActivityStatus.todo:
        return Icons.radio_button_unchecked;
      case ActivityStatus.inProgress:
        return Icons.timelapse_rounded;
      case ActivityStatus.done:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color get _baseColor {
    switch (status) {
      case ActivityStatus.todo:
        return AppColors.primary;
      case ActivityStatus.inProgress:
        return AppColors.statusProgress;
      case ActivityStatus.done:
        return AppColors.statusDone;
    }
  }

  Color get _bgColor {
    switch (status) {
      case ActivityStatus.todo:
        return AppColors.primary.withOpacity(0.08);
      case ActivityStatus.inProgress:
        return AppColors.statusProgress.withOpacity(0.14);
      case ActivityStatus.done:
        return AppColors.statusDone.withOpacity(0.14);
    }
  }

  Color get _borderColor => _baseColor.withOpacity(0.18);

  @override
  Widget build(BuildContext context) {
    final padH = dense ? 10.0 : 12.0;
    final padV = dense ? 6.0 : 8.0;
    final iconSize = dense ? 14.0 : 16.0;
    final fontSize = dense ? 12.0 : 13.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: iconSize, color: _baseColor),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: _baseColor,
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


