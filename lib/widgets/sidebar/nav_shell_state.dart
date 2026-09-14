import 'package:flutter/foundation.dart';

/// Sidebar'in daraltilmis/genisletilmis durumunu oturum boyunca hafizada
/// tutar. `Sidebar` her sayfa gecisinde (`pushReplacement`) yeniden
/// olusturuldugu icin bu durum widget state'inde degil, burada - kucuk bir
/// singleton'da - tutuluyor; boylece kullanici rayi bir kez daraltinca
/// baska bir sayfaya gecince tekrar acilmis gibi gormuyor.
///
/// Kalici depolamaya (SharedPreferences) gerek yok - uygulama yeniden
/// baslatildiginda varsayilan (genisletilmis) hale donmesi yeterli.
class NavShellState {
  NavShellState._();

  static final ValueNotifier<bool> railExpanded = ValueNotifier<bool>(true);

  static void toggleRail() {
    railExpanded.value = !railExpanded.value;
  }

  // Her sayfa kendi kullanici profilini (ad/rol) ayri ayri, asenkron
  // olarak yukluyor. `pushReplacement` her sayfa gecisinde Sidebar'i
  // sifirdan kurdugu icin, profil yuklenene kadar gecen o kisa surede
  // (rol henuz null iken) rol bazli menu ogeleri (Stok, Yonetici Panosu
  // vb.) bir an icin gizli goruntuleniyor, sonra profil gelince aniden
  // beliriyordu - kullanicinin "once farkli menu geliyor, 1 saniye sonra
  // degisiyor" dedigi "kirli" gorunum buydu. Cozum: en son bilinen
  // ad/rolu burada, oturum boyunca hafizada tutup her sayfanin ilk
  // render'inda hemen kullaniyoruz; asenkron yukleme sadece sessizce
  // dogrulama/guncelleme yapiyor, ekranda ani bir degisiklik olmuyor.
  static String? cachedUserName;
  static String? cachedUserRole;
}
