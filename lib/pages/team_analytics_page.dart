import 'package:flutter/material.dart';

import '../models/team_analytics.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';

class TeamAnalyticsPage extends StatefulWidget {
  const TeamAnalyticsPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamAnalyticsPage> createState() => _TeamAnalyticsPageState();
}

class _TeamAnalyticsPageState extends State<TeamAnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _isLoading = true;
  TeamAnalytics? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _analyticsService.getTeamSnapshot(widget.teamId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Veriler yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final completionRate = (data.completionRate * 100).clamp(0, 100).toDouble();
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(theme, data, completionRate),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMetricsGrid(theme, data)),
                const SizedBox(width: 18),
                SizedBox(
                  width: 320,
                  child: _buildDistributionCard(theme, data),
                ),
              ],
            )
          else ...[
            _buildMetricsGrid(theme, data),
            const SizedBox(height: 18),
            _buildDistributionCard(theme, data),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    ThemeData theme,
    TeamAnalytics data,
    double completionRate,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Takim Analizi',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kart akisi, tamamlama ritmi ve mevcut yuk dagilimini buradan izle.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.68),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildTopMetric(
                  theme,
                  title: 'Toplam Kart',
                  value: '${data.totalCards}',
                  color: AppColors.corporateBlue,
                  icon: Icons.layers_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTopMetric(
                  theme,
                  title: 'Tamamlama',
                  value: '%${completionRate.toStringAsFixed(0)}',
                  color: AppColors.statusDone,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Tamamlama Orani',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completionRate / 100,
              minHeight: 12,
              backgroundColor:
                  theme.brightness == Brightness.dark
                      ? AppColors.surfaceDarkMuted
                      : AppColors.surfaceMuted,
              color: AppColors.corporateBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetric(
    ThemeData theme, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(title, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, TeamAnalytics data) {
    final metrics = [
      _MetricData(
        title: 'Yapilacak',
        value: '${data.todoCount}',
        icon: Icons.radio_button_unchecked_rounded,
        color: const Color(0xFF64748B),
      ),
      _MetricData(
        title: 'Devam Eden',
        value: '${data.doingCount}',
        icon: Icons.play_circle_outline_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _MetricData(
        title: 'Tamamlanan',
        value: '${data.doneCount}',
        icon: Icons.task_alt_outlined,
        color: AppColors.statusDone,
      ),
      _MetricData(
        title: 'Gonderilen',
        value: '${data.sentCount}',
        icon: Icons.send_outlined,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.title, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDistributionCard(ThemeData theme, TeamAnalytics data) {
    final items = [
      _DistributionData(
        label: 'Yapilacak',
        count: data.todoCount,
        color: const Color(0xFF64748B),
      ),
      _DistributionData(
        label: 'Devam Eden',
        count: data.doingCount,
        color: const Color(0xFFF59E0B),
      ),
      _DistributionData(
        label: 'Tamamlanan',
        count: data.doneCount,
        color: AppColors.statusDone,
      ),
      _DistributionData(
        label: 'Gonderilen',
        count: data.sentCount,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Durum Dagilimi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toplam $total kart uzerinden anlik dagilim.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.68),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDistributionRow(theme, item, total),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(
    ThemeData theme,
    _DistributionData item,
    int total,
  ) {
    final ratio = total == 0 ? 0.0 : item.count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '${item.count}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor:
                theme.brightness == Brightness.dark
                    ? AppColors.surfaceDarkMuted
                    : AppColors.surfaceMuted,
            color: item.color,
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _DistributionData {
  const _DistributionData({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}
