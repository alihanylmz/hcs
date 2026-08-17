import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/permission_service.dart';
import '../services/personnel_pdf_service.dart';
import '../services/stock_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import 'pdf_viewer_page.dart';
import 'ticket_detail_page.dart';

class PersonnelDetailPage extends StatefulWidget {
  final String personnelId;
  final UserProfile? initialProfile;

  const PersonnelDetailPage({
    super.key,
    required this.personnelId,
    this.initialProfile,
  });

  @override
  State<PersonnelDetailPage> createState() => _PersonnelDetailPageState();
}

class _PersonnelDetailPageState extends State<PersonnelDetailPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final StockService _stockService = StockService();
  final UserService _userService = UserService();

  UserProfile? _profile;
  UserProfile? _currentActorProfile;
  bool _isLoading = true;
  int _activeTab = 0;
  late TabController _tabController;

  List<Map<String, dynamic>> _activeLoans = [];
  List<Map<String, dynamic>> _pastLoans = [];
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _allStocks = [];
  List<Map<String, dynamic>> _activeTicketsList = [];

  bool get _canManageStock =>
      _currentActorProfile != null &&
      PermissionService.hasPermission(
        _currentActorProfile!,
        AppPermission.manageStock,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _activeTab = _tabController.index);
    });
    _profile = widget.initialProfile;
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final actor = await _userService.getCurrentUserProfile();
      _currentActorProfile = actor;

      // 1. Profil bilgisi
      if (_profile == null) {
        final profRes =
            await _supabase
                .from('profiles')
                .select()
                .eq('id', widget.personnelId)
                .maybeSingle();
        if (profRes != null) {
          _profile = UserProfile.fromJson(profRes);
        }
      }

      // 2. Zimmetler (Açık ve Geçmiş)
      final allLoans = await _stockService.getPersonnelLoans(
        widget.personnelId,
        onlyOpen: false,
      );
      _activeLoans =
          allLoans
              .where(
                (l) =>
                    l['status'] == 'borrowed' &&
                    ((l['quantity'] as num?) ?? 0) > 0,
              )
              .toList();
      _pastLoans =
          allLoans
              .where(
                (l) =>
                    l['status'] != 'borrowed' ||
                    ((l['quantity'] as num?) ?? 0) <= 0,
              )
              .toList();

      // 3. İş Emirleri
      final ticketRes = await _supabase
          .from('tickets')
          .select(
            'id, job_code, title, status, planned_date, created_at, customers(name)',
          )
          .or(
            'assigned_to.eq.${widget.personnelId},creator_id.eq.${widget.personnelId}',
          )
          .order('created_at', ascending: false)
          .limit(50);
      _tickets = List<Map<String, dynamic>>.from(ticketRes);

      // 4. Yönetici Notları
      _notes = await _stockService.getPersonnelNotes(widget.personnelId);

      // 5. İlişkili Hareket Logları
      final pName = _profile?.displayName ?? _profile?.email ?? '';
      _movements = await _stockService.getPersonnelStockMovements(
        widget.personnelId,
        personnelName: pName,
      );

      // 6. Stok Listesi ve Aktif İşler (Zimmet diyalogları için)
      _allStocks = await _stockService.getStocks(onlyTracked: true);
      _activeTicketsList = await _stockService.getActiveTicketsList();
    } catch (e) {
      debugPrint('Personel detay yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPdfStatement() {
    if (_profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PdfViewerPage(
              title: 'Personel Ekstresi: ${_profile!.displayName}',
              pdfFileName:
                  'personel_ekstre_${_profile!.displayName.replaceAll(' ', '_')}.pdf',
              pdfGenerator:
                  () => PersonnelPdfService.generatePersonnelStatementPdf(
                    personnel: _profile!,
                    activeLoans: _activeLoans,
                    pastLoans: _pastLoans,
                    tickets: _tickets,
                    notes: _notes,
                  ),
            ),
      ),
    );
  }

  // --- ZİMMET VERME MODALI (SERİ NUMARALI / ÇOKLU SATIR) ---
  void _showGiveLoanModal() {
    if (!_canManageStock || _profile == null) return;

    Map<String, dynamic>? selectedStock;
    String? selectedJobCode;
    final qtyCtrl = TextEditingController(text: '1');
    final serialsCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
              final lines =
                  serialsCtrl.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_profile!.displayName} - Yeni Cihaz Zimmetle',
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Container(
                    width: 480,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedStock,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ürün / Cihaz Seçin *',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _allStocks.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    '${s['displayName'] ?? s['name']} (Stok: ${s['quantity']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedStock = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedJobCode,
                          decoration: const InputDecoration(
                            labelText: 'İş Kodu (İş Emri Bağlantısı)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Seçilmedi (Genel Zimmet)'),
                            ),
                            ..._activeTicketsList.map((t) {
                              final code = t['job_code'] ?? t['id'];
                              final cust =
                                  t['customers'] is Map
                                      ? (t['customers']['name'] ?? '')
                                      : '';
                              return DropdownMenuItem<String>(
                                value: code.toString(),
                                child: Text(
                                  '$code - $cust (${t['title'] ?? ''})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged:
                              (val) =>
                                  setModalState(() => selectedJobCode = val),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Adet *',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  setModalState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                qty > 1
                                    ? '$qty ayrı satır/seri no oluşacak'
                                    : '1 tekil cihaz kaydı',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5A6E82),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: serialsCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Seri Numaraları (Çıkışta Şart) *',
                            hintText:
                                qty > 1
                                    ? 'Her satıra bir seri no yazın veya barkod okutun:\nSN-001\nSN-002\nSN-003'
                                    : 'Cihaz seri numarasını girin veya okutun',
                            helperText:
                                '${lines.length} adet seri no girildi (Hedef: $qty)',
                            helperStyle: TextStyle(
                              color:
                                  lines.length == qty
                                      ? AppColors.mint
                                      : AppColors.brass,
                              fontWeight: FontWeight.bold,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        if (selectedStock != null &&
                            (selectedStock!['serial_numbers'] as List? ?? [])
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Depodaki Kayıtlı Seri No\'lardan Hızlıca Seç:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children:
                                (selectedStock!['serial_numbers'] as List).map((
                                  snObj,
                                ) {
                                  final sn = snObj.toString().trim();
                                  final isAlreadyAdded = lines.contains(sn);
                                  return ActionChip(
                                    avatar: Icon(
                                      isAlreadyAdded
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      size: 14,
                                      color:
                                          isAlreadyAdded
                                              ? AppColors.mint
                                              : AppColors.ink,
                                    ),
                                    label: Text(
                                      sn,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            isAlreadyAdded
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    backgroundColor:
                                        isAlreadyAdded
                                            ? AppColors.mint.withValues(
                                              alpha: 0.15,
                                            )
                                            : AppColors.sand,
                                    onPressed: () {
                                      setModalState(() {
                                        if (isAlreadyAdded) {
                                          final newLines =
                                              lines
                                                  .where((s) => s != sn)
                                                  .toList();
                                          serialsCtrl.text = newLines.join(
                                            '\n',
                                          );
                                        } else {
                                          final newLines = List<String>.from(
                                            lines,
                                          )..add(sn);
                                          serialsCtrl.text = newLines.join(
                                            '\n',
                                          );
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),

                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Açıklama / Not',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İptal'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (selectedStock == null) return;
                      final rawSerials =
                          serialsCtrl.text
                              .split(RegExp(r'[\n,]'))
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                      if (rawSerials.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Lütfen en az 1 adet seri numarası giriniz.',
                            ),
                            backgroundColor: AppColors.corporateRed,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      try {
                        await _stockService.registerBatchSerialLoans(
                          productId: selectedStock!['id'].toString(),
                          personnelId: widget.personnelId,
                          serialNumbers: rawSerials,
                          jobCode: selectedJobCode,
                          note: noteCtrl.text.trim(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${rawSerials.length} adet cihaz başarıyla zimmetlendi.',
                            ),
                            backgroundColor: AppColors.mint,
                          ),
                        );
                        _loadAllData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Zimmet hatası: $e'),
                            backgroundColor: AppColors.corporateRed,
                          ),
                        );
                      }
                    },
                    child: const Text('Zimmetle'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- CHECKLIST DÖNÜŞ & İADE MODALI ---
  void _showChecklistResolutionModal() {
    if (!_canManageStock || _activeLoans.isEmpty || _profile == null) return;

    // 3 Durumlu Aksiyon Haritası: Her cihaz 'returned' (Sağlam İade), 'consumed' (Sarf) veya 'defective' (Arızalı) olabilir.
    final Map<int, String> loanActions = {
      for (var l in _activeLoans) (l['id'] as int): 'returned',
    };
    String? selectedJobCode;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final returnedCount =
                  _activeLoans
                      .where((l) => loanActions[l['id'] as int] == 'returned')
                      .length;
              final consumedCount =
                  _activeLoans
                      .where((l) => loanActions[l['id'] as int] == 'consumed')
                      .length;
              final defectiveCount =
                  _activeLoans
                      .where((l) => loanActions[l['id'] as int] == 'defective')
                      .length;

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.fact_check, color: AppColors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_profile!.displayName} - Sahadan Dönüş / Zimmet Kapatma',
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Container(
                    width: 650,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Her bir cihaz için sahadan dönüş durumunu belirleyiniz (Sağlam İade, Sarf Edildi veya Arızalı).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A6E82),
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedJobCode,
                          decoration: const InputDecoration(
                            labelText: 'Kullanılan İş Kodu (İş Emri / Proje)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Seçilmedi (Genel Dönüş)'),
                            ),
                            ..._activeTicketsList.map((t) {
                              final code = t['job_code'] ?? t['id'];
                              final cust =
                                  t['customers'] is Map
                                      ? (t['customers']['name'] ?? '')
                                      : '';
                              return DropdownMenuItem<String>(
                                value: code.toString(),
                                child: Text(
                                  '$code - $cust (${t['title'] ?? ''})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged:
                              (val) =>
                                  setModalState(() => selectedJobCode = val),
                        ),
                        const SizedBox(height: 14),

                        // CİHAZ LİSTESİ CHECKLIST
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.mist),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _activeLoans.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final loan = _activeLoans[idx];
                              final loanId = loan['id'] as int;
                              final product = loan['inventory'] ?? {};
                              final name =
                                  product['displayName'] ??
                                  product['name'] ??
                                  'Cihaz';
                              final sn = loan['serial_number'] ?? 'Seri No Yok';
                              final currentAction =
                                  loanActions[loanId] ?? 'returned';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                color:
                                    currentAction == 'consumed'
                                        ? const Color(
                                          0xFF2563EB,
                                        ).withValues(alpha: 0.05)
                                        : currentAction == 'defective'
                                        ? AppColors.corporateRed.withValues(
                                          alpha: 0.05,
                                        )
                                        : AppColors.mint.withValues(
                                          alpha: 0.05,
                                        ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Seri No: $sn | Veriliş: ${_formatDate(loan['borrowed_at'])} ${loan['job_code'] != null ? '(${loan['job_code']})' : ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF5A6E82),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        ChoiceChip(
                                          avatar: Icon(
                                            Icons.keyboard_return,
                                            size: 13,
                                            color:
                                                currentAction == 'returned'
                                                    ? Colors.white
                                                    : AppColors.mint,
                                          ),
                                          label: const Text('Sağlam İade'),
                                          selected: currentAction == 'returned',
                                          selectedColor: AppColors.mint,
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                currentAction == 'returned'
                                                    ? Colors.white
                                                    : AppColors.ink,
                                          ),
                                          onSelected: (_) {
                                            setModalState(() {
                                              loanActions[loanId] = 'returned';
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          avatar: Icon(
                                            Icons.check_circle_outline,
                                            size: 13,
                                            color:
                                                currentAction == 'consumed'
                                                    ? Colors.white
                                                    : const Color(0xFF2563EB),
                                          ),
                                          label: const Text('Sarf Edildi'),
                                          selected: currentAction == 'consumed',
                                          selectedColor: const Color(
                                            0xFF2563EB,
                                          ),
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                currentAction == 'consumed'
                                                    ? Colors.white
                                                    : AppColors.ink,
                                          ),
                                          onSelected: (_) {
                                            setModalState(() {
                                              loanActions[loanId] = 'consumed';
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          avatar: Icon(
                                            Icons.build_circle_outlined,
                                            size: 13,
                                            color:
                                                currentAction == 'defective'
                                                    ? Colors.white
                                                    : AppColors.corporateRed,
                                          ),
                                          label: const Text('Arızalı'),
                                          selected:
                                              currentAction == 'defective',
                                          selectedColor: AppColors.corporateRed,
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                currentAction == 'defective'
                                                    ? Colors.white
                                                    : AppColors.ink,
                                          ),
                                          onSelected: (_) {
                                            setModalState(() {
                                              loanActions[loanId] = 'defective';
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ÖZET BİLGİ
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.mist),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                '🟢 Sağlam İade: $returnedCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mint,
                                ),
                              ),
                              Text(
                                '🔵 Sarf: $consumedCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              Text(
                                '🔴 Arızalı: $defectiveCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.corporateRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dönüş Açıklaması / Not',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İptal'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final consumedIds =
                          _activeLoans
                              .map((l) => l['id'] as int)
                              .where((id) => loanActions[id] == 'consumed')
                              .toList();
                      final returnedIds =
                          _activeLoans
                              .map((l) => l['id'] as int)
                              .where((id) => loanActions[id] == 'returned')
                              .toList();
                      final defectiveIds =
                          _activeLoans
                              .map((l) => l['id'] as int)
                              .where((id) => loanActions[id] == 'defective')
                              .toList();

                      Navigator.pop(ctx);
                      try {
                        await _stockService.processLoanChecklistResolution(
                          consumedLoanIds: consumedIds,
                          returnedLoanIds: returnedIds,
                          defectiveLoanIds: defectiveIds,
                          personnelName: _profile!.displayName,
                          jobCode: selectedJobCode,
                          note: noteCtrl.text.trim(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Zimmet dönüşü işlendi (${returnedIds.length} Sağlam İade / ${consumedIds.length} Sarf / ${defectiveIds.length} Arızalı).',
                            ),
                            backgroundColor: AppColors.mint,
                          ),
                        );
                        _loadAllData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Dönüş hatası: $e'),
                            backgroundColor: AppColors.corporateRed,
                          ),
                        );
                      }
                    },
                    child: const Text('Checklist İle Kapat & İade Al'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- YÖNETİCİ NOTU EKLEME MODALI ---
  void _showAddNoteModal() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('${_profile?.displayName ?? 'Personel'} - Not Ekle'),
            content: TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Personel ile ilgili iş, performans, zimmet veya takip notu yazınız...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (noteCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await _stockService.addPersonnelNote(
                      personnelId: widget.personnelId,
                      note: noteCtrl.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Not kaydedildi.'),
                        backgroundColor: AppColors.mint,
                      ),
                    );
                    _loadAllData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Not ekleme hatası: $e'),
                        backgroundColor: AppColors.corporateRed,
                      ),
                    );
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'Personel Kartı'),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF Ekstre Yazdır',
            onPressed: _openPdfStatement,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadAllData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadAllData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPersonnelHeaderCard(),
                      const SizedBox(height: 16),
                      _buildTabBar(),
                      const SizedBox(height: 12),
                      _buildActiveTabContent(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildPersonnelHeaderCard() {
    final p = _profile;
    final name = p?.displayName ?? 'İsimsiz Personel';
    final email = p?.email ?? '-';
    final roleStr = PersonnelPdfService.formatRole(p?.role);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.ink,
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            roleStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: AppColors.brass,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '✉️ $email   |   ID: ${p?.id ?? '-'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A6E82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // İSTATİSTİK KARTLARI
          Row(
            children: [
              _buildStatMetric(
                'Aktif Zimmet',
                '${_activeLoans.length} Cihaz',
                AppColors.brass,
                Icons.inventory_2,
              ),
              const SizedBox(width: 12),
              _buildStatMetric(
                'Geçmiş Sarfiyat',
                '${_pastLoans.where((l) => l['status'] == 'consumed').length} Adet',
                const Color(0xFF2563EB),
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 12),
              _buildStatMetric(
                'Depoya İade',
                '${_pastLoans.where((l) => l['status'] == 'returned').length} Adet',
                AppColors.mint,
                Icons.keyboard_return,
              ),
              const SizedBox(width: 12),
              _buildStatMetric(
                'İş Emirleri',
                '${_tickets.length} Görev',
                AppColors.corporateRed,
                Icons.assignment,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // HIZLI AKSİYON BUTONLARI
          if (_canManageStock)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Yeni Zimmet Ver (Seri No ile)'),
                  onPressed: _showGiveLoanModal,
                ),
                if (_activeLoans.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brass,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.fact_check, size: 16),
                    label: const Text('Checklist İle Dönüş / İade Al'),
                    onPressed: _showChecklistResolutionModal,
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.note_add, size: 16),
                  label: const Text('Yönetici Notu Ekle'),
                  onPressed: _showAddNoteModal,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('PDF Ekstre'),
                  onPressed: _openPdfStatement,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.mist),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.ink,
        indicatorColor: AppColors.brass,
        indicatorWeight: 3,
        unselectedLabelColor: const Color(0xFF5A6E82),
        tabs: [
          Tab(
            text: 'Aktif Zimmetler (${_activeLoans.length})',
            icon: const Icon(Icons.devices, size: 18),
          ),
          Tab(
            text: 'Zimmet Geçmişi (${_pastLoans.length})',
            icon: const Icon(Icons.history, size: 18),
          ),
          Tab(
            text: 'İş Emirleri (${_tickets.length})',
            icon: const Icon(Icons.assignment, size: 18),
          ),
          Tab(
            text: 'Notlar (${_notes.length})',
            icon: const Icon(Icons.notes, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildActiveLoansTab();
      case 1:
        return _buildPastLoansTab();
      case 2:
        return _buildTicketsTab();
      case 3:
        return _buildNotesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 1: AKTİF ZİMMETLER ---
  Widget _buildActiveLoansTab() {
    if (_activeLoans.isEmpty) {
      return _buildEmptyState(
        'Personelin üzerinde aktif zimmetli cihaz veya parça bulunmuyor.',
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _activeLoans.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final loan = _activeLoans[idx];
          final product = loan['inventory'] ?? {};
          final name = product['displayName'] ?? product['name'] ?? '-';
          final sn = loan['serial_number'] ?? '-';
          final jobCode = loan['job_code'];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.brass.withOpacity(0.15),
              child: const Icon(Icons.devices, color: AppColors.brass),
            ),
            title: Text(
              '$name',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Seri No: $sn   |   Veriliş Tarihi: ${_formatDate(loan['borrowed_at'])} ${jobCode != null ? '\nİş Kodu: $jobCode' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing:
                _canManageStock
                    ? OutlinedButton(
                      onPressed: _showChecklistResolutionModal,
                      child: const Text('İşle / İade Al'),
                    )
                    : null,
          );
        },
      ),
    );
  }

  // --- TAB 2: GEÇMİŞ ZİMMETLER ---
  Widget _buildPastLoansTab() {
    if (_pastLoans.isEmpty) {
      return _buildEmptyState('Geçmiş zimmet kaydı bulunmuyor.');
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _pastLoans.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final loan = _pastLoans[idx];
          final product = loan['inventory'] ?? {};
          final name = product['displayName'] ?? product['name'] ?? '-';
          final sn = loan['serial_number'] ?? '-';
          final status = loan['status']?.toString();
          final isConsumed = status == 'consumed';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isConsumed
                      ? const Color(0xFF2563EB).withOpacity(0.15)
                      : AppColors.mint.withOpacity(0.15),
              child: Icon(
                isConsumed ? Icons.check_circle_outline : Icons.keyboard_return,
                color: isConsumed ? const Color(0xFF2563EB) : AppColors.mint,
              ),
            ),
            title: Text(
              '$name',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Seri No: $sn   |   Veriliş: ${_formatDate(loan['borrowed_at'])}   |   Kapatılış: ${_formatDate(loan['closed_at'])}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Chip(
              label: Text(
                isConsumed ? 'Sarf Edildi' : 'Stoğa İade',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor:
                  isConsumed ? const Color(0xFF2563EB) : AppColors.mint,
            ),
          );
        },
      ),
    );
  }

  // --- TAB 3: İŞ EMİRLERİ ---
  Widget _buildTicketsTab() {
    if (_tickets.isEmpty) {
      return _buildEmptyState('Personele atanmış iş emri bulunmuyor.');
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final t = _tickets[idx];
          final customer = t['customers'];
          final custName = customer is Map ? (customer['name'] ?? '-') : '-';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.ink.withOpacity(0.1),
              child: const Icon(Icons.assignment, color: AppColors.ink),
            ),
            title: Text(
              '${t['job_code'] ?? '-'} - ${t['title'] ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Müşteri: $custName   |   Tarih: ${_formatDate(t['planned_date'] ?? t['created_at'])}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, color: AppColors.brass),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => TicketDetailPage(ticketId: t['id'].toString()),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // --- TAB 4: YÖNETİCİ NOTLARI ---
  Widget _buildNotesTab() {
    return Column(
      children: [
        if (_canManageStock)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Not Yaz'),
                onPressed: _showAddNoteModal,
              ),
            ),
          ),
        if (_notes.isEmpty)
          _buildEmptyState('Kayıtlı personel notu bulunmuyor.')
        else
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final n = _notes[idx];
                final creator =
                    n['profiles'] is Map
                        ? (n['profiles']['full_name'] ??
                            n['profiles']['email'] ??
                            'Yönetici')
                        : 'Yönetici';

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brass,
                    child: Icon(
                      Icons.sticky_note_2,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    n['note'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Yazan: $creator   |   Tarih: ${_formatDate(n['created_at'])}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing:
                      _canManageStock
                          ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.corporateRed,
                            ),
                            onPressed: () async {
                              await _stockService.deletePersonnelNote(
                                n['id'] as int,
                              );
                              _loadAllData();
                            },
                          )
                          : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF5A6E82), fontSize: 13),
        ),
      ),
    );
  }

  String _formatDate(dynamic dt) {
    if (dt == null) return '-';
    try {
      final parsed = DateTime.parse(dt.toString()).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(parsed);
    } catch (_) {
      return dt.toString();
    }
  }
}
