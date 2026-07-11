import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/leave_request_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/staff_provider.dart';
import 'screens/shared/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/leave_request_service.dart';
import 'services/notification_service.dart';
import 'services/restaurant_service.dart';
import 'services/shift_service.dart';

Future<void> main() async {
  // Necessario prima di qualsiasi chiamata asincrona che tocca i plugin
  // (qui: l'inizializzazione di Firebase) prima di runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handler delle notifiche in background: va registrato prima di runApp.
  NotificationService.registerBackgroundHandler();
  runApp(const ShiftFlowApp());
}

class ShiftFlowApp extends StatelessWidget {
  const ShiftFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider rende i Provider disponibili a tutta la UI sottostante.
    // Ogni Provider costruisce internamente il proprio Service: così i widget
    // vedono solo i Provider e non toccano mai direttamente i Service/Firebase.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService(), NotificationService()),
        ),
        ChangeNotifierProvider(create: (_) => ShiftProvider(ShiftService())),
        ChangeNotifierProvider(
          create: (_) => LeaveRequestProvider(LeaveRequestService()),
        ),
        ChangeNotifierProvider(
          create: (_) => StaffProvider(RestaurantService(), AuthService()),
        ),
      ],
      child: MaterialApp(
        title: 'ShiftFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Segue automaticamente il tema chiaro/scuro del sistema.
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}
