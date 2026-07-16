import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app_shell.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  await initializeDateFormatting('tr_TR');
  final bootstrap = await AppBootstrap.initialize();
  runApp(AppShell(bootstrap: bootstrap));
}
