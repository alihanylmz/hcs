import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/board.dart';

class BoardService {
  final _supabase = Supabase.instance.client;

  /// Takıma ait panoları getirir. Yoksa varsayılan bir tane oluşturur.
  Future<List<Board>> getTeamBoards(String teamId) async {
    final response = await _supabase
        .from('boards')
        .select()
        .eq('team_id', teamId)
        .order('created_at');

    List<Board> boards = (response as List).map((e) => Board.fromJson(e)).toList();

    if (boards.isEmpty) {
      // Otomatik "Genel Pano" oluştur
      final newBoard = await createBoard(teamId, 'Genel Pano');
      boards = [newBoard];
    }

    return boards;
  }

  Future<Board> createBoard(String teamId, String name) async {
    final response = await _supabase
        .from('boards')
        .insert({
          'team_id': teamId,
          'name': name,
        })
        .select()
        .single();
    
    return Board.fromJson(response);
  }
}
