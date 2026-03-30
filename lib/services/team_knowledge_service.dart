import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/team_knowledge_block.dart';
import '../models/team_knowledge_page.dart';

class TeamKnowledgeService {
  TeamKnowledgeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('TeamKnowledgeService');
  final SupabaseClient _client;

  Exception _mapKnowledgeError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      final mentionsKnowledgeTables =
          message.contains('team_pages') ||
          message.contains('team_page_blocks');
      final looksLikeSchemaIssue =
          message.contains('does not exist') ||
          message.contains('relation') ||
          message.contains('schema cache');

      if (mentionsKnowledgeTables && looksLikeSchemaIssue) {
        return Exception(
          'Bilgi Merkezi tablolari Supabase tarafinda hazir degil. '
          'migration_team_knowledge.sql veya migration_team_workspace_all_in_one.sql calistirilmali.',
        );
      }

      return Exception(error.message);
    }

    if (error is Exception) {
      return error;
    }

    return Exception(error.toString());
  }

  Future<List<TeamKnowledgePage>> listPages(String teamId) async {
    try {
      final response = await _client
          .from('team_pages')
          .select()
          .eq('team_id', teamId)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((row) => TeamKnowledgePage.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      _logger.error(
        'list_pages_failed',
        data: {'teamId': teamId},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }

  Future<TeamKnowledgePage> createPage({
    required String teamId,
    required String title,
    String summary = '',
    String icon = 'DOC',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Oturum gerekli');
    }

    try {
      final response =
          await _client
              .from('team_pages')
              .insert({
                'team_id': teamId,
                'title': title,
                'summary': summary,
                'icon': icon,
                'created_by': userId,
              })
              .select()
              .single();

      return TeamKnowledgePage.fromJson(response);
    } catch (error, stackTrace) {
      _logger.error(
        'create_page_failed',
        data: {'teamId': teamId, 'title': title},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }

  Future<void> updatePage({
    required String pageId,
    required String title,
    required String summary,
    required String icon,
  }) async {
    try {
      await _client
          .from('team_pages')
          .update({
            'title': title,
            'summary': summary,
            'icon': icon,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pageId);
    } catch (error, stackTrace) {
      _logger.error(
        'update_page_failed',
        data: {'pageId': pageId},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }

  Future<void> deletePage(String pageId) async {
    try {
      await _client.from('team_pages').delete().eq('id', pageId);
    } catch (error, stackTrace) {
      _logger.error(
        'delete_page_failed',
        data: {'pageId': pageId},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }

  Future<List<TeamKnowledgeBlock>> getBlocks(String pageId) async {
    try {
      final response = await _client
          .from('team_page_blocks')
          .select()
          .eq('page_id', pageId)
          .order('sort_order', ascending: true);

      return (response as List)
          .map(
            (row) => TeamKnowledgeBlock.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } catch (error, stackTrace) {
      _logger.error(
        'get_blocks_failed',
        data: {'pageId': pageId},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }

  Future<void> replaceBlocks(
    String pageId,
    List<TeamKnowledgeBlock> blocks,
  ) async {
    try {
      await _client.from('team_page_blocks').delete().eq('page_id', pageId);

      if (blocks.isEmpty) {
        return;
      }

      final payload =
          blocks
              .asMap()
              .entries
              .map((entry) => entry.value.toInsertJson(pageId, entry.key))
              .toList();

      await _client.from('team_page_blocks').insert(payload);
    } catch (error, stackTrace) {
      _logger.error(
        'replace_blocks_failed',
        data: {'pageId': pageId, 'count': blocks.length},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapKnowledgeError(error);
    }
  }
}
