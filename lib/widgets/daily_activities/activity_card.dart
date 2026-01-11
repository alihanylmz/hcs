import 'package:flutter/material.dart';
import '../../models/daily_activity.dart';
import '../../theme/app_colors.dart';
import 'status_chip.dart';
import '../../utils/text_sanitizer.dart';

class ActivityCard extends StatefulWidget {
  final DailyActivity activity;
  final Function(DailyActivity, ActivityStep) onToggleStep;
  final Function(DailyActivity) onToggleActivity;
  final Function(DailyActivity) onDelete;
  final Function(DailyActivity) onConfirmDelete;
  final bool canGiveKpi;
  final Function(DailyActivity, int?) onKpiChanged;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onToggleStep,
    required this.onToggleActivity,
    required this.onDelete,
    required this.onConfirmDelete,
    this.canGiveKpi = false,
    required this.onKpiChanged,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If steps disappear, ensure we collapse to avoid odd empty space.
    if (widget.activity.steps.isEmpty && _expanded) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final status = _statusFromActivity(a);
    final hasSteps = a.steps.isNotEmpty;
    final showProgressBar = hasSteps;
    final title = TextSanitizer.stripEmoji(a.title);

    return Dismissible(
      key: Key(a.id),
      direction: a.isAssignedByManager ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) => widget.onConfirmDelete(a),
      onDismissed: (_) => widget.onDelete(a),
      background: _DeleteSwipeBackground(),
      child: _SoftCard(
        onTapHeader: hasSteps ? () => setState(() => _expanded = !_expanded) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: progress badge + title, status chip at top-right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeadingBadge(
                  isDone: a.isCompleted || a.progress >= 1.0,
                  isInProgress: a.progress > 0 && a.progress < 1.0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: a.isCompleted ? AppColors.textLight : AppColors.textDark,
                        decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: StatusChip(status: status),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Meta row: subtle info + cleaner toggle + optional expand affordance.
            Row(
              children: [
                Icon(
                  a.isAssignedByManager ? Icons.lock_outline_rounded : (hasSteps ? Icons.checklist_rounded : Icons.task_alt_rounded),
                  size: 16,
                  color: a.isAssignedByManager ? AppColors.primary : AppColors.textLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.isAssignedByManager ? 'Yönetici Atadı' : (hasSteps ? 'Alt adımlar' : 'Tek adım'),
                    style: TextStyle(
                      color: a.isAssignedByManager ? AppColors.primary : AppColors.textLight,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                _TogglePill(
                  value: a.isCompleted,
                  onTap: () => widget.onToggleActivity(a),
                ),
                if (hasSteps) ...[
                  const SizedBox(width: 8),
                  _ExpandChevron(expanded: _expanded),
                ],
              ],
            ),

            if (showProgressBar) ...[
              const SizedBox(height: 12),
              _InlineProgressBar(value: a.progress),
            ],

            // KPI Score Section - Sadece biten işler için göster
            if (a.isCompleted) ...[
              const SizedBox(height: 12),
              _KpiScoreRow(
                score: a.kpiScore,
                canEdit: widget.canGiveKpi,
                onChanged: (score) => widget.onKpiChanged(a, score),
              ),
            ],

            if (hasSteps) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded ? const SizedBox(height: 12) : const SizedBox(height: 0),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: _StepsList(
                    steps: a.steps,
                    onToggle: (step) => widget.onToggleStep(a, step),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ActivityStatus _statusFromActivity(DailyActivity a) {
    // UI-only status: derived from existing model fields (no logic changes to services/models).
    if (a.isCompleted || a.progress >= 1.0) return ActivityStatus.done;
    if (a.progress > 0) return ActivityStatus.inProgress;
    return ActivityStatus.todo;
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTapHeader;

  const _SoftCard({required this.child, this.onTapHeader});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.primary.withOpacity(0.10);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapHeader,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withOpacity(0.06),
          highlightColor: AppColors.primary.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 26),
    );
  }
}

class _LeadingBadge extends StatelessWidget {
  final bool isDone;
  final bool isInProgress;
  const _LeadingBadge({required this.isDone, required this.isInProgress});

  @override
  Widget build(BuildContext context) {
    final Color ring = isDone
        ? AppColors.statusDone
        : (isInProgress ? AppColors.statusProgress : AppColors.primary.withOpacity(0.55));
    final Color fill = ring.withOpacity(0.10);

    final IconData icon = isDone
        ? Icons.check_rounded
        : (isInProgress ? Icons.play_arrow_rounded : Icons.circle_outlined);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ring.withOpacity(0.22)),
      ),
      child: Icon(icon, color: ring, size: 22),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  const _TogglePill({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = value ? AppColors.statusDone.withOpacity(0.14) : AppColors.primary.withOpacity(0.06);
    final border = value ? AppColors.statusDone.withOpacity(0.20) : AppColors.primary.withOpacity(0.10);
    final fg = value ? AppColors.statusDone : AppColors.primary;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.circle_outlined,
              size: 18,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandChevron extends StatelessWidget {
  final bool expanded;
  const _ExpandChevron({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 22,
        color: AppColors.textLight,
      ),
    );
  }
}

class _InlineProgressBar extends StatelessWidget {
  final double value;
  const _InlineProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 1.0 ? AppColors.statusDone : AppColors.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 5,
        backgroundColor: AppColors.primary.withOpacity(0.08),
        valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.9)),
      ),
    );
  }
}

class _StepsList extends StatelessWidget {
  final List<ActivityStep> steps;
  final ValueChanged<ActivityStep> onToggle;
  const _StepsList({required this.steps, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i], onToggle: () => onToggle(steps[i])),
            if (i != steps.length - 1)
              Divider(height: 1, thickness: 1, color: AppColors.primary.withOpacity(0.06)),
          ],
        ],
      ),
    );
  }
}

class _KpiScoreRow extends StatelessWidget {
  final int? score;
  final bool canEdit;
  final ValueChanged<int?> onChanged;

  const _KpiScoreRow({
    required this.score,
    required this.canEdit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          const Text(
            'KPI Puanı:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          if (canEdit)
            Row(
              children: List.generate(5, (index) {
                final starScore = index + 1;
                final isSelected = score != null && score! >= starScore;
                return GestureDetector(
                  onTap: () => onChanged(score == starScore ? null : starScore),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22,
                      color: isSelected ? Colors.amber : AppColors.textLight.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            )
          else if (score != null)
            Row(
              children: List.generate(5, (index) {
                final isSelected = score! >= index + 1;
                return Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: isSelected ? Colors.amber : AppColors.textLight.withValues(alpha: 0.2),
                );
              }),
            )
          else
            const Text(
              'Puanlanmadı',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textLight,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final ActivityStep step;
  final VoidCallback onToggle;
  const _StepRow({required this.step, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final title = TextSanitizer.stripEmoji(step.title);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: step.isCompleted ? AppColors.statusDone.withOpacity(0.16) : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: step.isCompleted
                      ? AppColors.statusDone.withOpacity(0.22)
                      : AppColors.primary.withOpacity(0.10),
                ),
              ),
              child: Icon(
                step.isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                size: 14,
                color: step.isCompleted ? AppColors.statusDone : AppColors.textLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: step.isCompleted ? AppColors.textLight : AppColors.textDark,
                  decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
