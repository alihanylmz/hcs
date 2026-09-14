import 'package:flutter/foundation.dart';

/// Sidebar'in daraltilmis/genisletilmis durumunu oturum boyunca hafizada
/// tutar. `MainNavigationShell` tek bir State icinde yasadigi icin (Is
/// Takip'teki gibi sayfa basina yeniden kurulmuyor) burasi teknik olarak
/// bir widget alaninda da tutulabilirdi, ama Is Takip ile ayni deseni
/// kullanmak icin ayni sekilde bir singleton'da tutuluyor.
class NavShellState {
  NavShellState._();

  static final ValueNotifier<bool> railExpanded = ValueNotifier<bool>(true);

  static void toggleRail() {
    railExpanded.value = !railExpanded.value;
  }
}
