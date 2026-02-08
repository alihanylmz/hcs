import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/team.dart';
import '../models/team_member.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';

class TeamMembersPage extends StatefulWidget {
  final String teamId;
  final bool canManage; // Yönetici yetkisi var mı?

  const TeamMembersPage({
    super.key, 
    required this.teamId, 
    this.canManage = false
  });

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  final TeamService _teamService = TeamService();
  
  bool _isLoading = true;
  List<TeamMember> _members = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _teamService.getTeamMembers(widget.teamId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Üyeler yüklenemedi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üye Davet Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Eklemek istediğiniz kişinin e-posta adresini girin:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(ctx);
                _inviteUser(email);
              }
            },
            child: const Text('Davet Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUser(String email) async {
    try {
      await _teamService.addMemberByEmail(widget.teamId, email);
      _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı eklendi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('${member.displayName} adlı kullanıcıyı takımdan çıkarmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Çıkar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _teamService.removeMember(widget.teamId, member.userId);
        _loadMembers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.canManage 
          ? FloatingActionButton(
              onPressed: _showInviteDialog,
              backgroundColor: AppColors.corporateNavy,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final member = _members[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.corporateNavy.withOpacity(0.1),
                child: Text(
                  member.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.corporateNavy, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Katıldı: ${DateFormat('dd MMM yyyy').format(member.joinedAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(member.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getRoleColor(member.role).withOpacity(0.3)),
                    ),
                    child: Text(
                      member.role.label,
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(member.role),
                      ),
                    ),
                  ),
                  if (widget.canManage && member.role != TeamRole.owner) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeMember(member),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner: return Colors.orange;
      case TeamRole.admin: return Colors.blue;
      case TeamRole.member: return Colors.green;
    }
  }
}
