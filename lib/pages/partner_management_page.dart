import 'package:flutter/material.dart';
import '../services/partner_service.dart';
import '../models/partner.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart';

class PartnerManagementPage extends StatefulWidget {
  const PartnerManagementPage({super.key});

  @override
  State<PartnerManagementPage> createState() => _PartnerManagementPageState();
}

class _PartnerManagementPageState extends State<PartnerManagementPage> {
  final PartnerService _partnerService = PartnerService();
  List<Partner> _partners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    setState(() => _isLoading = true);
    try {
      final list = await _partnerService.getAllPartners();
      if (mounted) {
        setState(() {
          _partners = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({Partner? partner}) async {
    final nameController = TextEditingController(text: partner?.name);
    final contactController = TextEditingController(text: partner?.contactInfo);
    final isEdit = partner != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Partner Düzenle' : 'Yeni Partner Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Firma Adı', hintText: 'Örn: Vensa Teknoloji'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: 'İletişim Bilgisi', hintText: 'Email veya Telefon'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              try {
                if (isEdit) {
                  await _partnerService.updatePartner(partner.id, {
                    'name': nameController.text.trim(),
                    'contact_info': contactController.text.trim(),
                  });
                } else {
                  await _partnerService.addPartner(
                    nameController.text.trim(),
                    contactInfo: contactController.text.trim(),
                  );
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadPartners();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kaydedildi'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePartner(Partner partner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: Text('${partner.name} firmasını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sil', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _partnerService.deletePartner(partner.id);
        _loadPartners();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: Silinemedi. İlişkili kayıtlar olabilir. $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const CustomHeader(
            title: 'Partner Firmalar',
            subtitle: 'İş ortaklarını yönetin',
            showBackArrow: true,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy))
                : _partners.isEmpty
                    ? const Center(child: Text('Henüz partner firma eklenmemiş.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _partners.length,
                        itemBuilder: (context, index) {
                          final partner = _partners[index];
                          return Card(
                            color: cardColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.corporateNavy.withOpacity(0.1),
                                child: Text(
                                  partner.name[0].toUpperCase(),
                                  style: const TextStyle(color: AppColors.corporateNavy, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(partner.contactInfo ?? 'İletişim bilgisi yok'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showAddEditDialog(partner: partner),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deletePartner(partner),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.corporateNavy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni Partner', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

