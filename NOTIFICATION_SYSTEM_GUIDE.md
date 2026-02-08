# 🔔 BİLDİRİM SİSTEMİ - TAM KURULUM REHBERİ

## 📋 BİLDİRİM SENARYOLARITeam-based notification system kuruldu. İşte tüm özellikler:

### Otomatik Bildirimler (Database Trigger ile):
1. ✅ **Kart Atandı** → Atanan kişiye bildirim
2. ✅ **Yorum Yapıldı** → Kart sahibi + atanan kişiye
3. ✅ **Durum Değişti** → Atanan kişiye

### Zamanlanmış Bildirimler (Manuel/Cron ile):
4. ✅ **Açık İş Uyarısı** → 24+ saat DOING'de bekleyen işler
5. ✅ **Günlük Özet** → Her sabah 09:00'da takım raporu

---

## 🚀 KURULUM ADIMLARI

### 1️⃣ Supabase Migration

**Supabase Dashboard → SQL Editor:**

`migration_notifications_system.sql` dosyasının **TAMAMINI** çalıştırın.

Bu şunları oluşturur:
- ✅ `notifications` tablosu
- ✅ `user_push_tokens` tablosu (OneSignal için)
- ✅ Otomatik trigger'lar (kart atama, yorum, durum değişimi)
- ✅ Helper fonksiyonlar

---

### 2️⃣ Flutter Hot Reload

```powershell
R  # Full restart
```

---

### 3️⃣ Test Edin

**In-App Bildirimler:**
1. ✅ Drawer menü → **"Bildirimler"** sayfası
2. ✅ Bir kart oluşturun ve başkasına atayın
3. ✅ O kişi giriş yapınca bildirim görecek!

---

## 📱 ÖZELLİKLER

### In-App Bildirimler (Hazır!)
- ✅ **Bildirimler sayfası** (drawer'dan erişim)
- ✅ **Okunmamış badge** (kırmızı nokta)
- ✅ **Tümünü okundu işaretle** butonu
- ✅ **Renkli ikonlar** (bildirim tipine göre)
- ✅ **Tarih gösterimi**

### Bildirim Tipleri ve Renkleri:
- 🔵 **Kart Atandı** (Mavi)
- 🟣 **Yorum Yapıldı** (Mor)
- 🟢 **Durum Değişti** (Yeşil)
- 🔴 **Açık İş Uyarısı** (Kırmızı)
- 🟡 **Günlük Özet** (Turuncu)

---

## ⚙️ ZAMANLANMIŞ BİLDİRİMLER (Opsiyonel)

### A) pg_cron Extension Aktif Et

**Supabase Dashboard → Database → Extensions:**

`pg_cron` extension'ını **ENABLE** edin.

### B) Cron Job'ları Oluşturun

**SQL Editor'de:**

```sql
-- Her 6 saatte bir: Açık iş kontrolü
SELECT cron.schedule(
    'overdue-check',           -- Job adı
    '0 */6 * * *',            -- Her 6 saatte
    'SELECT send_overdue_notifications()'
);

-- Her sabah 09:00: Günlük özet
SELECT cron.schedule(
    'daily-summary',          -- Job adı
    '0 9 * * *',              -- Her gün 09:00
    'SELECT send_daily_summary()'
);
```

### C) Cron Job'ları Görüntüle

```sql
SELECT * FROM cron.job;
```

### D) Cron Job Sil (gerekirse)

```sql
SELECT cron.unschedule('overdue-check');
SELECT cron.unschedule('daily-summary');
```

---

## 🔔 ONESIGNAL PUSH NOTIFICATIONS (Opsiyonel)

OneSignal zaten projede var! Push notification eklemek için:

### 1. OneSignal External ID Kaydet

`lib/main.dart`'ta OneSignal init'ten sonra:

```dart
// OneSignal Player ID'yi Supabase'e kaydet
OneSignal.User.pushSubscription.addObserver((state) {
  final playerId = state.current.id;
  if (playerId != null) {
    NotificationServiceKanban()
        .savePlayerID(playerId, Platform.isAndroid ? 'android' : 'ios');
  }
});
```

### 2. Supabase Edge Function (Webhook)

Bildirim gönderme için Edge Function oluşturun.

**Örnek:** `supabase/functions/send-push/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

serve(async (req) => {
  const { user_id, title, message } = await req.json()
  
  // OneSignal API call
  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Basic YOUR_REST_API_KEY'
    },
    body: JSON.stringify({
      app_id: 'YOUR_APP_ID',
      include_external_user_ids: [user_id],
      headings: { en: title },
      contents: { en: message }
    })
  })
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

---

## 🎯 KULLANIM ÖRNEKLERİ

### Senaryo 1: Kart Atama
```
Ali → "Rapor hazırla" kartını Mehmet'e atar
   ↓
📱 Mehmet'e bildirim:
   "Size yeni bir kart atandı"
   "Ali size 'Rapor hazırla' kartını atadı"
```

### Senaryo 2: Yorum
```
Ayşe → "Rapor hazırla" kartına yorum yapar
   ↓
📱 Mehmet'e bildirim:
   "Kartınıza yorum yapıldı"
   "Ayşe 'Rapor hazırla' kartına yorum yaptı"
```

### Senaryo 3: Durum Değişimi
```
Ali → Mehmet'in kartını DONE yapar
   ↓
📱 Mehmet'e bildirim:
   "Kartınızın durumu değişti"
   "Ali 'Rapor hazırla' kartını DONE yaptı"
```

### Senaryo 4: Açık İş Uyarısı (Cron - 6 saatte bir)
```
"Tasarım mockup" kartı 30 saat DOING'de
   ↓
📱 Atanan kişiye:
   "Açık iş bekliyor"
   "'Tasarım mockup' kartı 30 saattir devam ediyor"
```

### Senaryo 5: Günlük Özet (Cron - Her sabah 09:00)
```
📱 Takım üyelerine:
   "Günlük Özet"
   "Satış Ekibi takımı: 5 yapılacak, 3 devam eden iş"
```

---

## 🎨 BİLDİRİMLER SAYFASI

**Drawer → Bildirimler:**

```
┌─────────────────────────────────────────┐
│ 🔔 Bildirimler    [Tümünü Okundu İşaretle]│
├─────────────────────────────────────────┤
│ 🔵 Size yeni bir kart atandı       •   │
│    Ali size "Rapor" kartını atadı       │
│    04 Şub 14:30                         │
├─────────────────────────────────────────┤
│ 🟣 Kartınıza yorum yapıldı             │
│    Ayşe "Tasarım" kartına yorum yaptı   │
│    04 Şub 12:15                         │
└─────────────────────────────────────────┘
```

**Özellikler:**
- ✅ Okunmamış → **Kalın, beyaz arka plan, mavi border**
- ✅ Okunmuş → **İnce, gri arka plan**
- ✅ **Renkli ikonlar** (bildirim tipine göre)
- ✅ **Kırmızı nokta** (okunmamış)

---

## 📊 PERFORMANS

**Optimize edildi:**
- ✅ Tek query ile bildirimler
- ✅ Realtime subscription (yeni bildirim gelince anında)
- ✅ Badge güncellemesi otomatik

---

## 🔧 GELİŞMİŞ AYARLAR

### Bildirim Tercihleri (Gelecek özellik)

```sql
-- Kullanıcı bildirim tercihlerini kaydetmek için:
CREATE TABLE notification_preferences (
    user_id uuid PRIMARY KEY,
    card_assigned boolean DEFAULT true,
    card_comment boolean DEFAULT true,
    card_status_changed boolean DEFAULT true,
    card_overdue boolean DEFAULT true,
    daily_summary boolean DEFAULT false
);
```

### Email Bildirimleri (İleride)

Supabase Edge Function ile email gönderimi.

---

## 📝 YAPMANIZ GEREKENLER

### ŞIMDI:
1. ✅ `migration_notifications_system.sql` → Supabase SQL Editor'de **RUN**
2. ✅ Terminal'de **R** (full restart)
3. ✅ Test edin:
   - Drawer → Bildirimler sayfası
   - Kart atayın → Bildirim gelsin
   - Yorum yapın → Bildirim gelsin

### İLERİDE (Opsiyonel):
1. ⏰ pg_cron enable → Zamanlanmış bildirimler
2. 🔔 OneSignal Edge Function → Push notifications
3. 📧 Email entegrasyonu

---

## 🎉 SONUÇ

Artık tam fonksiyonel bir bildirim sisteminiz var:
- ✅ **Gerçek zamanlı**
- ✅ **Otomatik trigger'lar**
- ✅ **Modern UI**
- ✅ **Zamanlanmış görevler**

Migration'ı çalıştırın ve test edin! 🚀
