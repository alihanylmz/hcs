// TicketDetailPage'in (lib/pages/ticket_detail_page.dart) saf/yaprak gorsel
// bilesenleri. Bu widget'lar sadece kendi parametrelerini okur, sayfanin
// state'ine (ornek: _ticket, _notes) hicbir sekilde erismez - bu yuzden ilk
// ve en dusuk riskli cikarma partisi olarak buraya tasindi.
//
// Bu tasima saf mekaniktir: hicbir gorsel/davranissal degisiklik yapilmadi,
// yalnizca kod nereye yazildigi degisti. TicketDetailPage'deki karsilik
// gelen private metodlar silindi ve cagri yerleri bu widget'lara yonlendirildi.
//
// Not: ticket_detail_page.dart'ta ayni renk yardimcilari (_isDark,
// _surfaceColor, vb.) baska pek cok yerde hala kullanildigi icin oradan
// silinmedi; buradaki kucuk kopyalari sadece bu dosyadaki widget'lar icindir.
import 'package:flutter/material.dart';

import '../../models/ticket_daily_report.dart';
import '../../theme/app_colors.dart';

bool ticketDetailIsDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color ticketDetailSurfaceColor(BuildContext context) {
  return Theme.of(context).cardColor;
}

Color ticketDetailSurfaceMutedColor(BuildContext context) {
  return ticketDetailIsDark(context)
      ? AppColors.surfaceDarkMuted
      : AppColors.surfaceSoft;
}

Color ticketDetailBorderColor(BuildContext context) {
  return ticketDetailIsDark(context)
      ? AppColors.borderDark
      : AppColors.borderSubtle;
}

Color ticketDetailPrimaryTextColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface;
}

Color ticketDetailSecondaryTextColor(BuildContext context) {
  return ticketDetailIsDark(context)
      ? AppColors.textOnDarkMuted
      : AppColors.textLight;
}

Color ticketDetailCorporatePanelColor(BuildContext context) {
  return ticketDetailIsDark(context)
      ? AppColors.surfaceDarkMuted
      : AppColors.surfaceAccent;
}

Color ticketDetailPageAccentColor(BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

String formatTicketDailyReportDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

/// Eski adi: `_buildMetaPill`.
class TicketDetailMetaPill extends StatelessWidget {
  const TicketDetailMetaPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ticketDetailSurfaceMutedColor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ticketDetailBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: ticketDetailPrimaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildHeaderInfoPanel`.
class TicketDetailHeaderInfoPanel extends StatelessWidget {
  const TicketDetailHeaderInfoPanel({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isCompact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ticketDetailPageAccentColor(context);

    return Container(
      width: isCompact ? 240 : 184,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: ticketDetailSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ticketDetailBorderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ticketDetailSecondaryTextColor(context),
                    fontSize: 10,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: isCompact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ticketDetailPrimaryTextColor(context),
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildHeaderActionButton`.
class TicketDetailHeaderActionButton extends StatelessWidget {
  const TicketDetailHeaderActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ticketDetailPageAccentColor(context);
    final isEnabled = onPressed != null;
    final foregroundColor = isEnabled
        ? accent
        : ticketDetailSecondaryTextColor(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isEnabled
              ? ticketDetailSurfaceColor(context)
              : ticketDetailSurfaceMutedColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? accent.withOpacity(0.18)
                : ticketDetailBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eski adi: `_buildSummaryMetricCard`.
class TicketDetailSummaryMetricCard extends StatelessWidget {
  const TicketDetailSummaryMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ticketDetailIsDark(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ticketDetailSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? ticketDetailBorderColor(context)
              : color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: ticketDetailSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ticketDetailPrimaryTextColor(context),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildDetailDisclosure`.
class TicketDetailDisclosure extends StatelessWidget {
  const TicketDetailDisclosure({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ticketDetailSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ticketDetailBorderColor(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ticketDetailPrimaryTextColor(context),
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Eski adi: `_buildContentCard`. (Not: bu widget su an sayfada kullanilmiyor,
/// tasima sirasinda oldugu gibi korundu - davranis degisikligi yapilmadi.)
class TicketDetailContentCard extends StatelessWidget {
  const TicketDetailContentCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.corporateNavy, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.corporateNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildModernContentCard`.
class TicketDetailModernContentCard extends StatelessWidget {
  const TicketDetailModernContentCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ticketDetailIsDark(context);
    return Container(
      decoration: BoxDecoration(
        color: ticketDetailSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ticketDetailBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1A2A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (kurumsal sarı aksan)
          Container(
            decoration: BoxDecoration(
              color: ticketDetailCorporatePanelColor(context),
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(
                      isDark ? 0.16 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.24),
                    ),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ticketDetailPrimaryTextColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'Bolum',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ticketDetailSecondaryTextColor(context),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildInfoRow`.
class TicketDetailInfoRow extends StatelessWidget {
  const TicketDetailInfoRow(
    this.label,
    this.value, {
    super.key,
    this.isBold = false,
    this.isMultiLine = false,
    this.isInline = false,
  });

  final String label;
  final String? value;
  final bool isBold;
  final bool isMultiLine;
  final bool isInline;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: ticketDetailSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value!,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: isBold ? 15 : 14,
            color: ticketDetailPrimaryTextColor(context),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            height: isMultiLine ? 1.5 : 1.2,
          ),
        ),
        if (!isInline) const SizedBox(height: 16),
      ],
    );

    if (isInline) {
      return Container(
        constraints: const BoxConstraints(minWidth: 150),
        child: content,
      );
    }
    return content;
  }
}

/// Eski adi: `_buildTechMetricBox`.
class TicketDetailTechMetricBox extends StatelessWidget {
  const TicketDetailTechMetricBox(this.label, this.value, this.unit, {super.key});

  final String label;
  final dynamic value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valText = value == null ? '-' : value.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ticketDetailBorderColor(context)),
        borderRadius: BorderRadius.circular(8),
        color: ticketDetailSurfaceMutedColor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 10,
              color: ticketDetailSecondaryTextColor(context),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valText == '-'
                      ? ticketDetailSecondaryTextColor(context)
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              if (valText != '-')
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: ticketDetailSecondaryTextColor(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildStatusChip`.
class TicketDetailStatusChip extends StatelessWidget {
  const TicketDetailStatusChip(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(ticketDetailIsDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Eski adi: `_buildDailyReportChip`.
class TicketDetailDailyReportChip extends StatelessWidget {
  const TicketDetailDailyReportChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(ticketDetailIsDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildPriorityBadge`.
class TicketDetailPriorityBadge extends StatelessWidget {
  const TicketDetailPriorityBadge(this.label, this.priorityKey, {super.key});

  final String label;
  final String priorityKey;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priorityKey) {
      case 'high':
        color = AppColors.corporateRed;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = AppColors.corporateYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(ticketDetailIsDark(context) ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski adi: `_buildDailyReportCard`.
class TicketDetailDailyReportCard extends StatelessWidget {
  const TicketDetailDailyReportCard(this.report, {super.key});

  final TicketDailyReport report;

  @override
  Widget build(BuildContext context) {
    return TicketDetailModernContentCard(
      title: report.title,
      icon: Icons.assignment_turned_in_outlined,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TicketDetailDailyReportChip(
              icon: Icons.schedule_outlined,
              label: report.timeRange,
              color: AppColors.corporateBlue,
            ),
            if (report.technicianName.trim().isNotEmpty)
              TicketDetailDailyReportChip(
                icon: Icons.engineering_outlined,
                label: report.technicianName.trim(),
                color: AppColors.corporateNavy,
              ),
            if (report.customerApproval)
              TicketDetailDailyReportChip(
                icon: Icons.verified_outlined,
                label: 'Musteri onayli',
                color: AppColors.statusDone,
              ),
          ],
        ),
        const SizedBox(height: 14),
        TicketDetailInfoRow('Yapilan isler', report.workDone, isMultiLine: true),
        TicketDetailInfoRow(
          'Sorun / bekleme',
          report.issues.isEmpty ? '-' : report.issues,
          isMultiLine: true,
        ),
        TicketDetailInfoRow(
          'Kullanilan malzeme',
          report.usedMaterials.isEmpty ? '-' : report.usedMaterials,
          isMultiLine: true,
        ),
        TicketDetailInfoRow(
          'Sonraki adim',
          report.nextStep.isEmpty ? '-' : report.nextStep,
          isMultiLine: true,
        ),
        if (report.createdByName != null || report.createdAt != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (report.createdByName != null) report.createdByName!,
              if (report.createdAt != null)
                formatTicketDailyReportDate(report.createdAt!),
            ].join(' - '),
            style: TextStyle(
              color: ticketDetailSecondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Eski adi: `_buildDropdown`. (Not: bu widget su an sayfada kullanilmiyor,
/// tasima sirasinda oldugu gibi korundu.) `disabled`, eskiden dogrudan
/// okunan `_isUpdating` alaninin yerini alir.
class TicketDetailDropdown extends StatelessWidget {
  const TicketDetailDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.disabled = false,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeValue = items.containsKey(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: ticketDetailSecondaryTextColor(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: ticketDetailSurfaceColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ticketDetailBorderColor(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              hint: Text(value, style: const TextStyle(fontSize: 12)),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.primary,
              ),
              dropdownColor: ticketDetailSurfaceColor(context),
              style: TextStyle(
                color: ticketDetailPrimaryTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              items: items.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: ticketDetailPrimaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: disabled ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Eski adi: `_buildCompactDropdown`. `updating`, eskiden dogrudan okunan
/// `_isUpdating` alaninin yerini alir; `isDisabled` ise mevcut kilit
/// gostergesi anlamini korur.
class TicketDetailCompactDropdown extends StatelessWidget {
  const TicketDetailCompactDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isDisabled = false,
    this.updating = false,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?>? onChanged;
  final bool isDisabled;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeValue = items.containsKey(value) ? value : null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ticketDetailSecondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: ticketDetailSurfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ticketDetailBorderColor(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                hint: Text(value, style: const TextStyle(fontSize: 12)),
                icon: Icon(
                  isDisabled ? Icons.lock_outline : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                dropdownColor: ticketDetailSurfaceColor(context),
                style: TextStyle(
                  color: ticketDetailPrimaryTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                items: items.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: ticketDetailPrimaryTextColor(context),
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (updating || isDisabled) ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
