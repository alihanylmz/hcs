import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team_analytics.dart';

class AnalyticsService {
  final _supabase = Supabase.instance.client;

  Future<TeamAnalytics> getTeamSnapshot(String teamId) async {
    // Tüm kartları çekip client side saymak şimdilik en kolayı
    // İleride RPC veya count(*) sorguları ile optimize edilebilir.
    
    final response = await _supabase
        .from('cards')
        .select('status')
        .eq('team_id', teamId);
    
    final cards = response as List;
    final total = cards.length;
    
    int todo = 0;
    int doing = 0;
    int done = 0;
    int sent = 0;
    
    for (var c in cards) {
      final status = c['status'];
      if (status == 'TODO') todo++;
      else if (status == 'DOING') doing++;
      else if (status == 'DONE') done++;
      else if (status == 'SENT') sent++;
    }
    
    final completed = done + sent;
    final rate = total > 0 ? completed / total : 0.0;
    
    return TeamAnalytics(
      totalCards: total,
      todoCount: todo,
      doingCount: doing,
      doneCount: done,
      sentCount: sent,
      completionRate: rate,
    );
  }
}
