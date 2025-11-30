# Otomatik Bildirim Kurulumu

Bu proje, OneSignal kullanarak otomatik push bildirimleri gönderir.

## Gereksinimler

1. OneSignal hesabı ve uygulaması
2. OneSignal REST API Key

## Kurulum Adımları

### 1. OneSignal REST API Key Alma

1. [OneSignal Dashboard](https://app.onesignal.com/)'a giriş yapın
2. Uygulamanızı seçin
3. **Settings** > **Keys & IDs** bölümüne gidin
4. **REST API Key** değerini kopyalayın

### 2. .env Dosyasına Ekleme

Proje kök dizinindeki `.env` dosyasına şu satırı ekleyin:

```env
ONESIGNAL_REST_API_KEY=your_rest_api_key_here
```

**Örnek:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-key
ONESIGNAL_REST_API_KEY=YjA5YzE2YzAtYjE5ZC00YzY5LWI5YjAtYjE5YzE2YzAtYjE5ZC00
```

### 3. OneSignal App ID

OneSignal App ID zaten `lib/main.dart` dosyasında yapılandırılmış:
```dart
OneSignal.initialize("faeed989-8a81-4fe0-9c73-2eb9ed2144a7");
```

## Otomatik Bildirimler

Sistem şu durumlarda otomatik bildirim gönderir:

### 1. Yeni İş Emri Oluşturulduğunda
- **Ne zaman:** Yeni bir ticket oluşturulduğunda
- **Kime:** Tüm kullanıcılar
- **Mesaj:** "Yeni iş emri oluşturuldu: [İş Kodu]"

### 2. İş Emri Durumu Değiştiğinde
- **Ne zaman:** Ticket durumu güncellendiğinde
- **Kime:** Tüm kullanıcılar
- **Mesaj:** "[İş Kodu] iş emrinin durumu '[Eski Durum]' → '[Yeni Durum]' olarak güncellendi"

### 3. Not Eklendiğinde
- **Ne zaman:** Ticket'a yeni bir not eklendiğinde
- **Kime:** Tüm kullanıcılar
- **Mesaj:** "[Kullanıcı Adı], [İş Kodu] iş emrine not ekledi"

### 4. Öncelik Değiştiğinde
- **Ne zaman:** Ticket önceliği güncellendiğinde
- **Kime:** Tüm kullanıcılar
- **Mesaj:** "[İş Kodu] iş emrinin önceliği '[Eski Öncelik]' → '[Yeni Öncelik]' olarak güncellendi"

## Bildirim Servisi Kullanımı

### Manuel Bildirim Gönderme

```dart
import 'package:istakip_app/services/notification_service.dart';

final notificationService = NotificationService();

// Tüm kullanıcılara bildirim gönder
await notificationService.sendNotificationToAll(
  title: "Başlık",
  message: "Mesaj içeriği",
  data: {"custom_key": "custom_value"},
);

// Belirli kullanıcılara bildirim gönder
await notificationService.sendNotificationToUsers(
  playerIds: ["player-id-1", "player-id-2"],
  title: "Başlık",
  message: "Mesaj içeriği",
);
```

## Sorun Giderme

### Bildirimler Gönderilmiyor

1. `.env` dosyasında `ONESIGNAL_REST_API_KEY` değerinin doğru olduğundan emin olun
2. OneSignal Dashboard'da uygulamanızın aktif olduğunu kontrol edin
3. Konsol loglarını kontrol edin (hata mesajları görünecektir)

### API Key Hatası

Eğer şu hatayı görüyorsanız:
```
⚠️ OneSignal REST API Key bulunamadı. .env dosyasına ONESIGNAL_REST_API_KEY ekleyin.
```

`.env` dosyasını kontrol edin ve REST API Key'i ekleyin.

## Notlar

- Bildirimler asenkron olarak gönderilir, hata olsa bile ana işlem devam eder
- Bildirim gönderme hataları konsola yazdırılır ancak kullanıcıya gösterilmez
- Tüm bildirimler şu anda tüm kullanıcılara gönderilir (segmentasyon eklenebilir)

