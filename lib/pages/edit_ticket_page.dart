import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // Eklendi
import 'package:flutter_svg/flutter_svg.dart'; // Eklendi
import '../services/stock_service.dart'; // StockService eklendi
import '../services/partner_service.dart'; // Partner Service eklendi
import '../services/user_service.dart'; // User Service eklendi
import '../models/partner.dart'; // Partner Model eklendi

class EditTicketPage extends StatefulWidget {
  final String ticketId;

  const EditTicketPage({super.key, required this.ticketId});

  @override
  State<EditTicketPage> createState() => _EditTicketPageState();
}

class _EditTicketPageState extends State<EditTicketPage> {
  // --- SABİTLER VE AYARLAR ---
  static const Color _corporateNavy = Color(0xFF0F172A);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);
  static const Color _surfaceWhite = Colors.white;
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textLight = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobCodeController = TextEditingController();
  final _kompresor1KwController = TextEditingController();
  final _kompresor2KwController = TextEditingController();
  final _heaterKwController = TextEditingController(); // Yeni: Isıtıcı kW
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  String? _selectedDeviceModel;
  String? _selectedPlcModel;
  
  String? _selectedHmiBrand;
  double? _selectedHmiSize;
  
  String? _selectedAspiratorBrand;
  String? _selectedAspiratorModel; // Aspiratör için model
  double? _selectedAspiratorKw;
  List<String> _availableAspiratorModels = []; // Aspiratör markasına göre modeller
  
  String? _selectedVantBrand;
  String? _selectedVantModel; // Vantilatör için model
  double? _selectedVantKw;
  List<String> _availableVantModels = []; // Vantilatör markasına göre modeller
  
  final StockService _stockService = StockService();
  List<String> _availableDriveBrands = []; // Veritabanından yüklenen markalar

  // Partner Firmalar
  final PartnerService _partnerService = PartnerService();
  List<Partner> _partners = [];
  int? _selectedPartnerId;
  bool _canAssignPartner = false; // Sadece admin/manager atayabilir

  String _selectedTandem = 'yok';
  String _heaterExists = 'Yok'; // Yeni: Isıtıcı var mı yok mu
  String _selectedIsiticiKademe = 'yok';

  bool _dx = false;
  bool _suluBatarya = false;
  bool _karisimDamper = false;
  bool _nemlendirici = false;
  bool _rotor = false;
  bool _brulor = false;

  DateTime? _plannedDate;
  PlatformFile? _selectedPdf; // Seçilen PDF dosyası
  bool _isUploading = false;
  
  String _status = 'open';
  String _priority = 'normal';
  String? _customerId;

  bool _isSaving = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole; // Kullanıcı rolü (admin/manager kontrolü için)

  dynamic get _ticketIdQueryValue {
    final parsed = int.tryParse(widget.ticketId);
    return parsed ?? widget.ticketId;
  }

  @override
  void initState() {
    super.initState();
    _loadDriveBrands();
    _loadTicket();
    _loadUserRole();
    _loadPartners(); // Partnerleri yükle
  }
  
  Future<void> _loadPartners() async {
    try {
      final userService = UserService();
      final profile = await userService.getCurrentUserProfile();
      
      // Sadece Admin ve Yöneticiler partner atayabilir
      if (profile != null && (profile.isAdmin || profile.isManager)) {
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
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _userRole = profile != null ? profile['role'] as String? : null;
          });
        }
      } catch (_) {
        // Hata durumunda null kalır
      }
    }
  }
  
  Future<void> _loadDriveBrands() async {
    try {
      final brands = await _stockService.getBrandsByCategory('Sürücü');
      // Sadece veritabanından gelenleri kullan
      final allBrands = brands;
      if (mounted) {
        setState(() {
          _availableDriveBrands = allBrands;
        });
      }
    } catch (e) {
      // Hata durumunda boş liste
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _jobCodeController.dispose();
    _kompresor1KwController.dispose();
    _kompresor2KwController.dispose();
    _heaterKwController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
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
          // İş Bilgileri
          _titleController.text = ticket['title'] ?? '';
          _descriptionController.text = ticket['description'] ?? '';
          _jobCodeController.text = ticket['job_code'] ?? '';
          _status = ticket['status'] ?? 'open';
          // Eğer veritabanından gelen status listede yoksa varsayılan 'open' olsun (güvenlik)
          const validStatuses = ['open', 'panel_done_stock', 'panel_done_sent', 'in_progress', 'done', 'archived'];
          if (!validStatuses.contains(_status)) {
            _status = 'open';
          }
          
          _priority = ticket['priority'] ?? 'normal';
          
          if (ticket['planned_date'] != null) {
            _plannedDate = DateTime.tryParse(ticket['planned_date'] as String);
          }

          // Teknik Bilgiler
          _selectedDeviceModel = ticket['device_model'];
          _selectedPlcModel = ticket['plc_model'];
          _selectedHmiBrand = ticket['hmi_brand'];
          _selectedHmiSize = (ticket['hmi_size'] as num?)?.toDouble();
          _selectedAspiratorBrand = ticket['aspirator_brand'];
          _selectedAspiratorKw = (ticket['aspirator_kw'] as num?)?.toDouble();
          _selectedAspiratorModel = ticket['aspirator_model'];
          
          _selectedVantBrand = ticket['vant_brand'];
          _selectedVantKw = (ticket['vant_kw'] as num?)?.toDouble();
          _selectedVantModel = ticket['vant_model'];
          
          _kompresor1KwController.text = ticket['kompresor_kw_1']?.toString() ?? '';
          _kompresor2KwController.text = ticket['kompresor_kw_2']?.toString() ?? '';
          
          _selectedTandem = ticket['tandem'] ?? 'yok';
          
          // Isıtıcı Bilgileri
          final isiticiKw = ticket['isitici_kw'];
          final isiticiKademe = ticket['isitici_kademe'] ?? 'yok';
          _heaterExists = (isiticiKw != null || (isiticiKademe != null && isiticiKademe != 'yok')) ? 'Var' : 'Yok';
          _selectedIsiticiKademe = isiticiKademe;
          if (isiticiKw != null) {
            _heaterKwController.text = isiticiKw.toString();
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
            _customerId = customer['id'] as String?; // String veya int olabilir, dikkat
            if (customer['id'] is int) _customerId = customer['id'].toString();
            
            _customerNameController.text = customer['name'] ?? '';
            _customerAddressController.text = customer['address'] ?? '';
            _customerPhoneController.text = customer['phone'] ?? '';
          }

          _isLoading = false;
        });
      }

      // Markalar yüklendikten sonra modelleri yükle (setState dışında)
      if (_selectedAspiratorBrand != null && _selectedAspiratorBrand != 'Diğer') {
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
    if (picked != null) {
      setState(() {
        _plannedDate = picked;
      });
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Web için gerekli
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
      // 4. Adım: Stok Değişikliği Kontrolü
      // Eski ve yeni parçaları karşılaştır, sadece değişiklik varsa stok güncelle
      
      // Önceki veriyi çek (Eski stokları bilmek için)
      final oldTicketResponse = await supabase
          .from('tickets')
          .select()
          .eq('id', _ticketIdQueryValue)
          .maybeSingle();

      // Eski kayıt bilgileri
      final oldPlc = oldTicketResponse != null ? oldTicketResponse['plc_model'] : null;
      final oldHmiBrand = oldTicketResponse != null ? oldTicketResponse['hmi_brand'] : null;
      final oldHmiSize = oldTicketResponse != null ? (oldTicketResponse['hmi_size'] as num?)?.toDouble() : null;
      final oldAspBrand = oldTicketResponse != null ? oldTicketResponse['aspirator_brand'] : null;
      final oldAspKw = oldTicketResponse != null ? (oldTicketResponse['aspirator_kw'] as num?)?.toDouble() : null;
      final oldAspModel = oldTicketResponse != null ? oldTicketResponse['aspirator_model'] : null; // Gelecekte eklenecek
      final oldVantBrand = oldTicketResponse != null ? oldTicketResponse['vant_brand'] : null;
      final oldVantKw = oldTicketResponse != null ? (oldTicketResponse['vant_kw'] as num?)?.toDouble() : null;
      final oldVantModel = oldTicketResponse != null ? oldTicketResponse['vant_model'] : null; // Gelecekte eklenecek

      // Yeni seçilenler
      final newPlc = _selectedPlcModel;
      final newHmiBrand = _selectedHmiBrand;
      final newHmiSize = _selectedHmiSize;
      final newAspBrand = _selectedAspiratorBrand;
      final newAspModel = _selectedAspiratorModel;
      final newAspKw = _selectedAspiratorKw;
      final newVantBrand = _selectedVantBrand;
      final newVantModel = _selectedVantModel;
      final newVantKw = _selectedVantKw;

      // PLC değişti mi?
      if (oldPlc != newPlc) {
         if (oldPlc != null) await StockService().revertTicketStockUsage(plcModel: oldPlc);
         if (newPlc != null) await StockService().processTicketStockUsage(plcModel: newPlc);
      }
      
      // HMI değişti mi?
      if (oldHmiBrand != newHmiBrand || oldHmiSize != newHmiSize) {
         if (oldHmiBrand != null && oldHmiSize != null) {
            await StockService().revertTicketStockUsage(hmiBrand: oldHmiBrand, hmiSize: oldHmiSize);
         }
         if (newHmiBrand != null && newHmiSize != null) {
            await StockService().processTicketStockUsage(hmiBrand: newHmiBrand, hmiSize: newHmiSize);
         }
      }

      // Aspiratör Sürücü değişti mi?
      if (oldAspBrand != newAspBrand || oldAspKw != newAspKw || oldAspModel != newAspModel) {
         // Eski kombinasyonu iade et
         if (oldAspBrand != null && oldAspKw != null) {
            await StockService().revertTicketStockUsage(
              aspiratorBrand: oldAspBrand, 
              aspiratorModel: oldAspModel,
              aspiratorKw: oldAspKw
            );
         }
         // Yeni kombinasyonu düş
         if (newAspBrand != null && newAspKw != null) {
            await StockService().processTicketStockUsage(
              aspiratorBrand: newAspBrand, 
              aspiratorModel: newAspModel,
              aspiratorKw: newAspKw
            );
         }
      }

      // Vantilatör Sürücü değişti mi?
      if (oldVantBrand != newVantBrand || oldVantKw != newVantKw || oldVantModel != newVantModel) {
         // Eski kombinasyonu iade et
         if (oldVantBrand != null && oldVantKw != null) {
            await StockService().revertTicketStockUsage(
              vantBrand: oldVantBrand, 
              vantModel: oldVantModel,
              vantKw: oldVantKw
            );
         }
         // Yeni kombinasyonu düş
         if (newVantBrand != null && newVantKw != null) {
            await StockService().processTicketStockUsage(
              vantBrand: newVantBrand, 
              vantModel: newVantModel,
              vantKw: newVantKw
            );
         }
      }

      // Eksik Parça Listesini Güncelle (Son duruma göre tekrar kontrol et)
      // Burada sadece eksik kontrolü yapıyoruz, stok düşmüyoruz (çünkü yukarıda yaptık)
      final missingItems = <String>[];
      
      // PLC Eksik mi?
      if (newPlc != null && newPlc != 'Diğer') {
         final stock = await supabase.from('inventory').select('quantity').eq('name', '$newPlc PLC').maybeSingle();
         if (stock != null && (stock['quantity'] as int) < 0) missingItems.add('$newPlc PLC');
      }

      // HMI Eksik mi?
      if (newHmiBrand != null && newHmiSize != null && newHmiBrand != 'Diğer') {
         final name = '$newHmiBrand ${StockService.formatInch(newHmiSize)} inç HMI';
         final stock = await supabase.from('inventory').select('quantity').eq('name', name).maybeSingle();
         if (stock != null && (stock['quantity'] as int) < 0) missingItems.add(name);
      }

      // Aspiratör Eksik mi?
      if (newAspBrand != null && newAspKw != null && newAspBrand != 'Diğer') {
         final name = '$newAspBrand ${StockService.formatKw(newAspKw)} kW Sürücü';
         final stock = await supabase.from('inventory').select('quantity').eq('name', name).maybeSingle();
         if (stock != null && (stock['quantity'] as int) < 0) missingItems.add(name);
      }
      
      // Vantilatör Eksik mi?
      if (newVantBrand != null && newVantKw != null && newVantBrand != 'Diğer') {
         final name = '$newVantBrand ${StockService.formatKw(newVantKw)} kW Sürücü';
         final stock = await supabase.from('inventory').select('quantity').eq('name', name).maybeSingle();
         if (stock != null && (stock['quantity'] as int) < 0) missingItems.add(name);
      }

      // Müşteri bilgilerini güncelle
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

      // Isıtıcı verilerini hazırla
      final komp1Kw = _parseDouble(_kompresor1KwController.text);
      final komp2Kw = _parseDouble(_kompresor2KwController.text);
      final heaterKw = (_heaterExists == 'Var') ? _parseDouble(_heaterKwController.text) : null;
      final heaterStage = (_heaterExists == 'Var') ? _selectedIsiticiKademe : 'yok';

      // PDF Yükleme İşlemi
      String? pdfUrl;
      if (_selectedPdf != null) {
        try {
          final fileBytes = _selectedPdf!.bytes;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedPdf!.name}';
          
          if (fileBytes != null) {
            await supabase.storage.from('ticket-files').uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );
            
            // Public URL al
            pdfUrl = supabase.storage.from('ticket-files').getPublicUrl(fileName);
          }
        } catch (e) {
          debugPrint('PDF yükleme hatası: $e');
          throw Exception('PDF yüklenirken hata oluştu: $e');
        }
      }

      // Ticket açıklamasını güncelle (PDF varsa ekle)
      String finalDescription = _descriptionController.text.trim();
      if (pdfUrl != null) {
        finalDescription += '\n\nEkli PDF Dosyası: $pdfUrl';
      }

      // 5. Adım: Ticket Bilgilerini Güncelle
      final missingPartsString = missingItems.isEmpty ? null : missingItems.join(', ');
      await supabase
          .from('tickets')
          .update({
            'title': _titleController.text.trim(),
            'description': finalDescription,
            'status': _status,
            'priority': _priority,
            'partner_id': _selectedPartnerId,
            'planned_date': _plannedDate?.toIso8601String(),
            'job_code': _jobCodeController.text.trim().isEmpty
                ? null
                : _jobCodeController.text.trim(),
            'device_model': _selectedDeviceModel,
            'plc_model': _selectedPlcModel,
            'hmi_brand': _selectedHmiBrand,
            'hmi_size': _selectedHmiSize,
            'aspirator_kw': _selectedAspiratorKw,
            'aspirator_brand': _selectedAspiratorBrand,
            'aspirator_model': _selectedAspiratorModel,
            'vant_kw': _selectedVantKw,
            'vant_brand': _selectedVantBrand,
            'vant_model': _selectedVantModel,
            'kompresor_kw_1': komp1Kw,
            'kompresor_kw_2': komp2Kw,
            'tandem': _selectedTandem,
            'isitici_kademe': heaterStage,
            'isitici_kw': heaterKw,
            'dx': _dx,
            'sulu_batarya': _suluBatarya,
            'karisim_damper': _karisimDamper,
            'nemlendirici': _nemlendirici,
            'rotor': _rotor,
            'brulor': _brulor,
            'missing_parts': missingPartsString,
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
    final bgColor = isDark ? const Color(0xFF0F172A) : _backgroundGrey;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final textColor = isDark ? Colors.white : _textDark;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _corporateNavy))
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
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isWide ? 3 : 1,
                            child: Column(
                              children: [
                                _buildContentCard(
                                  title: 'İŞ BİLGİLERİ',
                                  icon: Icons.work_outline,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(flex: 2, child: _buildTextField(controller: _titleController, label: 'İş Başlığı', isRequired: true)),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 1, child: _buildTextField(controller: _jobCodeController, label: 'İş Kodu')),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(controller: _descriptionController, label: 'İş Açıklaması', maxLines: 3),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _status,
                                            decoration: _inputDecoration('Durum'),
                                            items: [
                                              // Admin ve manager'lar için draft seçeneği
                                              if (_userRole == 'admin' || _userRole == 'manager')
                                                const DropdownMenuItem(value: 'draft', child: Text('Taslak (Gizli)')),
                                              const DropdownMenuItem(value: 'open', child: Text('Açık')),
                                              const DropdownMenuItem(value: 'panel_done_stock', child: Text('Panosu Yapıldı (Stok)')),
                                              const DropdownMenuItem(value: 'panel_done_sent', child: Text('Panosu Yapıldı (Gönderildi)')),
                                              const DropdownMenuItem(value: 'in_progress', child: Text('Serviste')),
                                              const DropdownMenuItem(value: 'done', child: Text('Tamamlandı')),
                                              const DropdownMenuItem(value: 'archived', child: Text('Arşivde')),
                                            ],
                                            onChanged: (val) => setState(() => _status = val!),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _priority,
                                            decoration: _inputDecoration('Öncelik'),
                                            items: const [
                                              DropdownMenuItem(value: 'low', child: Text('Düşük')),
                                              DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                              DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                                            ],
                                            onChanged: (val) => setState(() => _priority = val!),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDatePicker(),
                                    const SizedBox(height: 16),
                                    // PDF Seçici
                                    InkWell(
                                      onTap: _pickPdf,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                          color: _backgroundGrey.withOpacity(0.5),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Ek Döküman (PDF)',
                                                    style: TextStyle(fontSize: 11, color: _textLight),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _selectedPdf != null ? _selectedPdf!.name : 'Dosya seçilmedi',
                                                    style: TextStyle(
                                                      color: _selectedPdf != null ? _textDark : _textLight,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_selectedPdf != null)
                                              IconButton(
                                                icon: const Icon(Icons.close, color: Colors.red),
                                                onPressed: () => setState(() => _selectedPdf = null),
                                              )
                                            else
                                              const Icon(Icons.attach_file, color: _textLight),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildContentCard(
                                  title: 'MÜŞTERİ BİLGİLERİ',
                                  icon: Icons.person_outline,
                                  children: [
                                    // --- PARTNER FİRMA SEÇİMİ (Sadece Yetkililer İçin) ---
                                    if (_canAssignPartner && _partners.isNotEmpty) ...[
                                      _buildDropdown<int?>(
                                        label: 'Partner Firma Ataması (Opsiyonel)',
                                        value: _selectedPartnerId,
                                        items: [null, ..._partners.map((p) => p.id)],
                                        itemLabelBuilder: (val) {
                                          if (val == null) return 'Atama Yapılmayacak (Doğrudan Müşteri)';
                                          final p = _partners.firstWhere(
                                            (element) => element.id == val,
                                            orElse: () => Partner(id: -1, name: 'Bilinmeyen')
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
                                        Expanded(child: _buildTextField(controller: _customerNameController, label: 'Müşteri Adı / Firma', icon: Icons.business, isRequired: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildTextField(controller: _customerPhoneController, label: 'Telefon', icon: Icons.phone, keyboardType: TextInputType.phone)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(controller: _customerAddressController, label: 'Adres', icon: Icons.location_on_outlined, maxLines: 2),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          if (isWide) const SizedBox(width: 24),
                          
                          if (isWide)
                            Expanded(
                              flex: 2,
                              child: Column(
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
                      ),

                      if (!isWide) ...[
                        const SizedBox(height: 24),
                        _buildTechnicalInfoCard(),
                        const SizedBox(height: 24),
                        _buildHeaterInfoCard(),
                        const SizedBox(height: 24),
                        _buildHardwareFeaturesCard(),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('KAYDET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Widget _buildTechnicalInfoCard() {
    return _buildContentCard(
      title: 'CİHAZ TEKNİK VERİLERİ',
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
                items: const ['Havkon Cpx.139', 'Havkon Cpx.119', 'ABB FBX', 'ABB CBX', 'ABB CBT'],
                onChanged: (val) => setState(() => _selectedPlcModel = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('HMI Ekran Bilgileri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
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
        const Text('Aspiratör Sürücü Bilgileri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
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
                    _selectedAspiratorModel = null; // Marka değişince modeli sıfırla
                  });
                  await _loadModelsForBrand(val ?? '', true);
                },
              ),
            ),
            const SizedBox(width: 12),
            // Model seçimi (sadece modeller varsa göster)
            if (_selectedAspiratorBrand != null && _selectedAspiratorBrand != 'Diğer' && _availableAspiratorModels.isNotEmpty)
              Expanded(
                child: _buildDropdown(
                  label: 'Model',
                  value: _selectedAspiratorModel,
                  items: _availableAspiratorModels,
                  onChanged: (val) => setState(() => _selectedAspiratorModel = val),
                ),
              ),
            if (_selectedAspiratorBrand != null && _selectedAspiratorBrand != 'Diğer' && _availableAspiratorModels.isNotEmpty)
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
        const Text('Vantilatör Sürücü Bilgileri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
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
                    _selectedVantModel = null; // Marka değişince modeli sıfırla
                  });
                  await _loadModelsForBrand(val ?? '', false);
                },
              ),
            ),
            const SizedBox(width: 12),
            // Model seçimi (sadece modeller varsa göster)
            if (_selectedVantBrand != null && _selectedVantBrand != 'Diğer' && _availableVantModels.isNotEmpty)
              Expanded(
                child: _buildDropdown(
                  label: 'Model',
                  value: _selectedVantModel,
                  items: _availableVantModels,
                  onChanged: (val) => setState(() => _selectedVantModel = val),
                ),
              ),
            if (_selectedVantBrand != null && _selectedVantBrand != 'Diğer' && _availableVantModels.isNotEmpty)
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
        const Text('Kompresör Güçleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTextField(controller: _kompresor1KwController, label: 'Komp. 1', isNumeric: true, suffixText: 'kW')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(controller: _kompresor2KwController, label: 'Komp. 2', isNumeric: true, suffixText: 'kW')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Tandem',
                value: _selectedTandem,
                items: const ['yok', '1', '2'],
                itemLabels: const {'yok': 'Yok', '1': '1 Tandem', '2': '2 Tandem'},
                onChanged: (val) => setState(() => _selectedTandem = val!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHardwareFeaturesCard() {
    return _buildContentCard(
      title: 'DONANIM KONTROLÜ',
      icon: Icons.check_box_outlined,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFeatureChip('DX', _dx, (val) => setState(() => _dx = val)),
            _buildFeatureChip('Sulu Batarya', _suluBatarya, (val) => setState(() => _suluBatarya = val)),
            _buildFeatureChip('Karışım Damper', _karisimDamper, (val) => setState(() => _karisimDamper = val)),
            _buildFeatureChip('Nemlendirici', _nemlendirici, (val) => setState(() => _nemlendirici = val)),
            _buildFeatureChip('Rotor', _rotor, (val) => setState(() => _rotor = val)),
            _buildFeatureChip('Brülör', _brulor, (val) => setState(() => _brulor = val)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaterInfoCard() {
    return _buildContentCard(
      title: 'ISITICI BİLGİLERİ',
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
                    // Eğer Yok seçilirse diğer alanları sıfırla
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
                    '6': '6 Kademe'
                  },
                  onChanged: (val) => setState(() => _selectedIsiticiKademe = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _heaterKwController,
                  label: 'Isıtıcı Güç',
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

  Widget _buildContentCard({required String title, required IconData icon, required List<Widget> children}) {
    // Tema kontrolü
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final textColor = isDark ? Colors.white : _corporateNavy;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint, IconData? icon, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      labelStyle: const TextStyle(color: _textLight, fontSize: 13),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: _textLight) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _corporateNavy, width: 1.5)),
      filled: true,
      fillColor: _backgroundGrey.withOpacity(0.5),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, String? hint, IconData? icon, bool isRequired = false, int maxLines = 1, bool isNumeric = false, String? suffixText, TextInputType? keyboardType}) {
    // Tema kontrolü
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF334155) : _backgroundGrey.withOpacity(0.5);
    final textColor = isDark ? Colors.white : _textDark;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        labelStyle: const TextStyle(color: _textLight, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: _textLight) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      validator: isRequired ? (val) => (val == null || val.trim().isEmpty) ? '$label zorunludur.' : null : null,
    );
  }

  Widget _buildDropdown<T>({required String label, required T? value, required List<T> items, Map<T, String>? itemLabels, String Function(T)? itemLabelBuilder, required Function(T?) onChanged, bool isRequired = false}) {
    // Eğer gelen değer listede yoksa null yap (Hata vermemesi için)
    T? safeValue;
    if (value != null) {
      try {
        // Listede eşleşen değerin kendisini al (Referans güvenliği için)
        safeValue = items.firstWhere((item) => item == value);
      } catch (_) {
        safeValue = null;
      }
    }

    // Tema kontrolü - Dark mode uyumluluğu için
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    final fillColor = isDark ? const Color(0xFF334155) : _backgroundGrey.withOpacity(0.5);
    final textColor = isDark ? Colors.white : Colors.black;

    return DropdownButtonFormField<T>(
      isExpanded: true,
      dropdownColor: dropdownColor,
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textLight, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      items: items.toSet().map((item) {
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
          child: Text(
            text,
            style: TextStyle(color: textColor),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: isRequired
          ? (val) {
              if (val == null) return '$label seçilmelidir.';
              if (val is String && val.isEmpty) return '$label seçilmelidir.';
              return null;
            }
          : null,
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildFeatureChip(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: value ? _corporateNavy : Colors.transparent,
          border: Border.all(color: value ? _corporateNavy : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check : Icons.add, size: 16, color: value ? Colors.white : _textLight),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: value ? Colors.white : _textLight, fontWeight: value ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final dateText = _plannedDate == null ? 'Tarih seçilmedi' : '${_plannedDate!.day}.${_plannedDate!.month}.${_plannedDate!.year}';
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: _backgroundGrey.withOpacity(0.5)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _textLight, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Planlanan Tarih', style: TextStyle(fontSize: 11, color: _textLight)),
                const SizedBox(height: 2),
                Text(dateText, style: TextStyle(color: _plannedDate == null ? _textLight : _textDark, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: _textLight),
          ],
        ),
      ),
    );
  }
}
