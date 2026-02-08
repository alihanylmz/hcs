# 🔄 TEMİZ BAŞLANGIÇ REHBERİ

## ⚠️ ÖNEMLİ: Yedek Alın!

Önce mevcut çalışmanızı yedekleyin (isterseniz):

```powershell
# Proje klasöründe
git add .
git commit -m "Yedek - reset öncesi"
```

---

## 🗑️ ESKİ DOSYALARI TEMİZLEYİN

Şu dosyaları **SİLİN** (ben yenilerini oluşturacağım):

### Flutter Dosyaları:
```
lib/models/team.dart
lib/models/board.dart
lib/models/kanban_card.dart
lib/models/card_event.dart
lib/models/card_comment.dart
lib/models/app_notification.dart

lib/services/team_service.dart
lib/services/board_service.dart
lib/services/card_service.dart
lib/services/analytics_service.dart
lib/services/notification_service_kanban.dart

lib/pages/my_teams_page.dart
lib/pages/team_home_page.dart
lib/pages/board_page.dart
lib/pages/card_detail_page.dart
lib/pages/team_members_page.dart
lib/pages/team_analytics_page.dart
lib/pages/completed_cards_page.dart
lib/pages/team_notifications_page.dart
```

**NOT:** `main.dart`, `app_drawer.dart`, `sidebar.dart` güncellenecek (silmeyin).

---

## ✅ BEN ŞİMDİ TEMİZ DOSYALARI OLUŞTURUYORUM

Bekleyin, tüm dosyaları oluşturacağım...
