import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // Eklendi
import 'package:flutter_svg/flutter_svg.dart'; // Eklendi
import '../services/stock_service.dart'; // StockService eklendi
import '../services/notification_service.dart'; // Bildirim servisi
import '../services/user_service.dart'; // Kullanıcı servisi

class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, this.deviceType});

  final String? deviceType;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  // --- SABİTLER VE AYARLAR ---
  static const Color _corporateNavy = Color(0xFF0F172A);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);
  static const Color _surfaceWhite = Colors.white;
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textLight = Color(0xFF64748B);

  // Listeler artık StockService'den alınıyor
  final StockService _stockService = StockService();
  List<String> _availableDriveBrands = []; // Veritabanından yüklenen markalar
  
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobCodeController = TextEditingController();
  // _aspiratorKwController ve _vantKwController kaldırıldı (artık dropdown)
  final _kompresor1KwController = TextEditingController();
  final _kompresor2KwController = TextEditingController();
  final _heaterKwController = TextEditingController(); // Yeni: Isıtıcı kW
  
  // Jet Fan / Otopark Sistemi İçin Yeni Controller'lar
  // _zoneCountController kaldırıldı, yerine _selectedZoneCount ve _zoneFanCounts kullanılacak
  final _jetFanCountController = TextEditingController();
  // _bidirectionalFanCountController kaldırıldı
  // _inverterCountController kaldırıldı
  final _inverterBrandController = TextEditingController(); // Manuel giriş veya Dropdown olabilir
  
  // Jet Fan Dinamik Listeleri
  int _selectedZoneCount = 0;
  final List<TextEditingController> _zoneFanCountControllers = [];

  int _smokeFanCount = 0;
  List<Map<String, dynamic>> _smokeFans = []; // [{'brand': 'Danfoss', 'kw': 5.5}, ...]
  
  int _freshFanCount = 0;
  List<Map<String, dynamic>> _freshFans = [];
  
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

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDriveBrands();
    
    // Teknisyenler iş açamaz - kontrol et
    _checkUserPermission();
    
    if (widget.deviceType == 'santral') {
      _selectedDeviceModel = 'Klima Santrali';
    } else if (widget.deviceType == 'jet_fan') {
      _selectedDeviceModel = 'Jet Fan';
    } else if (widget.deviceType == 'other') {
      _selectedDeviceModel = 'Diğer / Arıza';
    }
  }
  
  Future<void> _loadDriveBrands() async {
    try {
      final brands = await _stockService.getBrandsByCategory('Sürücü');
      // Sabit listeyi de ekle
      final allBrands = {...StockService.driveBrands, ...brands}.toList();
      if (mounted) {
        setState(() {
          _availableDriveBrands = allBrands;
        });
      }
    } catch (e) {
      // Hata durumunda sabit listeyi kullan
      if (mounted) {
        setState(() {
          _availableDriveBrands = StockService.driveBrands;
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
            _selectedAspiratorModel = null; // Marka değişince modeli sıfırla
          } else {
            _availableVantModels = models;
            _selectedVantModel = null; // Marka değişince modeli sıfırla
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

  Future<void> _checkUserPermission() async {
    final userService = UserService();
    final profile = await userService.getCurrentUserProfile();
    
    if (profile != null && (profile.role == 'technician' || profile.role == 'pending')) {
      // Teknisyen veya onay bekleyen kullanıcılar iş açamaz
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teknisyenler yeni iş emri oluşturamaz.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
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
    // _zoneCountController.dispose();
    for (var c in _zoneFanCountControllers) {
      c.dispose();
    }
    _jetFanCountController.dispose();
    // _bidirectionalFanCountController.dispose();
    // _inverterCountController.dispose();
    _inverterBrandController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
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
  
  int? _parseInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // 1) Müşteri oluştur
      final customerInsert = await supabase
          .from('customers')
          .insert({
            'name': _customerNameController.text.trim(),
            'address': _customerAddressController.text.trim(),
            'phone': _customerPhoneController.text.trim(),
            'note': null,
          })
          .select()
          .maybeSingle();

      if (customerInsert == null) {
        throw Exception('Müşteri oluşturulamadı.');
      }

      final customerId = customerInsert['id'];

      final komp1Kw = _parseDouble(_kompresor1KwController.text);
      final komp2Kw = _parseDouble(_kompresor2KwController.text);
      // Isıtıcı verilerini hazırla
      final heaterKw = (_heaterExists == 'Var') ? _parseDouble(_heaterKwController.text) : null;
      final heaterStage = (_heaterExists == 'Var') ? _selectedIsiticiKademe : 'yok'; 
      
      // Jet Fan Verileri
      final zoneCount = _selectedZoneCount;
      // Zone detaylarını al
      final List<Map<String, dynamic>> zoneDetails = [];
      for (int i = 0; i < _zoneFanCountControllers.length; i++) {
        zoneDetails.add({
          'zone_no': i + 1,
          'fan_count': _parseInt(_zoneFanCountControllers[i].text) ?? 0,
        });
      }

      final jetFanCount = _parseInt(_jetFanCountController.text);
      // bidirectCount artık kullanılmıyor
      // inverterCount artık kullanılmıyor
      final inverterBrand = _inverterBrandController.text.trim().isEmpty ? null : _inverterBrandController.text.trim();

      // Jet Fan Detay JSON Hazırlığı
      final Map<String, dynamic> jetfanDetails = {
        'zone_details': zoneDetails,
        'smoke_fans': _smokeFans,
        'fresh_fans': _freshFans,
      };

      String? pdfUrl;

      // PDF Yükleme İşlemi
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
          // PDF yüklenemese bile iş emri açılsın mı? 
          // Kullanıcıya hata gösterip duralım şimdilik.
          throw Exception('PDF yüklenirken hata oluştu: $e. (Lütfen "ticket-files" adında bir bucket olduğundan emin olun)');
        }
      }

      // 2) Ticket oluştur
      String finalDescription = _descriptionController.text.trim();
      if (pdfUrl != null) {
        finalDescription += '\n\nEkli PDF Dosyası: $pdfUrl';
      }

      final ticketInsert = await supabase.from('tickets').insert({
        'title': _titleController.text.trim(),
        'description': finalDescription,
        'customer_id': customerId,
        'priority': 'normal',
        'status': 'open',
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
        'vant_kw': _selectedVantKw,
        'vant_brand': _selectedVantBrand,
        'kompresor_kw_1': komp1Kw,
        'kompresor_kw_2': komp2Kw,
        'tandem': _selectedTandem,
        'isitici_kademe': heaterStage, // Güncellendi: Mantıksal kontrol eklendi
        'isitici_kw': heaterKw,        // Güncellendi: Mantıksal kontrol eklendi
        'dx': _dx,
        'sulu_batarya': _suluBatarya,
        'karisim_damper': _karisimDamper,
        'nemlendirici': _nemlendirici,
        'rotor': _rotor,
        'brulor': _brulor,
        'zone_count': zoneCount,
        'jetfan_count': jetFanCount,
        'bidirectional_jetfan_count': null, // Artık kullanılmıyor
        'inverter_count': null, // Artık kullanılmıyor
        'inverter_brand': inverterBrand,
        'jetfan_details': jetfanDetails,
      }).select().single();

      final ticketId = ticketInsert['id'];

      // --- STOKTAN DÜŞME VE EKSİK KONTROLÜ ---
      try {
        final stockService = StockService();
        final List<String> missingItems = [];

        // 1. Standart Kontroller (Jet Fan dışındakiler veya ortaklar)
        final standardMissing = await stockService.processTicketStockUsage(
          plcModel: _selectedPlcModel,
          aspiratorBrand: _selectedAspiratorBrand,
          aspiratorModel: _selectedAspiratorModel,
          aspiratorKw: _selectedAspiratorKw,
          vantBrand: _selectedVantBrand,
          vantModel: _selectedVantModel,
          vantKw: _selectedVantKw,
          hmiBrand: _selectedHmiBrand,
          hmiSize: _selectedHmiSize,
        );
        missingItems.addAll(standardMissing);

        // 2. Jet Fan Dinamik Stok Düşümü
        if (widget.deviceType == 'jet_fan') {
           final jetFanMissing = await stockService.processJetFanStockUsage(
             smokeFans: _smokeFans,
             freshFans: _freshFans,
           );
           missingItems.addAll(jetFanMissing);
        }

        // Eğer eksik varsa ticket'a kaydet
        if (missingItems.isNotEmpty) {
          await supabase
            .from('tickets')
            .update({'missing_parts': missingItems.join(', ')})
            .eq('id', ticketId);
        }
      } catch (stockErr) {
        debugPrint('Stok düşme hatası (Kritik değil, işlem devam ediyor): $stockErr');
      }
      // ---------------------------

      // --- BİLDİRİM GÖNDERME ---
      try {
        final notificationService = NotificationService();
        final userService = UserService();
        final currentUser = await userService.getCurrentUserProfile();
        final userName = currentUser?.fullName ?? 'Kullanıcı';
        
        await notificationService.notifyTicketCreated(
          ticketId: ticketId.toString(),
          ticketTitle: _titleController.text.trim(),
          jobCode: _jobCodeController.text.trim().isEmpty 
              ? null 
              : _jobCodeController.text.trim(),
          createdBy: userName,
        );
      } catch (notifErr) {
        debugPrint('Bildirim gönderme hatası (Kritik değil, işlem devam ediyor): $notifErr');
      }
      // ---------------------------

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Hata: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // --- ARAYÜZ (BUILD METODU) ---

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : _backgroundGrey;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite;
    // Metin renkleri: Dark mode'da beyaz, Light mode'da koyu gri/siyah
    final textColor = isDark ? Colors.white : _textDark; 
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        iconTheme: IconThemeData(color: textColor), // İkon rengi
        leadingWidth: 80,
        leading: Row(
          children: [
            const BackButton(),
            SvgPicture.asset('assets/images/log.svg', width: 24, height: 24),
          ],
        ),
        title: Text(
          'YENİ İŞ EMRİ',
          style: TextStyle(
            color: textColor, // Başlık rengi
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                          const Icon(Icons.error_outline, color: Colors.red),
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

                  // --- ÜST BÖLÜM: İŞ VE MÜŞTERİ BİLGİLERİ ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isWide ? 3 : 1,
                        child: Column(
                          children: [
                            // İŞ BİLGİLERİ KARTI
                            _buildContentCard(
                              title: 'İŞ BİLGİLERİ',
                              icon: Icons.work_outline,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  hint: 'Yapılacak işlemlerin detayları...',
                                  maxLines: 3,
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
                            
                            // MÜŞTERİ BİLGİLERİ KARTI
                            _buildContentCard(
                              title: 'MÜŞTERİ BİLGİLERİ',
                              icon: Icons.person_outline,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _customerNameController,
                                        label: 'Müşteri Adı / Firma',
                                        icon: Icons.business,
                                        isRequired: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _customerPhoneController,
                                        label: 'Telefon',
                                        icon: Icons.phone,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _customerAddressController,
                                  label: 'Adres',
                                  icon: Icons.location_on_outlined,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      if (isWide && widget.deviceType != 'other') const SizedBox(width: 24),
                      
                      if (isWide && widget.deviceType != 'other')
                        Expanded(
                          flex: 2,
                          child: widget.deviceType == 'jet_fan'
                          ? _buildJetFanInfoCard()
                          : Column(
                            children: [
                              _buildTechnicalInfoCard(),
                              const SizedBox(height: 24),
                              _buildHeaterInfoCard(), // Yeni: Isıtıcı Kartı
                              const SizedBox(height: 24),
                              _buildHardwareFeaturesCard(),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Mobil görünüm için teknik detayları alta al
                  if (!isWide && widget.deviceType != 'other') ...[
                    const SizedBox(height: 24),
                    if (widget.deviceType == 'jet_fan')
                       _buildJetFanInfoCard()
                    else ...[
                      _buildTechnicalInfoCard(),
                      const SizedBox(height: 24),
                      _buildHeaterInfoCard(), 
                      const SizedBox(height: 24),
                      _buildHardwareFeaturesCard(),
                    ]
                  ],

                  const SizedBox(height: 40),

                  // --- KAYDET BUTONU ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corporateNavy,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
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

  Widget _buildJetFanInfoCard() {
    // 0-15 arası seçim listesi
    final countOptions = List.generate(16, (index) => index);
    
    // 1-15 Zone Seçimi (0 olamaz, en az 1 olabilir ama opsiyonel olsun diye 0-15 koyuyoruz)
    final zoneOptions = List.generate(16, (index) => index);

    return _buildContentCard(
      title: 'JET FAN SİSTEM BİLGİLERİ',
      icon: Icons.wind_power,
      children: [
        // ÜST BÖLÜM: Genel Sayılar
        Row(
          children: [
            Expanded(
              child: _buildDropdown<int>(
                label: 'Zone Sayısı',
                value: _selectedZoneCount,
                items: zoneOptions,
                onChanged: (val) {
                  setState(() {
                    _selectedZoneCount = val ?? 0;
                    // Controller listesini güncelle
                     if (_selectedZoneCount > _zoneFanCountControllers.length) {
                        for (int i = _zoneFanCountControllers.length; i < _selectedZoneCount; i++) {
                          _zoneFanCountControllers.add(TextEditingController());
                        }
                      } else {
                        // Fazlalıkları dispose et ve listeden çıkar
                        for (int i = _zoneFanCountControllers.length - 1; i >= _selectedZoneCount; i--) {
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
        
        // DİNAMİK ZONE LİSTESİ
        if (_zoneFanCountControllers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Zone Bazlı Fan Sayıları', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
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
                    label: '${index + 1}. Zone Jetfan Sayısı',
                    isNumeric: true,
                 ),
               );
            },
          ),
        ],

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // --- DUMAN TAHLİYE FANLARI ---
        Text(
          'Duman Tahliye Fanları',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _corporateNavy),
        ),
        const SizedBox(height: 8),
        _buildDropdown<int>(
          label: 'Duman Tahliye Fanı Sayısı',
          value: _smokeFanCount,
          items: countOptions,
          onChanged: (val) {
            setState(() {
              _smokeFanCount = val ?? 0;
              // Listeyi güncelle
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
                    // Sıra No
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    // Marka
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'İnverter Markası',
                        value: _smokeFans[index]['brand'],
                        items: StockService.driveBrands,
                        onChanged: (val) {
                           setState(() => _smokeFans[index]['brand'] = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // kW
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

        // --- TAZE HAVA FANLARI ---
        Text(
          'Taze Hava Fanları',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _corporateNavy),
        ),
        const SizedBox(height: 8),
         _buildDropdown<int>(
          label: 'Taze Hava Fanı Sayısı',
          value: _freshFanCount,
          items: countOptions,
          onChanged: (val) {
            setState(() {
              _freshFanCount = val ?? 0;
              // Listeyi güncelle
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
                    // Sıra No
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    // Marka
                    Expanded(
                      child: _buildDropdown<String>(
                        label: 'İnverter Markası',
                        value: _freshFans[index]['brand'],
                        items: StockService.driveBrands,
                        onChanged: (val) {
                           setState(() => _freshFans[index]['brand'] = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // kW
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
        // En alttaki İnverter Sayısı alanı kaldırıldı.
        // Eğer genel marka seçimi isteniyorsa buraya eklenebilir ama talep edilmedi.
      ],
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
                isRequired: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: 'PLC Marka/Model',
                value: _selectedPlcModel,
                items: const ['Havkon Cpx.139', 'Havkon Cpx.119', 'ABB FBX', 'ABB CBX', 'ABB CBT'], // Güncellendi
                onChanged: (val) => setState(() => _selectedPlcModel = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // HMI Bölümü
        const Text(
          'HMI Ekran Bilgileri',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight),
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
        
        // Aspiratör Bölümü
        const Text(
          'Aspiratör Sürücü Bilgileri',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Marka',
                value: _selectedAspiratorBrand,
                items: _availableDriveBrands.isEmpty ? StockService.driveBrands : _availableDriveBrands,
                onChanged: (val) async {
                  setState(() => _selectedAspiratorBrand = val);
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<dynamic>( // dynamic yapıldı
                label: 'Güç (kW)',
                value: _selectedAspiratorKw,
                items: [null, ...StockService.kwValues], // Yok (null) eklendi
                itemLabelBuilder: (val) => val == null ? 'Yok' : '$val kW',
                onChanged: (val) => setState(() => _selectedAspiratorKw = val),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Vantilatör Bölümü
        const Text(
          'Vantilatör Sürücü Bilgileri',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Marka',
                value: _selectedVantBrand,
                items: _availableDriveBrands.isEmpty ? StockService.driveBrands : _availableDriveBrands,
                onChanged: (val) async {
                  setState(() => _selectedVantBrand = val);
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<dynamic>( // dynamic yapıldı
                label: 'Güç (kW)',
                value: _selectedVantKw,
                items: [null, ...StockService.kwValues], // Yok (null) eklendi
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight),
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
            const SizedBox(width: 12),
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
                    '1': '1 Kademe', '2': '2 Kademe', 
                    '3': '3 Kademe', '4': '4 Kademe',
                    '5': '5 Kademe', '6': '6 Kademe'
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

  // --- TASARIM YARDIMCILARI ---

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
      validator: isRequired
          ? (val) {
              if (val == null || val.trim().isEmpty) {
                return '$label alanı zorunludur.';
              }
              return null;
            }
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
    // Dropdown arka plan rengi: Dark mode'da koyu gri, Light mode'da beyaz
    final dropdownColor = isDark ? const Color(0xFF1E293B) : _surfaceWhite; 
    // Input alanı dolgu rengi: Dark mode'da daha açık gri, Light mode'da çok açık gri
    final fillColor = isDark ? const Color(0xFF334155) : _backgroundGrey.withOpacity(0.5);
    
    // Seçili metin rengi: 
    final textColor = isDark ? Colors.white : Colors.black;

    return DropdownButtonFormField<T>(
      isExpanded: true,
      dropdownColor: dropdownColor, 
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textLight, fontSize: 13),
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
        fillColor: fillColor, // Dinamik dolgu rengi
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
            style: TextStyle(color: textColor), // Metin rengi
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
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500), // Seçili öğe rengi
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
          border: Border.all(
            color: value ? _corporateNavy : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check : Icons.add,
              size: 16,
              color: value ? Colors.white : _textLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : _textLight,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final dateText = _plannedDate == null
        ? 'Tarih seçilmedi'
        : '${_plannedDate!.day}.${_plannedDate!.month}.${_plannedDate!.year}';

    return InkWell(
      onTap: _pickDate,
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
            const Icon(Icons.calendar_today_outlined, color: _textLight, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planlanan Tarih',
                  style: TextStyle(fontSize: 11, color: _textLight),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: TextStyle(
                    color: _plannedDate == null ? _textLight : _textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
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
