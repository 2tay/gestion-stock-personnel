import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/utils/formatters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cible tablette : l'application est conçue et testée en paysage.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  // Données de localisation nécessaires aux dates et nombres en français.
  await initializeDateFormatting(Formatters.locale);

  await configureDependencies();

  runApp(const ProviderScope(child: GestionStockApp()));
}
