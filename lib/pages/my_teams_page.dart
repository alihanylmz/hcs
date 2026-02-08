import 'package:flutter/material.dart';

import '../models/team.dart';
import '../models/user_profile.dart';
import '../services/team_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import 'team_home_page.dart';

class MyTeamsPage extends StatefulWidget {
  const MyTeamsPage({super.key});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  final TeamService _teamService = TeamService();
  final UserService _userService = UserService();

  List<Team> _teams = [];
  bool _isLoading = false;
  String? _error;
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profile = await _userService.getCurrentUserProfile();
    final teams = await _teamService.listTeams();

    if (!mounted) return;
    setState(() {
      _currentUser = profile;
      _teams = teams;
      _isLoading = false;
    });
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Takım'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Takım Adı'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateNavy),
            child: const Text('Oluştur', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final team = await _teamService.createTeam(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TeamHomePage(teamId: team.id)),
      );

      _loadAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Takım oluşturulamadı: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.myTeams,
      title: 'Takımlarım',
      userName: _currentUser?.displayName,
      userRole: _currentUser?.role,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.corporateNavy,
        onPressed: _showCreateTeamDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 12),
              const Text(
                'Henüz bir takımın yok.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni bir takım oluşturup kanban planlamaya başlayabilirsin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCreateTeamDialog,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateNavy),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Takım Oluştur', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _teams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final team = _teams[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: team.description == null || team.description!.trim().isEmpty
                  ? const Text('Açıklama yok')
                  : Text(team.description!),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TeamHomePage(teamId: team.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
