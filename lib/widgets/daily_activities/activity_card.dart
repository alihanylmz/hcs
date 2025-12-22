import 'package:flutter/material.dart';
import '../../models/daily_activity.dart';
import '../../theme/app_colors.dart';

class ActivityCard extends StatelessWidget {
  final DailyActivity activity;
  final Function(DailyActivity, ActivityStep) onToggleStep;
  final Function(DailyActivity) onToggleActivity;
  final Function(DailyActivity) onDelete;
  final Function(DailyActivity) onConfirmDelete;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onToggleStep,
    required this.onToggleActivity,
    required this.onDelete,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(activity.id),
      direction: activity.isAssignedByManager ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Confirm dialog logic should be handled by the parent via callback returning Future<bool>
        // But since Dismissible expects a Future<bool> here, we might need a workaround or pass a Future returning function.
        // For simplicity in this refactor, let's assume the parent handles the dialog and we trigger it here.
        // NOTE: In a stateless widget, we can't easily await a dialog unless passed as a async function.
        // Let's wrap the callback.
        return await onConfirmDelete(activity); 
      },
      onDismissed: (direction) => onDelete(activity),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: activity.progress,
                    backgroundColor: Colors.grey.shade100,
                    color: activity.progress == 1.0 ? Colors.green : AppColors.primary,
                    strokeWidth: 4,
                  ),
                  Text(
                    "${(activity.progress * 100).toInt()}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activity.progress == 1.0 ? Colors.green : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              activity.title,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16, 
                color: activity.isCompleted ? Colors.grey : const Color(0xFF1E293B),
                decoration: activity.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: activity.isAssignedByManager
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text('Yönetici Atadı', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                      ],
                    ),
                  )
                : Text(
                    "${activity.steps.length} Adım",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
            
            trailing: Transform.scale(
              scale: 1.1,
              child: Checkbox(
                value: activity.isCompleted,
                shape: const CircleBorder(),
                activeColor: Colors.green,
                onChanged: (val) => onToggleActivity(activity),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            
            children: activity.steps.isEmpty
                ? [
                    ListTile(
                      title: const Text("Bu iş paketinde alt adım yok."),
                      trailing: TextButton(
                        onPressed: () => onToggleActivity(activity),
                        child: Text(activity.isCompleted ? "Geri Al" : "Tamamla"),
                      ),
                    )
                  ]
                : activity.steps.map((step) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 20, right: 16),
                      horizontalTitleGap: 0,
                      title: Text(
                        step.title,
                        style: TextStyle(
                          decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                          color: step.isCompleted ? Colors.grey : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      leading: Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: step.isCompleted,
                          activeColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            onToggleStep(activity, step);
                          },
                        ),
                      ),
                      onTap: () => onToggleStep(activity, step),
                    );
                  }).toList(),
          ),
        ),
      ),
    );
  }
}
