import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserService _userService = UserService();
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _userService.getAllUsers();
      // Onay bekleyenleri en üste al
      list.sort((a, b) {
        if (a.role == 'pending' && b.role != 'pending') return -1;
        if (a.role != 'pending' && b.role == 'pending') return 1;
        return (a.fullName ?? '').compareTo(b.fullName ?? '');
      });
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(UserProfile user) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${user.fullName} için Rol Seç'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'admin'), child: const Text('Admin (Tam Yetki)')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'manager'), child: const Text('Yönetici (Stok/Rapor)')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'technician'), child: const Text('Teknisyen (Sınırlı)')),
        ],
      ),
    );

    if (newRole != null && newRole != user.role) {
      setState(() => _isLoading = true);
      try {
        await _userService.updateUserRole(user.id, newRole);
        await _loadUsers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetki güncellendi')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                leading: CircleAvatar(child: Text(user.fullName?.substring(0, 1).toUpperCase() ?? '?')),
                title: Text(user.fullName ?? user.email ?? 'İsimsiz'),
                subtitle: Text(user.email ?? ''),
                trailing: Chip(
                  label: Text(_getRoleLabel(user.role)),
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                ),
                onTap: () => _changeRole(user),
              );
            },
          ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'manager': return 'Yönetici';
      case 'technician': return 'Teknisyen';
      case 'pending': return 'Onay Bekliyor';
      default: return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'technician': return Colors.blue;
      case 'pending': return Colors.amber;
      default: return Colors.grey;
    }
  }
}

