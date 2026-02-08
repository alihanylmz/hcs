# Sidebar Widget

Production-ready, modüler ve responsive sidebar navigasyon komponenti.

## Kullanım

### Temel Kullanım (AppLayout ile)

```dart
import 'package:istakip_app/widgets/sidebar/app_layout.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.dashboard,
      userName: 'Ali Veli',
      userRole: 'admin',
      title: 'Dashboard',
      child: Center(
        child: Text('Sayfa içeriği'),
      ),
    );
  }
}
```

### Özellikler

- ✅ **Tam Responsive**: >1024px ekranlarda sidebar, daha küçük ekranlarda drawer
- ✅ Temiz, modüler kod yapısı
- ✅ Component-based mimari
- ✅ 8px grid system
- ✅ Material Design ve tema desteği (dark/light mode)
- ✅ Rol tabanlı menü görünürlüğü
- ✅ Otomatik navigasyon yönetimi
- ✅ Production-ready

### Dosyalar

- `app_layout.dart` - Ana layout wrapper (responsive)
- `sidebar.dart` - Desktop sidebar widget'ı
- `sidebar_item.dart` - Tekrar kullanılabilir menu item komponenti
- `sidebar_demo_page.dart` - Kullanım örneği

### Responsive Davranış

- **Desktop (>1024px)**: Sol tarafta sabit sidebar, sağ tarafta içerik
- **Mobile/Tablet (<1024px)**: Hamburger menü ile açılan drawer

### Sayfa Türleri

```dart
enum AppPage {
  ticketList,
  dashboard,
  stock,
  archived,
  profile,
  faultCodes,
  dailyActivities,
  reports,
  other,
}
```

### Özelleştirme

#### Yeni sayfa eklemek:
1. `AppPage` enum'una yeni değer ekle
2. `app_layout.dart`'ta `_getActiveMenuItem()` ve `_convertToDrawerPage()` metodlarını güncelle
3. `sidebar.dart`'ta yeni `SidebarItem` ekle
