import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // Eklendi
import 'package:flutter_svg/flutter_svg.dart'; // Eklendi
import '../services/stock_service.dart'; // StockService eklendi

class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key});

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
  
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobCodeController = TextEditingController();
  // _aspiratorKwController ve _vantKwController kaldırıldı (artık dropdown)
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
  double? _selectedAspiratorKw;
  
  String? _selectedVantBrand;
  double? _selectedVantKw;

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
      final heaterStage = (_heaterExists == 'Var') ? _selectedIsiticiKademe : 'yok'; // Veritabanında 'yok' string olarak tutuluyor olabilir

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
      }).select().single();

      final ticketId = ticketInsert['id'];

      // --- STOKTAN DÜŞME VE EKSİK KONTROLÜ ---
      try {
        final stockService = StockService();
        final missingItems = await stockService.processTicketStockUsage(
          plcModel: _selectedPlcModel,
          aspiratorBrand: _selectedAspiratorBrand,
          aspiratorKw: _selectedAspiratorKw,
          vantBrand: _selectedVantBrand,
          vantKw: _selectedVantKw,
          hmiBrand: _selectedHmiBrand,
          hmiSize: _selectedHmiSize,
        );

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
                      
                      if (isWide) const SizedBox(width: 24),
                      
                      if (isWide)
                        Expanded(
                          flex: 2,
                          child: Column(
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
                  if (!isWide) ...[
                    const SizedBox(height: 24),
                    _buildTechnicalInfoCard(),
                    const SizedBox(height: 24),
                    _buildHeaterInfoCard(), // Yeni: Isıtıcı Kartı
                    const SizedBox(height: 24),
                    _buildHardwareFeaturesCard(),
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
                items: StockService.driveBrands,
                onChanged: (val) => setState(() => _selectedAspiratorBrand = val),
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
                items: StockService.driveBrands,
                onChanged: (val) => setState(() => _selectedVantBrand = val),
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
