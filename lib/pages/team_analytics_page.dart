import 'package:flutter/material.dart';
import '../models/team_analytics.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';

class TeamAnalyticsPage extends StatefulWidget {
  final String teamId;

  const TeamAnalyticsPage({super.key, required this.teamId});

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
    setState(() => _isLoading = true);
    try {
      final data = await _analyticsService.getTeamSnapshot(widget.teamId);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Veriler yüklenemedi: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_data == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genel Bakış',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _buildSummaryCard('Toplam İş', '${_data!.totalCards}', Icons.assignment, Colors.blueGrey),
              _buildSummaryCard('Tamamlanan', '${_data!.doneCount + _data!.sentCount}', Icons.check_circle, Colors.green),
              _buildSummaryCard('Devam Eden', '${_data!.doingCount}', Icons.play_circle_fill, Colors.orange),
              _buildSummaryCard('Bekleyen', '${_data!.todoCount}', Icons.pause_circle_filled, Colors.red),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Verimlilik',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tamamlama Oranı', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '%${(_data!.completionRate * 100).toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _data!.completionRate,
                  backgroundColor: Colors.grey.shade100,
                  color: AppColors.corporateNavy,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
