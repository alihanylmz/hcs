-- Danfoss FC102 Hata Kodları Ekleme SQL Scripti
-- Bu kodu Supabase SQL editöründe çalıştırarak hata kodlarını ekleyebilirsiniz.

INSERT INTO public.fault_codes (code, fault_name, possible_causes, device_brand, device_model)
VALUES
  ('2', 'Canlı sıfır hatası (Live zero error)', 'Terminal 53 veya 54 üzerindeki sinyal, Parametre 6-10 veya 6-12''de ayarlanan değerin %50''sinden az.', 'Danfoss', 'FC102'),
  ('4', 'Şebeke faz kaybı (Mains phase loss)', 'Besleme tarafında eksik faz veya çok yüksek voltaj dengesizliği. Besleme voltajını kontrol edin.', 'Danfoss', 'FC102'),
  ('7', 'DC aşırı gerilim (DC overvoltage)', 'DC bara gerilimi sınırı aşıyor.', 'Danfoss', 'FC102'),
  ('8', 'DC düşük gerilim (DC undervoltage)', 'DC bara gerilimi, düşük voltaj uyarısı sınırının altına düştü.', 'Danfoss', 'FC102'),
  ('9', 'İnvertör aşırı yükü (Inverter overload)', 'Uzun süre %100''den fazla yüklenme.', 'Danfoss', 'FC102'),
  ('10', 'Motor ETR aşırı sıcaklığı (Motor ETR overtemperature)', 'Uzun süre %100''den fazla yüklenme nedeniyle motor çok ısındı.', 'Danfoss', 'FC102'),
  ('11', 'Motor termistör aşırı sıcaklığı (Motor thermistor overtemperature)', 'Termistör veya termistör bağlantısı kopuk.', 'Danfoss', 'FC102'),
  ('12', 'Tork limiti (Torque limit)', 'Tork, parametre 4-16 veya 4-17''de ayarlanan değeri aşıyor.', 'Danfoss', 'FC102'),
  ('13', 'Aşırı akım (Overcurrent)', 'İnvertör tepe akım sınırı aşıldı.', 'Danfoss', 'FC102'),
  ('14', 'Toprak hatası (Ground fault)', 'Çıkış fazlarından toprağa deşarj (kısa devre) var.', 'Danfoss', 'FC102'),
  ('16', 'Kısa devre (Short circuit)', 'Motorda veya motor terminallerinde kısa devre.', 'Danfoss', 'FC102'),
  ('17', 'Kontrol kelimesi zaman aşımı (Control word timeout)', 'Sürücü ile iletişim yok.', 'Danfoss', 'FC102'),
  ('25', 'Fren direnci kısa devresi (Brake resistor short-circuited)', 'Fren direnci kısa devre yapmış, bu nedenle fren fonksiyonu kesildi.', 'Danfoss', 'FC102'),
  ('27', 'Fren kıyıcı kısa devresi (Brake chopper short-circuited)', 'Fren transistörü kısa devre yapmış, bu nedenle fren fonksiyonu kesildi.', 'Danfoss', 'FC102'),
  ('28', 'Fren kontrolü (Brake check)', 'Fren direnci bağlı değil veya çalışmıyor.', 'Danfoss', 'FC102'),
  ('29', 'Güç kartı aşırı sıcaklığı (Power board over temp)', 'Soğutucu kesme sıcaklığına ulaşıldı.', 'Danfoss', 'FC102'),
  ('30', 'Motor fazı U eksik (Motor phase U missing)', 'Motor U fazı eksik. Fazı kontrol edin.', 'Danfoss', 'FC102'),
  ('31', 'Motor fazı V eksik (Motor phase V missing)', 'Motor V fazı eksik. Fazı kontrol edin.', 'Danfoss', 'FC102'),
  ('32', 'Motor fazı W eksik (Motor phase W missing)', 'Motor W fazı eksik. Fazı kontrol edin.', 'Danfoss', 'FC102'),
  ('38', 'Dahili hata (Internal fault)', 'Yerel Danfoss tedarikçisi ile iletişime geçin.', 'Danfoss', 'FC102'),
  ('44', 'Toprak hatası (Ground fault)', 'Çıkış fazlarından toprağa deşarj var.', 'Danfoss', 'FC102'),
  ('47', 'Kontrol voltaj hatası (Control voltage fault)', '24 V DC beslemesi aşırı yüklü.', 'Danfoss', 'FC102'),
  ('51', 'AMA kontrol Unom ve Inom (AMA check Unom and Inom)', 'Motor voltajı ve/veya motor akımı için yanlış ayar.', 'Danfoss', 'FC102'),
  ('52', 'AMA düşük Inom (AMA low Inom)', 'Motor akımı çok düşük. Ayarları kontrol edin.', 'Danfoss', 'FC102'),
  ('59', 'Akım limiti (Current limit)', 'Sürücü aşırı yüklendi.', 'Danfoss', 'FC102'),
  ('63', 'Mekanik fren düşük (Mechanical brake low)', 'Gerçek motor akımı, başlatma gecikme süresi penceresinde fren bırakma akımını aşmadı.', 'Danfoss', 'FC102'),
  ('80', 'Sürücü varsayılan değere başlatıldı (Drive initialized to default value)', 'Tüm parametre ayarları varsayılan ayarlara döndürüldü.', 'Danfoss', 'FC102'),
  ('84', 'Sürücü ve LCP arasındaki bağlantı koptu (The connection between drive and LCP is lost)', 'LCP ve sürücü arasında iletişim yok.', 'Danfoss', 'FC102'),
  ('85', 'Tuş devre dışı (Key disabled)', 'Parametre grubu 0-4* LCP''ye bakın.', 'Danfoss', 'FC102'),
  ('86', 'Kopyalama başarısız (Copy fail)', 'Sürücüden LCP''ye veya LCP''den sürücüye kopyalama sırasında hata oluştu.', 'Danfoss', 'FC102'),
  ('87', 'LCP verisi geçersiz (LCP data invalid)', 'LCP hatalı veri içeriyorsa veya LCP''ye veri yüklenmediyse kopyalama sırasında oluşur.', 'Danfoss', 'FC102'),
  ('88', 'LCP verisi uyumlu değil (LCP data not compatible)', 'Yazılım sürümleri arasında büyük fark olan sürücüler arasında veri taşınırken oluşur.', 'Danfoss', 'FC102'),
  ('89', 'Parametre salt okunur (Parameter read only)', 'Salt okunur bir parametreye yazmaya çalışıldığında oluşur.', 'Danfoss', 'FC102'),
  ('90', 'Parametre veritabanı meşgul (Parameter database busy)', 'LCP ve RS485 bağlantısı aynı anda parametreleri güncellemeye çalışıyor.', 'Danfoss', 'FC102'),
  ('91', 'Parametre değeri bu modda geçerli değil (Parameter value is not valid in this mode)', 'Bir parametreye geçersiz bir değer yazmaya çalışıldığında oluşur.', 'Danfoss', 'FC102'),
  ('92', 'Parametre değeri sınırları aşıyor (Parameter value exceeds the minimum/maximum limits)', 'Aralık dışında bir değer ayarlanmaya çalışıldığında oluşur.', 'Danfoss', 'FC102'),
  ('nw run', 'Çalışırken yapılamaz (Not while running)', 'Parametreler yalnızca motor durdurulduğunda değiştirilebilir.', 'Danfoss', 'FC102'),
  ('Err.', 'Yanlış şifre girildi (A wrong password was entered)', 'Şifre korumalı bir parametreyi değiştirirken yanlış şifre kullanıldığında oluşur.', 'Danfoss', 'FC102');






