# Sidebar Entegrasyon Kılavuzu

## ✅ Tamamlanan Entegrasyonlar

### 1. DashboardPage ✓
- AppLayout ile sarmalandı
- Responsive tasarım aktif
- Desktop'ta sidebar, mobilde drawer gösteriliyor

### 2. TicketListPage ✓
- AppLayout ile sarmalandı
- Tüm özellikler korundu
- Bildirimler ve PDF menüleri çalışıyor

## 📋 Diğer Sayfalara Entegrasyon Adımları

Herhangi bir sayfayı sidebar sistemiyle entegre etmek için:

### Adım 1: Import'ları Ekleyin

```dart
import '../widgets/sidebar/app_layout.dart';
```

Eğer AppDrawer kullanıyorsanız kaldırın:
```dart
// Kaldırın:
// import '../widgets/app_drawer.dart';
```

### Adım 2: Scaffold Yerine AppLayout Kullanın

**Eski Kod:**
```dart
class MyPage extends StatelessWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: AppDrawerPage.myPage,
        userName: userName,
        userRole: userRole,
      ),
      appBar: AppBar(
        title: Text('Sayfa Başlığı'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: // İçerik
      floatingActionButton: // FAB
    );
  }
}
```

**Yeni Kod:**
```dart
class MyPage extends StatelessWidget {
  // _scaffoldKey'e gerek yok
  
  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.myPage, // Enum değerini belirtin
      userName: userName,
      userRole: userRole,
      title: 'Sayfa Başlığı',
      actions: [
        // AppBar action'ları buraya
      ],
      floatingActionButton: // FAB buraya
      child: // İçerik buraya (Scaffold body içeriği)
    );
  }
}
```

### Adım 3: AppPage Enum'una Ekleyin (Gerekirse)

Eğer yeni bir sayfa ekliyorsanız, `app_layout.dart` dosyasında:

1. `AppPage` enum'una yeni değeri ekleyin:
```dart
enum AppPage {
  ticketList,
  dashboard,
  myNewPage, // YENİ
  ...
}
```

2. `_getActiveMenuItem()` metoduna ekleyin:
```dart
String _getActiveMenuItem() {
  switch (currentPage) {
    case AppPage.myNewPage:
      return 'my_new_page';
    ...
  }
}
```

3. `_convertToDrawerPage()` metoduna ekleyin:
```dart
AppDrawerPage _convertToDrawerPage() {
  switch (currentPage) {
    case AppPage.myNewPage:
      return AppDrawerPage.myNewPage;
    ...
  }
}
```

### Adım 4: Sidebar'a Menü Öğesi Ekleyin (Gerekirse)

`sidebar.dart` dosyasında, menü listesine yeni öğeyi ekleyin:

```dart
SidebarItem(
  icon: Icons.my_icon,
  label: 'Menü Başlığı',
  isActive: activeMenuItem == 'my_new_page',
  activeColor: activeColor,
  iconColor: iconColor,
  textColor: textColor,
  onTap: () => _navigate(context, const MyNewPage()),
),
```

## 🎯 Örnekler

### Basit Sayfa (AppBar olmadan)

```dart
return AppLayout(
  currentPage: AppPage.profile,
  userName: userName,
  userRole: userRole,
  title: 'Profilim',
  showAppBar: false, // AppBar'ı gizle
  child: ProfileContent(),
);
```

### Popup Menu ile Sayfa

```dart
return AppLayout(
  currentPage: AppPage.dashboard,
  userName: userName,
  userRole: userRole,
  title: 'Dashboard',
  actions: [
    PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      onSelected: (value) {
        // Handle menu actions
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'action1', child: Text('Action 1')),
        PopupMenuItem(value: 'action2', child: Text('Action 2')),
      ],
    ),
  ],
  child: DashboardContent(),
);
```

## 📱 Responsive Davranış

- **Desktop (>1024px)**: Sidebar sol tarafta sabit, içerik sağ tarafta
- **Mobile/Tablet (<1024px)**: Hamburger menü, AppDrawer açılır

Kodda özel responsive kontrol yapmaya gerek yok, AppLayout otomatik halleder.

## ⚙️ AppLayout Parametreleri

| Parametre | Tip | Zorunlu | Açıklama |
|-----------|-----|---------|----------|
| `child` | Widget | ✓ | Sayfa içeriği |
| `currentPage` | AppPage | ✓ | Aktif sayfa |
| `title` | String | ✓ | AppBar başlığı |
| `userName` | String? | - | Kullanıcı adı |
| `userRole` | String? | - | Kullanıcı rolü |
| `actions` | List<Widget>? | - | AppBar action'ları |
| `floatingActionButton` | Widget? | - | FAB widget'ı |
| `onProfileReload` | VoidCallback? | - | Profil güncellendiğinde callback |
| `showAppBar` | bool | - | AppBar göster/gizle (default: true) |

## 🚀 Entegre Edilecek Sayfalar

- [ ] StockOverviewPage
- [ ] ArchivedTicketsPage
- [ ] ProfilePage
- [ ] FaultCodesPage
- [ ] DailyActivitiesPage
- [ ] ReportsPage
- [ ] UserManagementPage
- [ ] PartnerManagementPage
- [ ] TicketDetailPage (opsiyonel)
- [ ] NewTicketPage (opsiyonel)

## 💡 İpuçları

1. **_scaffoldKey kullanımı**: AppLayout ile artık gerek yok, silebilirsiniz
2. **AppBar leading**: Otomatik hamburger menü eklenir, custom leading gerekmez
3. **Drawer**: AppDrawer otomatik kullanılır, manuel eklemeye gerek yok
4. **Tema değişimi**: Tüm sayfalarda otomatik çalışır
5. **Rol bazlı menü**: Sidebar zaten role göre menüleri gösterir/gizler
