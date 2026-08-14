import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/stock_service.dart';
import '../services/partner_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../models/partner.dart';
import '../models/ticket_part.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class EditTicketPage extends StatefulWidget {
  final String ticketId;

  const EditTicketPage({super.key, required this.ticketId});

  @override
  State<EditTicketPage> createState() => _EditTicketPageState();
}

class _EditTicketPageState extends State<EditTicketPage> {
  // --- SABİTLER VE AYARLAR ---
  static const Color _corporateNavy = AppColors.corporateNavy;
  static const Color _backgroundGrey = AppColors.backgroundGrey;
  static const Color _surfaceWhite = AppColors.surfaceWhite;
  static const Color _textDark = AppColors.textDark;
  static const Color _textLight = AppColors.textLight;

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobCodeController = TextEditingController();
  final _projectLocationController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _kompresor1KwController = TextEditingController();
  final _kompresor2KwController = TextEditingController();
  final _heaterKwController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Jet Fan Controller'ları
  final _jetFanCountController = TextEditingController();
  final _inverterBrandController = TextEditingController();
  int _selectedZoneCount = 0;
  final List<TextEditingController> _zoneFanCountControllers = [];
  int _smokeFanCount = 0;
  List<Map<String, dynamic>> _smokeFans = [];
  int _freshFanCount = 0;
  List<Map<String, dynamic>> _freshFans = [];

  // Proje Alanları
  String _jobType = 'service';
  String _projectType = 'BMS';
  String _projectStatus = 'planned';
  String? _responsibleUserId;
  final Set<String> _assignedUserIds = {};
  DateTime? _projectStartDate;
  DateTime? _projectDueDate;

  // Santral & Teknik Alanlar
  String? _selectedDeviceModel;
  String? _selectedPlcModel;
  String? _selectedHmiBrand;
  double? _selectedHmiSize;

  String? _selectedAspiratorBrand;
  String? _selectedAspiratorModel;
  double? _selectedAspiratorKw;
  List<String> _availableAspiratorModels = [];

  String? _selectedVantBrand;
  String? _selectedVantModel;
  double? _selectedVantKw;
  List<String> _availableVantModels = [];

  final StockService _stockService = StockService();
  List<String> _availableDriveBrands = [];

  // Partner & Kullanıcılar
  final PartnerService _partnerService = PartnerService();
  List<Partner> _partners = [];
  List<UserProfile> _users = [];
  int? _selectedPartnerId;
  bool _canAssignPartner = false;
  bool _canManageDraftTickets = false;

  String _selectedTandem = 'yok';
  String _heaterExists = 'Yok';
  String _selectedIsiticiKademe = 'yok';

  bool _dx = false;
  bool _suluBatarya = false;
  bool _karisimDamper = false;
  bool _nemlendirici = false;
  bool _rotor = false;
  bool _brulor = false;

  DateTime? _plannedDate;
  PlatformFile? _selectedPdf;
  String _status = 'open';
  String _priority = 'normal';
  String? _customerId;

  bool _isSaving = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;

  // Stok Parça Yönetimi
  List<TicketPart> _usedParts = [];
  bool _isLoadingParts = false;
  List<Map<String, dynamic>> _allInventory = [];

  dynamic get _ticketIdQueryValue {
    final parsed = int.tryParse(widget.ticketId);
    return parsed ?? widget.ticketId;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadDriveBrands(),
      _loadUserRole(),
      _loadUsers(),
      _loadPartners(),
      _loadUsedParts(),
      _loadInventory(),
    ]);
    await _loadTicket();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _jobCodeController.dispose();
    _projectLocationController.dispose();
    _internalNotesController.dispose();
    _kompresor1KwController.dispose();
    _kompresor2KwController.dispose();
    _heaterKwController.dispose();
    _jetFanCountController.dispose();
    _inverterBrandController.dispose();
    for (final c in _zoneFanCountControllers) {
      c.dispose();
    }
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await UserService().getAllUsers();
      if (mounted) setState(() => _users = list);
    } catch (_) {}
  }

  Future<void> _loadInventory() async {
    try {
      final items = await _stockService.getStocks();
      if (mounted) setState(() => _allInventory = items);
    } catch (e) {
      debugPrint('Envanter yükleme hatası: $e');
    }
  }

  Future<void> _loadUsedParts() async {
    setState(() => _isLoadingParts = true);
    try {
      final parts = await _stockService.getTicketParts(widget.ticketId);
      if (mounted) {
        setState(() {
          _usedParts = parts;
          _isLoadingParts = false;
        });
      }
    } catch (e) {
      debugPrint('Parça yükleme hatası: $e');
      if (mounted) setState(() => _isLoadingParts = false);
    }
  }

  Future<void> _addPartDialog() async {
    String? selectedInventoryId;
    int quantity = 1;
    final controller = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Kullanılan Parça Ekle'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stoktan Parça Seçin',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedInventoryId,
                        items:
                            _allInventory.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id'].toString(),
                                child: Text(
                                  '${item['name']} (Stok: ${item['quantity']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedInventoryId = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Adet',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          quantity = int.tryParse(val) ?? 1;
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedInventoryId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen bir parça seçin.'),
                            ),
                          );
                          return;
                        }
                        try {
                          await _stockService.addPartToTicket(
                            widget.ticketId,
                            selectedInventoryId!,
                            quantity,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadUsedParts();
                            _loadInventory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parça eklendi ve stoktan düşüldü.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Ekle'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _removePart(int partId) async {
    try {
      await _stockService.removePartFromTicket(partId);
      _loadUsedParts();
      _loadInventory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parça silindi ve stoğa iade edildi.')),
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

  Future<void> _loadPartners() async {
    try {
      final userService = UserService();
      final profile = await userService.getCurrentUserProfile();

      if (PermissionService.hasPermission(
        profile,
        AppPermission.assignTicketPartner,
      )) {
        final partners = await _partnerService.getAllPartners();
        if (mounted) {
          setState(() {
            _partners = partners;
            _canAssignPartner = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Partner yükleme hatası: $e');
    }
  }

  Future<void> _loadUserRole() async {
    final profile = await UserService().getCurrentUserProfile();
    if (!mounted) return;

    setState(() {
      _userRole = profile?.role;
      _canManageDraftTickets = PermissionService.hasPermission(
        profile,
        AppPermission.manageDraftTickets,
      );
    });

    if (!PermissionService.hasPermission(profile, AppPermission.editTicket)) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kaydı düzenleme yetkiniz yok.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadDriveBrands() async {
    try {
      final brands = await _stockService.getBrandsByCategory('Sürücü');
      if (mounted) {
        setState(() {
          _availableDriveBrands = brands;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableDriveBrands = [];
        });
      }
    }
  }

  Future<void> _loadModelsForBrand(String brand, bool isAspirator) async {
    if (brand.isEmpty || brand == 'Diğer') {
      if (mounted) {
        setState(() {
          if (isAspirator) {
            _availableAspiratorModels = [];
            _selectedAspiratorModel = null;
          } else {
            _availableVantModels = [];
            _selectedVantModel = null;
          }
        });
      }
      return;
    }

    try {
      final models = await _stockService.getBrandModels(brand, 'Sürücü');
      if (mounted) {
        setState(() {
          if (isAspirator) {
            _availableAspiratorModels = models;
          } else {
            _availableVantModels = models;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isAspirator) {
            _availableAspiratorModels = [];
          } else {
            _availableVantModels = [];
          }
        });
      }
    }
  }

  Future<void> _loadTicket() async {
    final supabase = Supabase.instance.client;

    try {
      final response =
          await supabase
              .from('tickets')
              .select('''
            *,
            customers (
              id,
              name,
              address,
              phone
            )
          ''')
              .eq('id', _ticketIdQueryValue)
              .maybeSingle();

      if (response == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Kayıt bulunamadı.';
            _isLoading = false;
          });
        }
        return;
      }

      final Map<String, dynamic> ticket = response;
      final customer = ticket['customers'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _titleController.text = ticket['title'] ?? '';
          _descriptionController.text = ticket['description'] ?? '';
          _jobCodeController.text = ticket['job_code'] ?? '';
          _status = ticket['status'] ?? 'open';
          const validStatuses = ['open', 'done', 'archived', 'draft', 'cancelled'];
          if (!validStatuses.contains(_status)) {
            _status = 'open';
          }

          _priority = ticket['priority'] ?? 'normal';
          _jobType = ticket['job_type'] ?? 'service';
          _projectType = ticket['project_type'] ?? 'BMS';
          _projectStatus = ticket['project_status'] ?? 'planned';
          _projectLocationController.text = ticket['project_location'] ?? '';
          _responsibleUserId = ticket['responsible_user_id'] as String?;
          _internalNotesController.text = ticket['internal_notes'] ?? '';

          final assigned = ticket['assigned_user_ids'];
          if (assigned is List) {
            _assignedUserIds
              ..clear()
              ..addAll(assigned.map((e) => e.toString()));
          }

          if (ticket['planned_date'] != null) {
            _plannedDate = DateTime.tryParse(ticket['planned_date'] as String);
          }
          if (ticket['project_start_date'] != null) {
            _projectStartDate = DateTime.tryParse(
              ticket['project_start_date'] as String,
            );
          }
          if (ticket['project_due_date'] != null) {
            _projectDueDate = DateTime.tryParse(
              ticket['project_due_date'] as String,
            );
          }

          // Teknik Bilgiler
          _selectedDeviceModel = ticket['device_model'] ?? 'Klima Santrali';
          _selectedPlcModel = ticket['plc_model'];
          _selectedHmiBrand = ticket['hmi_brand'];
          _selectedHmiSize = (ticket['hmi_size'] as num?)?.toDouble();
          _selectedAspiratorBrand = ticket['aspirator_brand'];
          _selectedAspiratorKw = (ticket['aspirator_kw'] as num?)?.toDouble();
          _selectedAspiratorModel = ticket['aspirator_model'];

          _selectedVantBrand = ticket['vant_brand'];
          _selectedVantKw = (ticket['vant_kw'] as num?)?.toDouble();
          _selectedVantModel = ticket['vant_model'];

          _kompresor1KwController.text =
              ticket['kompresor_kw_1']?.toString() ?? '';
          _kompresor2KwController.text =
              ticket['kompresor_kw_2']?.toString() ?? '';

          _selectedTandem = ticket['tandem'] ?? 'yok';

          // Isıtıcı Bilgileri
          final isiticiKw = ticket['isitici_kw'];
          final isiticiKademe = ticket['isitici_kademe'] ?? 'yok';
          _heaterExists =
              (isiticiKw != null ||
                      (isiticiKademe != null && isiticiKademe != 'yok'))
                  ? 'Var'
                  : 'Yok';
          _selectedIsiticiKademe = isiticiKademe;
          if (isiticiKw != null) {
            _heaterKwController.text = isiticiKw.toString();
          }

          // Jet Fan Alanları
          _selectedZoneCount = (ticket['zone_count'] as num?)?.toInt() ?? 0;
          _jetFanCountController.text =
              ticket['jetfan_count']?.toString() ?? '';
          _inverterBrandController.text = ticket['inverter_brand'] ?? '';

          _zoneFanCountControllers.clear();
          for (int i = 0; i < _selectedZoneCount; i++) {
            _zoneFanCountControllers.add(TextEditingController());
          }

          // Detay JSON'dan parse
          final jetfanDetails = ticket['jetfan_details'];
          if (jetfanDetails is Map) {
            final zList = jetfanDetails['zone_details'];
            if (zList is List) {
              for (int i = 0; i < zList.length && i < _zoneFanCountControllers.length; i++) {
                final item = zList[i];
                if (item is Map && item['fan_count'] != null) {
                  _zoneFanCountControllers[i].text = item['fan_count'].toString();
                }
              }
            }
            final sFans = jetfanDetails['smoke_fans'];
            if (sFans is List) {
              _smokeFans = List<Map<String, dynamic>>.from(sFans);
              _smokeFanCount = _smokeFans.length;
            }
            final fFans = jetfanDetails['fresh_fans'];
            if (fFans is List) {
              _freshFans = List<Map<String, dynamic>>.from(fFans);
              _freshFanCount = _freshFans.length;
            }
          }

          // Partner Bilgileri
          _selectedPartnerId = ticket['partner_id'] as int?;

          _dx = ticket['dx'] ?? false;
          _suluBatarya = ticket['sulu_batarya'] ?? false;
          _karisimDamper = ticket['karisim_damper'] ?? false;
          _nemlendirici = ticket['nemlendirici'] ?? false;
          _rotor = ticket['rotor'] ?? false;
          _brulor = ticket['brulor'] ?? false;

          // Müşteri Bilgileri
          if (customer != null) {
            _customerId = customer['id']?.toString();
            _customerNameController.text = customer['name'] ?? '';
            _customerAddressController.text = customer['address'] ?? '';
            _customerPhoneController.text = customer['phone'] ?? '';
          }

          _isLoading = false;
        });
      }

      if (_selectedAspiratorBrand != null &&
          _selectedAspiratorBrand != 'Diğer') {
        await _loadModelsForBrand(_selectedAspiratorBrand!, true);
      }
      if (_selectedVantBrand != null && _selectedVantBrand != 'Diğer') {
        await _loadModelsForBrand(_selectedVantBrand!, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Yükleme Hatası: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _plannedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _corporateNavy,
              onPrimary: Colors.white,
              onSurface: _textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _plannedDate = picked);
    }
  }

  Future<void> _pickProjectDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
        (isStart ? _projectStartDate : _projectDueDate) ?? _plannedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _corporateNavy,
              onPrimary: Colors.white,
              onSurface: _textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _projectStartDate = picked;
        } else {
          _projectDueDate = picked;
        }
      });
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedPdf = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Dosya seçme hatası: $e');
      setState(() {
        _errorMessage = 'Dosya seçilirken hata oluştu: $e';
      });
    }
  }

  double? _parseDouble(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  int? _parseInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      setState(() => _errorMessage = 'Müşteri ID bulunamadı.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // 1. Müşteri bilgilerini güncelle
      final customerId = _customerId;
      if (customerId != null) {
        await supabase
            .from('customers')
            .update({
              'name': _customerNameController.text.trim(),
              'address': _customerAddressController.text.trim(),
              'phone': _customerPhoneController.text.trim(),
            })
            .eq('id', customerId);
      }

      final isProject = _jobType == 'project';
      final isJetFan = !isProject && _selectedDeviceModel == 'Jet Fan';
      final isOther = !isProject && _selectedDeviceModel == 'Diğer / Arıza';

      final komp1Kw = (isProject || isJetFan || isOther)
          ? null
          : _parseDouble(_kompresor1KwController.text);
      final komp2Kw = (isProject || isJetFan || isOther)
          ? null
          : _parseDouble(_kompresor2KwController.text);
      final heaterKw = (!isProject && !isJetFan && !isOther && _heaterExists == 'Var')
          ? _parseDouble(_heaterKwController.text)
          : null;
      final heaterStage = (!isProject && !isJetFan && !isOther && _heaterExists == 'Var')
          ? _selectedIsiticiKademe
          : 'yok';

      // Jet Fan Verileri
      final zoneCount = isJetFan ? _selectedZoneCount : null;
      final List<Map<String, dynamic>> zoneDetails = [];
      if (isJetFan) {
        for (int i = 0; i < _zoneFanCountControllers.length; i++) {
          zoneDetails.add({
            'zone_no': i + 1,
            'fan_count': _parseInt(_zoneFanCountControllers[i].text) ?? 0,
          });
        }
      }

      final jetFanCount = isJetFan ? _parseInt(_jetFanCountController.text) : null;
      final inverterBrand = isJetFan && _inverterBrandController.text.trim().isNotEmpty
          ? _inverterBrandController.text.trim()
          : null;

      final Map<String, dynamic>? jetfanDetails = isJetFan
          ? {
              'zone_details': zoneDetails,
              'smoke_fans': _smokeFans,
              'fresh_fans': _freshFans,
            }
          : null;

      // PDF Yükleme İşlemi
      String? pdfUrl;
      if (_selectedPdf != null) {
        try {
          final fileBytes = _selectedPdf!.bytes;
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_selectedPdf!.name}';

          if (fileBytes != null) {
            await supabase.storage
                .from('ticket-files')
                .uploadBinary(
                  fileName,
                  fileBytes,
                  fileOptions: const FileOptions(
                    contentType: 'application/pdf',
                  ),
                );

            pdfUrl = supabase.storage
                .from('ticket-files')
                .getPublicUrl(fileName);
          }
        } catch (e) {
          debugPrint('PDF yükleme hatası: $e');
          throw Exception('PDF yüklenirken hata oluştu: $e');
        }
      }

      String finalDescription = _descriptionController.text.trim();
      if (pdfUrl != null) {
        finalDescription += '\n\nEkli PDF Dosyası: $pdfUrl';
      }

      // 2. Ticket Bilgilerini Güncelle
      await supabase
          .from('tickets')
          .update({
            'title': _titleController.text.trim(),
            'description': finalDescription,
            'status': _status,
            'priority': _priority,
            'partner_id': _selectedPartnerId,
            'planned_date': _plannedDate?.toIso8601String(),
            'job_type': _jobType,
            'project_type': isProject ? _projectType : null,
            'project_status': isProject ? _projectStatus : 'planned',
            'project_location':
                isProject ? _projectLocationController.text.trim() : null,
            'responsible_user_id': isProject ? _responsibleUserId : null,
            'assigned_user_ids':
                isProject ? _assignedUserIds.toList(growable: false) : <String>[],
            'project_start_date':
                isProject ? _projectStartDate?.toIso8601String() : null,
            'project_due_date':
                isProject ? _projectDueDate?.toIso8601String() : null,
            'internal_notes':
                isProject ? _internalNotesController.text.trim() : null,
            'job_code':
                _jobCodeController.text.trim().isEmpty
                    ? null
                    : _jobCodeController.text.trim(),
            'device_model': isProject ? null : _selectedDeviceModel,
            'plc_model': (isProject || isOther || isJetFan) ? null : _selectedPlcModel,
            'hmi_brand': (isProject || isOther || isJetFan) ? null : _selectedHmiBrand,
            'hmi_size': (isProject || isOther || isJetFan) ? null : _selectedHmiSize,
            'aspirator_kw': (isProject || isOther || isJetFan) ? null : _selectedAspiratorKw,
            'aspirator_brand': (isProject || isOther || isJetFan) ? null : _selectedAspiratorBrand,
            'aspirator_model': (isProject || isOther || isJetFan) ? null : _selectedAspiratorModel,
            'vant_kw': (isProject || isOther || isJetFan) ? null : _selectedVantKw,
            'vant_brand': (isProject || isOther || isJetFan) ? null : _selectedVantBrand,
            'vant_model': (isProject || isOther || isJetFan) ? null : _selectedVantModel,
            'kompresor_kw_1': komp1Kw,
            'kompresor_kw_2': komp2Kw,
            'tandem': (isProject || isOther || isJetFan) ? 'yok' : _selectedTandem,
            'isitici_kademe': heaterStage,
            'isitici_kw': heaterKw,
            'dx': (isProject || isOther || isJetFan) ? false : _dx,
            'sulu_batarya': (isProject || isOther || isJetFan) ? false : _suluBatarya,
            'karisim_damper': (isProject || isOther || isJetFan) ? false : _karisimDamper,
            'nemlendirici': (isProject || isOther || isJetFan) ? false : _nemlendirici,
            'rotor': (isProject || isOther || isJetFan) ? false : _rotor,
            'brulor': (isProject || isOther || isJetFan) ? false : _brulor,
            'zone_count': zoneCount,
            'jetfan_count': jetFanCount,
            'inverter_brand': inverterBrand,
            if (jetfanDetails != null) 'jetfan_details': jetfanDetails,
          })
          .eq('id', _ticketIdQueryValue);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final textColor = isDark ? Colors.white : _textDark;

    final isProject = _jobType == 'project';
    final isJetFan = !isProject && _selectedDeviceModel == 'Jet Fan';
    final isOther = !isProject && _selectedDeviceModel == 'Diğer / Arıza';
    final showSantralTechnicalCards = !isProject && !isJetFan && !isOther;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        iconTheme: IconThemeData(color: textColor),
        leadingWidth: 80,
        leading: Row(
          children: [
            const BackButton(),
            SvgPicture.asset('assets/images/log.svg', width: 24, height: 24),
          ],
        ),
        title: Text(
          'İŞ EMRİNİ DÜZENLE',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: _corporateNavy),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // İŞ TİPİ SEÇİCİ
                          _buildJobTypeSelector(),
                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: isWide ? 3 : 1,
                                child: Column(
                                  children: [
                                    _buildContentCard(
                                      title: 'İş Bilgileri',
                                      icon: Icons.work_outline,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: _buildTextField(
                                                controller: _titleController,
                                                label: 'İş Başlığı',
                                                hint: 'Örn: Klima Bakımı',
                                                isRequired: true,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 1,
                                              child: _buildTextField(
                                                controller: _jobCodeController,
                                                label: 'İş Kodu',
                                                hint: 'H-001-23',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _descriptionController,
                                          label: 'İş Açıklaması',
                                          hint:
                                              'Yapılacak işlemlerin detayları...',
                                          maxLines: 3,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDatePicker(),
                                        const SizedBox(height: 16),
                                        // PDF Seçici
                                        InkWell(
                                          onTap: _pickPdf,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: _backgroundGrey
                                                  .withValues(alpha: 0.5),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.picture_as_pdf,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Ek Doküman (PDF)',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: _textLight,
                                                        ),
                                                      ),
                                                      Text(
                                                        _selectedPdf != null
                                                            ? _selectedPdf!.name
                                                            : 'Yeni PDF Seç (İsteğe bağlı)',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (_selectedPdf != null)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed:
                                                        () => setState(
                                                          () =>
                                                              _selectedPdf =
                                                                  null,
                                                        ),
                                                  )
                                                else
                                                  const Icon(
                                                    Icons.attach_file,
                                                    color: _textLight,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // PROJE BİLGİLERİ (Proje Seçildiyse)
                                    if (isProject) ...[
                                      _buildProjectInfoCard(),
                                      const SizedBox(height: 24),
                                    ],

                                    // MÜŞTERİ BİLGİLERİ
                                    _buildContentCard(
                                      title: 'Müşteri Bilgileri',
                                      icon: Icons.person_outline,
                                      children: [
                                        if (_canAssignPartner &&
                                            _partners.isNotEmpty) ...[
                                          _buildDropdown<int?>(
                                            label:
                                                'Partner Firma Ataması (Opsiyonel)',
                                            value: _selectedPartnerId,
                                            items: [
                                              null,
                                              ..._partners.map((p) => p.id),
                                            ],
                                            itemLabelBuilder: (val) {
                                              if (val == null) {
                                                return 'Atama Yapılmayacak (Doğrudan Müşteri)';
                                              }
                                              final p = _partners.firstWhere(
                                                (element) => element.id == val,
                                                orElse:
                                                    () => Partner(
                                                      id: -1,
                                                      name: 'Bilinmeyen',
                                                    ),
                                              );
                                              return p.name;
                                            },
                                            onChanged: (val) {
                                              setState(() {
                                                _selectedPartnerId = val;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 16),
                                        ],

                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildTextField(
                                                controller:
                                                    _customerNameController,
                                                label: 'Müşteri Adı / Firma',
                                                icon: Icons.business,
                                                isRequired: true,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildTextField(
                                                controller:
                                                    _customerPhoneController,
                                                label: 'Telefon',
                                                icon: Icons.phone,
                                                keyboardType:
                                                    TextInputType.phone,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller:
                                              _customerAddressController,
                                          label: 'Adres',
                                          icon: Icons.location_on_outlined,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // KULLANILAN MALZEMELER
                                    _buildContentCard(
                                      title: 'KULLANILAN MALZEMELER',
                                      icon: Icons.inventory_2_outlined,
                                      children: [
                                        if (_isLoadingParts)
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        else if (_usedParts.isEmpty)
                                          const Center(
                                            child: Text(
                                              'Henüz malzeme eklenmemiş.',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          )
                                        else
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: _usedParts.length,
                                            separatorBuilder:
                                                (_, __) => const Divider(),
                                            itemBuilder: (context, index) {
                                              final part = _usedParts[index];
                                              return ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  part.inventoryName ??
                                                      'Bilinmeyen Ürün',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${part.quantity} Adet',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _removePart(part.id),
                                                ),
                                              );
                                            },
                                          ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _addPartDialog,
                                            icon: const Icon(Icons.add),
                                            label: const Text('Parça Ekle'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (isWide && !isProject && !isOther) ...[
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 2,
                                  child: isJetFan
                                      ? _buildJetFanInfoCard()
                                      : Column(
                                        children: [
                                          _buildTechnicalInfoCard(),
                                          const SizedBox(height: 24),
                                          _buildHeaterInfoCard(),
                                          const SizedBox(height: 24),
                                          _buildHardwareFeaturesCard(),
                                        ],
                                      ),
                                ),
                              ],
                            ],
                          ),

                          if (!isWide && !isProject && !isOther) ...[
                            const SizedBox(height: 24),
                            if (isJetFan)
                              _buildJetFanInfoCard()
                            else ...[
                              _buildTechnicalInfoCard(),
                              const SizedBox(height: 24),
                              _buildHeaterInfoCard(),
                              const SizedBox(height: 24),
                              _buildHardwareFeaturesCard(),
                            ],
                          ],

                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _corporateNavy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _isSaving
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : const Text(
                                        'KAYDET',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildJobTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _JobTypeOption(
            title: 'Servis İşi',
            subtitle: 'Klima, bakım, arıza ve tek seferlik saha işleri',
            icon: Icons.build_circle_outlined,
            selected: _jobType == 'service',
            onTap: () => setState(() => _jobType = 'service'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _JobTypeOption(
            title: 'Proje İşi',
            subtitle: 'BMS, SCADA, otomasyon ve uzun süreli işler',
            icon: Icons.account_tree_outlined,
            selected: _jobType == 'project',
            onTap: () => setState(() => _jobType = 'project'),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectInfoCard() {
    return _buildContentCard(
      title: 'Proje Takip Bilgileri',
      icon: Icons.account_tree_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                label: 'Proje Tipi',
                value: _projectType,
                items: const [
                  'BMS',
                  'SCADA',
                  'PLC/HMI',
                  'Pano Revizyonu',
                  'BACnet/Modbus',
                  'Devreye Alma',
                  'Diğer',
                ],
                onChanged:
                    (value) => setState(() => _projectType = value ?? 'BMS'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<String>(
                label: 'Proje Durumu',
                value: _projectStatus,
                items: const [
                  'planned',
                  'in_progress',
                  'waiting',
                  'testing',
                  'missing',
                  'done',
                  'cancelled',
                ],
                itemLabels: const {
                  'planned': 'Planlandı',
                  'in_progress': 'Devam ediyor',
                  'waiting': 'Beklemede',
                  'testing': 'Test aşamasında',
                  'missing': 'Eksik bekliyor',
                  'done': 'Tamamlandı',
                  'cancelled': 'İptal edildi',
                },
                onChanged:
                    (value) =>
                        setState(() => _projectStatus = value ?? 'planned'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _projectLocationController,
          label: 'Lokasyon',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                label: 'Sorumlu Kullanıcı',
                value: _responsibleUserId,
                items: _users.map((user) => user.id).toList(),
                itemLabelBuilder: (id) {
                  final user = _users.firstWhere(
                    (item) => item.id == id,
                    orElse: () => UserProfile(id: id, role: UserRole.user),
                  );
                  return user.displayName;
                },
                onChanged:
                    (value) => setState(() => _responsibleUserId = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final user in _users)
              FilterChip(
                label: Text(user.displayName),
                selected: _assignedUserIds.contains(user.id),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _assignedUserIds.add(user.id);
                    } else {
                      _assignedUserIds.remove(user.id);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ProjectDateBox(
                label: 'Başlangıç Tarihi',
                date: _projectStartDate,
                onTap: () => _pickProjectDate(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProjectDateBox(
                label: 'Planlanan Bitiş',
                date: _projectDueDate,
                onTap: () => _pickProjectDate(isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _internalNotesController,
          label: 'İç Notlar',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildJetFanInfoCard() {
    final countOptions = List.generate(21, (index) => index);

    return _buildContentCard(
      title: 'Jet Fan & Otopark Havalandırma',
      icon: Icons.wind_power,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<int>(
                label: 'Zone Sayısı',
                value: _selectedZoneCount,
                items: countOptions,
                onChanged: (val) {
                  setState(() {
                    _selectedZoneCount = val ?? 0;
                    if (_selectedZoneCount > _zoneFanCountControllers.length) {
                      for (
                        int i = _zoneFanCountControllers.length;
                        i < _selectedZoneCount;
                        i++
                      ) {
                        _zoneFanCountControllers.add(TextEditingController());
                      }
                    } else {
                      for (
                        int i = _zoneFanCountControllers.length - 1;
                        i >= _selectedZoneCount;
                        i--
                      ) {
                        _zoneFanCountControllers[i].dispose();
                        _zoneFanCountControllers.removeAt(i);
                      }
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _jetFanCountController,
                label: 'Toplam Jet Fan',
                icon: Icons.numbers,
                isNumeric: true,
              ),
            ),
          ],
        ),
        if (_zoneFanCountControllers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Zone Bazlı Fan Sayıları',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _zoneFanCountControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTextField(
                  controller: _zoneFanCountControllers[index],
                  label: '${index + 1}. Zone Jet Fan Sayısı',
                  isNumeric: true,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Duman Tahliye Fanları',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _corporateNavy,
          ),
        ),
        const SizedBox(height: 8),
        _buildDropdown<int>(
          label: 'Duman Tahliye Fanı Sayısı',
          value: _smokeFanCount,
          items: countOptions,
          onChanged: (val) {
            setState(() {
              _smokeFanCount = val ?? 0;
              if (_smokeFanCount > _smokeFans.length) {
                for (int i = _smokeFans.length; i < _smokeFanCount; i++) {
                  _smokeFans.add({'brand': null, 'kw': null});
                }
              } else {
                _smokeFans.length = _smokeFanCount;
              }
            });
          },
        ),
        if (_smokeFans.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _smokeFans.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'İnverter Markası',
                        value: _smokeFans[index]['brand'],
                        items: _availableDriveBrands,
                        onChanged: (val) {
                          setState(() => _smokeFans[index]['brand'] = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown<double>(
                        label: 'Güç (kW)',
                        value: _smokeFans[index]['kw'],
                        items: StockService.kwValues,
                        itemLabelBuilder: (val) => '$val kW',
                        onChanged: (val) {
                          setState(() => _smokeFans[index]['kw'] = val);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Taze Hava Fanları',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _corporateNavy,
          ),
        ),
        const SizedBox(height: 8),
        _buildDropdown<int>(
          label: 'Taze Hava Fanı Sayısı',
          value: _freshFanCount,
          items: countOptions,
          onChanged: (val) {
            setState(() {
              _freshFanCount = val ?? 0;
              if (_freshFanCount > _freshFans.length) {
                for (int i = _freshFans.length; i < _freshFanCount; i++) {
                  _freshFans.add({'brand': null, 'kw': null});
                }
              } else {
                _freshFans.length = _freshFanCount;
              }
            });
          },
        ),
        if (_freshFans.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _freshFans.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'İnverter Markası',
                        value: _freshFans[index]['brand'],
                        items: _availableDriveBrands,
                        onChanged: (val) {
                          setState(() => _freshFans[index]['brand'] = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown<double>(
                        label: 'Güç (kW)',
                        value: _freshFans[index]['kw'],
                        items: StockService.kwValues,
                        itemLabelBuilder: (val) => '$val kW',
                        onChanged: (val) {
                          setState(() => _freshFans[index]['kw'] = val);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTechnicalInfoCard() {
    return _buildContentCard(
      title: 'Cihaz Teknik Verileri',
      icon: Icons.settings_input_component,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Cihaz Modeli',
                value: _selectedDeviceModel,
                items: const [
                  'Klima Santrali',
                  'Hijyenik Klima Santrali',
                  'Rooftop',
                  'Nem Alma Santrali',
                  'Elektrostatik',
                  'Heat-Pump',
                  'Jet Fan',
                  'Diğer / Arıza',
                ],
                onChanged: (val) => setState(() => _selectedDeviceModel = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'PLC Marka/Model',
                value: _selectedPlcModel,
                items: const [
                  'Havkon Cpx.139',
                  'Havkon Cpx.119',
                  'ABB FBX',
                  'ABB CBX',
                  'ABB CBT',
                ],
                onChanged: (val) => setState(() => _selectedPlcModel = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'HMI Ekran Bilgileri',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _textLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Marka',
                value: _selectedHmiBrand,
                items: StockService.hmiBrands,
                onChanged: (val) => setState(() => _selectedHmiBrand = val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<double>(
                label: 'Ekran Boyutu (inç)',
                value: _selectedHmiSize,
                items: StockService.hmiSizes,
                itemLabelBuilder: (val) => '$val inç',
                onChanged: (val) => setState(() => _selectedHmiSize = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Aspiratör Sürücü Bilgileri',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _textLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Marka',
                value: _selectedAspiratorBrand,
                items: _availableDriveBrands,
                onChanged: (val) async {
                  setState(() {
                    _selectedAspiratorBrand = val;
                    _selectedAspiratorModel = null;
                  });
                  await _loadModelsForBrand(val ?? '', true);
                },
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedAspiratorBrand != null &&
                _availableAspiratorModels.isNotEmpty)
              Expanded(
                child: _buildDropdown(
                  label: 'Model',
                  value: _selectedAspiratorModel,
                  items: _availableAspiratorModels,
                  onChanged:
                      (val) => setState(() => _selectedAspiratorModel = val),
                ),
              ),
            if (_selectedAspiratorBrand != null &&
                _availableAspiratorModels.isNotEmpty)
              const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<dynamic>(
                label: 'Güç (kW)',
                value: _selectedAspiratorKw,
                items: [null, ...StockService.kwValues],
                itemLabelBuilder: (val) => val == null ? 'Yok' : '$val kW',
                onChanged: (val) => setState(() => _selectedAspiratorKw = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Vantilatör Sürücü Bilgileri',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _textLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Marka',
                value: _selectedVantBrand,
                items: _availableDriveBrands,
                onChanged: (val) async {
                  setState(() {
                    _selectedVantBrand = val;
                    _selectedVantModel = null;
                  });
                  await _loadModelsForBrand(val ?? '', false);
                },
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedVantBrand != null && _availableVantModels.isNotEmpty)
              Expanded(
                child: _buildDropdown(
                  label: 'Model',
                  value: _selectedVantModel,
                  items: _availableVantModels,
                  onChanged: (val) => setState(() => _selectedVantModel = val),
                ),
              ),
            if (_selectedVantBrand != null && _availableVantModels.isNotEmpty)
              const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<dynamic>(
                label: 'Güç (kW)',
                value: _selectedVantKw,
                items: [null, ...StockService.kwValues],
                itemLabelBuilder: (val) => val == null ? 'Yok' : '$val kW',
                onChanged: (val) => setState(() => _selectedVantKw = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Kompresör Güçleri',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _textLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _kompresor1KwController,
                label: 'Komp. 1',
                isNumeric: true,
                suffixText: 'kW',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _kompresor2KwController,
                label: 'Komp. 2',
                isNumeric: true,
                suffixText: 'kW',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Tandem Özelliği',
          value: _selectedTandem,
          items: const ['yok', 'var'],
          itemLabels: const {'yok': 'Yok', 'var': 'Var'},
          onChanged: (val) => setState(() => _selectedTandem = val!),
        ),
      ],
    );
  }

  Widget _buildHardwareFeaturesCard() {
    return _buildContentCard(
      title: 'Donanım Özellikleri',
      icon: Icons.check_box_outlined,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFeatureChip('DX', _dx, (val) => setState(() => _dx = val)),
            _buildFeatureChip(
              'Sulu Batarya',
              _suluBatarya,
              (val) => setState(() => _suluBatarya = val),
            ),
            _buildFeatureChip(
              'Karışım Damper',
              _karisimDamper,
              (val) => setState(() => _karisimDamper = val),
            ),
            _buildFeatureChip(
              'Nemlendirici',
              _nemlendirici,
              (val) => setState(() => _nemlendirici = val),
            ),
            _buildFeatureChip(
              'Rotor',
              _rotor,
              (val) => setState(() => _rotor = val),
            ),
            _buildFeatureChip(
              'Brülör',
              _brulor,
              (val) => setState(() => _brulor = val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaterInfoCard() {
    return _buildContentCard(
      title: 'Isıtıcı Bilgileri',
      icon: Icons.whatshot,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Isıtıcı Mevcut mu?',
                value: _heaterExists,
                items: const ['Yok', 'Var'],
                onChanged: (val) {
                  setState(() {
                    _heaterExists = val!;
                    if (_heaterExists == 'Yok') {
                      _selectedIsiticiKademe = 'yok';
                      _heaterKwController.clear();
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (_heaterExists == 'Var') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Isıtıcı Kademesi',
                  value: _selectedIsiticiKademe,
                  items: const ['yok', '1', '2', '3', '4', '5', '6'],
                  itemLabels: const {
                    'yok': 'Seçiniz',
                    '1': '1 Kademe',
                    '2': '2 Kademe',
                    '3': '3 Kademe',
                    '4': '4 Kademe',
                    '5': '5 Kademe',
                    '6': '6 Kademe',
                  },
                  onChanged: (val) => setState(() => _selectedIsiticiKademe = val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _heaterKwController,
                  label: 'Isıtıcı Gücü (kW)',
                  isNumeric: true,
                  suffixText: 'kW',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureChip(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF38BDF8) : _corporateNavy;
    final activeTextColor = isDark ? Colors.black : Colors.white;

    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: activeColor,
      checkmarkColor: activeTextColor,
      labelStyle: TextStyle(
        color: value ? activeTextColor : _textDark,
        fontSize: 12,
        fontWeight: value ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: _backgroundGrey.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: value ? activeColor : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final dateText =
        _plannedDate == null
            ? 'Planlanan Tarih Seç (İsteğe bağlı)'
            : '${_plannedDate!.day}.${_plannedDate!.month}.${_plannedDate!.year}';

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: _backgroundGrey.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: _textLight,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Planlanan Müdahale Tarihi',
                    style: TextStyle(fontSize: 11, color: _textLight),
                  ),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_plannedDate != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _textLight),
                onPressed: () => setState(() => _plannedDate = null),
              )
            else
              const Icon(Icons.arrow_drop_down, color: _textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : _corporateNavy;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool isRequired = false,
    int maxLines = 1,
    bool isNumeric = false,
    String? suffixText,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor =
        isDark ? const Color(0xFF334155) : _backgroundGrey.withValues(alpha: 0.5);
    final textColor = isDark ? Colors.white : _textDark;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType:
          keyboardType ??
          (isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        labelStyle: const TextStyle(color: _textLight, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon:
            icon != null ? Icon(icon, size: 20, color: _textLight) : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _corporateNavy, width: 1.5),
        ),
        filled: true,
        fillColor: fillColor,
      ),
      validator:
          isRequired
              ? (val) =>
                  (val == null || val.trim().isEmpty)
                      ? '$label zorunludur.'
                      : null
              : null,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    Map<T, String>? itemLabels,
    String Function(T)? itemLabelBuilder,
    required Function(T?) onChanged,
    bool isRequired = false,
  }) {
    // Listede olmayan bir değer varsa çökmeyi önlemek için listeye ekle
    final List<T> effectiveItems = [
      if (value != null && !items.contains(value)) value,
      ...items,
    ];

    T? safeValue;
    if (value != null) {
      try {
        safeValue = effectiveItems.firstWhere((item) => item == value);
      } catch (_) {
        safeValue = null;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final fillColor =
        isDark ? const Color(0xFF334155) : _backgroundGrey.withValues(alpha: 0.5);
    final textColor = isDark ? Colors.white : Colors.black;

    return DropdownButtonFormField<T>(
      isExpanded: true,
      dropdownColor: dropdownColor,
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textLight, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _corporateNavy, width: 1.5),
        ),
        filled: true,
        fillColor: fillColor,
      ),
      items:
          effectiveItems.toSet().map((item) {
            String text;
            if (itemLabels != null) {
              text = itemLabels[item] ?? item.toString();
            } else if (itemLabelBuilder != null) {
              text = itemLabelBuilder(item);
            } else {
              text = item.toString();
            }
            return DropdownMenuItem<T>(
              value: item,
              child: Text(text, style: TextStyle(color: textColor)),
            );
          }).toList(),
      onChanged: onChanged,
      validator:
          isRequired
              ? (val) {
                if (val == null) return '$label seçilmelidir.';
                if (val is String && val.isEmpty) return '$label seçilmelidir.';
                return null;
              }
              : null,
    );
  }
}

class _JobTypeOption extends StatelessWidget {
  const _JobTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.corporateNavy.withValues(alpha: 0.08)
                  : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.corporateNavy : AppColors.borderSubtle,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.corporateNavy : AppColors.textLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDateBox extends StatelessWidget {
  const _ProjectDateBox({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text =
        date == null
            ? 'Tarih seçilmedi'
            : '${date!.day}.${date!.month}.${date!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textLight,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          date == null
                              ? AppColors.textLight
                              : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
