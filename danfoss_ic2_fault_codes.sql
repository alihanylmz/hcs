-- Danfoss iC2 Hata Kodları Ekleme SQL Scripti
-- Bu kodu Supabase SQL editöründe çalıştırarak hata kodlarını ekleyebilirsiniz.

INSERT INTO public.fault_codes (code, fault_name, possible_causes, device_brand, device_model)
VALUES
  ('2', 'Canlı sıfır hatası (Live zero error)', 'Terminal 33 veya 34 üzerindeki sinyal, Parametre P9.5.2.3, P9.5.2.5, P9.5.3.3 veya P9.5.3.5''de ayarlanan değerin %50''sinden az.', 'Danfoss', 'iC2'),
  ('3', 'Motor yok (No motor)', 'Sürücü çıkışına bağlı motor yok.', 'Danfoss', 'iC2'),
  ('4', 'Şebeke faz kaybı (Mains phase loss)', 'Besleme tarafında eksik faz veya çok yüksek voltaj dengesizliği. Besleme voltajını kontrol edin.', 'Danfoss', 'iC2'),
  ('7', 'DC aşırı gerilim (DC overvoltage)', 'DC bara gerilimi sınırı aşıyor.', 'Danfoss', 'iC2'),
  ('8', 'DC düşük gerilim (DC undervoltage)', 'DC bara gerilimi, düşük voltaj uyarısı sınırının altına düştü.', 'Danfoss', 'iC2'),
  ('9', 'İnvertör aşırı yükü (Inverter overloaded)', 'Uzun süre %100''den fazla yüklenme.', 'Danfoss', 'iC2'),
  ('10', 'Motor ETR aşırı sıcaklığı (Motor ETR overtemperature)', 'Uzun süre %100''den fazla yüklenme nedeniyle motor çok ısındı.', 'Danfoss', 'iC2'),
  ('11', 'Motor termistör aşırı sıcaklığı (Motor thermistor overtemperature)', 'Termistör veya termistör bağlantısı kopuk veya motor çok sıcak.', 'Danfoss', 'iC2'),
  ('12', 'Tork limiti (Torque limit)', 'Tork, parametre P5.10.1 Motor Tork Limiti veya P5.10.2 Rejeneratif Tork Limiti''nde ayarlanan değeri aşıyor.', 'Danfoss', 'iC2'),
  ('13', 'Aşırı akım (Overcurrent)', 'İnvertör tepe akım sınırı aşıldı. Güç kablolarının motor terminallerine yanlış bağlanıp bağlanmadığını kontrol edin.', 'Danfoss', 'iC2'),
  ('14', 'Toprak hatası (Ground fault)', 'Çıkış fazlarından toprağa deşarj (kısa devre) var.', 'Danfoss', 'iC2'),
  ('16', 'Kısa devre (Short circuit)', 'Motorda veya motor terminallerinde kısa devre.', 'Danfoss', 'iC2'),
  ('17', 'Kontrol kelimesi zaman aşımı (Control word timeout)', 'Sürücü ile iletişim yok.', 'Danfoss', 'iC2'),
  ('25', 'Fren direnci kısa devresi (Brake resistor short-circuited)', 'Fren direnci kısa devre yapmış, bu nedenle fren fonksiyonu kesildi.', 'Danfoss', 'iC2'),
  ('26', 'Fren aşırı yükü (Brake overload)', 'Son 120 saniyede fren direncine iletilen güç limiti aşıyor. Hızı düşürün veya rampa süresini uzatın.', 'Danfoss', 'iC2'),
  ('27', 'Fren kıyıcı kısa devresi (Brake IGBT/Brake chopper short-circuited)', 'Fren transistörü kısa devre yapmış, bu nedenle fren fonksiyonu kesildi.', 'Danfoss', 'iC2'),
  ('28', 'Fren kontrolü (Brake check)', 'Fren direnci bağlı değil veya çalışmıyor.', 'Danfoss', 'iC2'),
  ('30', 'U fazı kaybı (U phase loss)', 'Motor U fazı eksik. Fazı kontrol edin.', 'Danfoss', 'iC2'),
  ('31', 'V fazı kaybı (V phase loss)', 'Motor V fazı eksik. Fazı kontrol edin.', 'Danfoss', 'iC2'),
  ('32', 'W fazı kaybı (W phase loss)', 'Motor W fazı eksik. Fazı kontrol edin.', 'Danfoss', 'iC2'),
  ('36', 'Şebeke hatası (Mains failure)', 'Sürücü besleme voltajı, P2.3.7 Güç Kaybı Kontrol Limiti''nden düşük.', 'Danfoss', 'iC2'),
  ('38', 'Dahili hata (Internal fault)', 'Yerel Danfoss tedarikçisi ile iletişime geçin.', 'Danfoss', 'iC2'),
  ('40', 'Aşırı yük T15 (Overload T15)', 'Terminal 15''e bağlı yükü kontrol edin veya kısa devre bağlantısını kaldırın.', 'Danfoss', 'iC2'),
  ('46', 'Kapı sürücü voltaj hatası (Gate drive voltage fault)', 'Kapı sürücü voltaj hatası.', 'Danfoss', 'iC2'),
  ('47', '24 V besleme düşük (24 V supply low)', '24 V DC beslemesi aşırı yüklü olabilir.', 'Danfoss', 'iC2'),
  ('50', 'AMA kalibrasyon başarısız (AMA calibration failed)', 'Kalibrasyon hatası oluştu.', 'Danfoss', 'iC2'),
  ('51', 'AMA kontrol Unom ve Inom (AMA check Unom and Inom)', 'Motor voltajı ve/veya motor akımı için yanlış ayar.', 'Danfoss', 'iC2'),
  ('52', 'AMA düşük Inom (AMA low Inom)', 'Motor akımı çok düşük. Ayarları kontrol edin.', 'Danfoss', 'iC2'),
  ('53', 'AMA büyük motor (AMA big motor)', 'Motor güç boyutu AMA çalışması için çok büyük.', 'Danfoss', 'iC2'),
  ('54', 'AMA küçük motor (AMA small motor)', 'Motor güç boyutu AMA çalışması için çok küçük.', 'Danfoss', 'iC2'),
  ('55', 'AMA parametre aralığı (AMA parameter range)', 'Motor parametre değerleri kabul edilebilir aralığın dışında. AMA çalışmıyor.', 'Danfoss', 'iC2'),
  ('56', 'AMA kesintiye uğradı (AMA interrupt)', 'AMA kesintiye uğradı.', 'Danfoss', 'iC2'),
  ('57', 'AMA zaman aşımı (AMA timeout)', 'AMA zaman aşımı.', 'Danfoss', 'iC2'),
  ('58', 'AMA dahili hata (AMA internal)', 'Yerel tedarikçi ile iletişime geçin.', 'Danfoss', 'iC2'),
  ('59', 'Akım limiti (Current limit)', 'Sürücü aşırı yüklendi.', 'Danfoss', 'iC2'),
  ('60', 'Harici kilitleme (External Interlock)', 'Harici kilitleme etkinleştirildi.', 'Danfoss', 'iC2'),
  ('61', 'Geri besleme hatası (Feedback error)', 'Geri besleme hatası.', 'Danfoss', 'iC2'),
  ('63', 'Mekanik fren düşük (Mechanical brake low)', 'Gerçek motor akımı, başlatma gecikme süresi penceresinde fren bırakma akımını aşmadı.', 'Danfoss', 'iC2'),
  ('69', 'Güç kartı sıcaklığı (Power card temp)', 'Güç kartı kesme sıcaklığı üst limiti aştı.', 'Danfoss', 'iC2'),
  ('80', 'Sürücü varsayılan değere başlatıldı (Drive initialized to default value)', 'Tüm parametre ayarları varsayılan ayarlara döndürüldü.', 'Danfoss', 'iC2'),
  ('87', 'Otomatik DC fren (Auto DC brake)', 'IT şebekesinde sürücü boştayken DC voltajı çok yüksek (400V üniteler için 830V üstü).', 'Danfoss', 'iC2'),
  ('95', 'Yük kaybı algılandı (Lost load detected)', 'Yük kaybı algılandı.', 'Danfoss', 'iC2'),
  ('99', 'Kilitli rotor (Locked rotor)', 'Rotor bloke olmuş.', 'Danfoss', 'iC2'),
  ('126', 'Motor dönüyor (Motor rotating)', 'AMA yapılırken PM motor dönüyor.', 'Danfoss', 'iC2'),
  ('127', 'Geri EMF çok yüksek (Back EMF too high)', 'PM motorun geri EMF''si başlamadan önce çok yüksek.', 'Danfoss', 'iC2'),
  ('Err. 89', 'Parametre salt okunur (Parameter read only)', 'Parametreler değiştirilemez.', 'Danfoss', 'iC2'),
  ('Err. 95', 'Çalışırken yapılamaz (Not while running)', 'Parametreler yalnızca motor durdurulduğunda değiştirilebilir.', 'Danfoss', 'iC2'),
  ('Err. 96', 'Yanlış şifre girildi (A wrong password was entered)', 'Şifre korumalı bir parametreyi değiştirirken yanlış şifre kullanıldığında oluşur.', 'Danfoss', 'iC2');






