// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'Presentation/features/cashier_page/data/cashier_datasource.dart';
import 'Presentation/features/cashier_page/domain/cashier_repository.dart';
import 'Presentation/features/cashier_page/viewmodel/cashier_viewmodel.dart';
import 'Presentation/splash screen/splash_screen.dart';
import 'core/services/firebase_options.dart';

Future<void> main() async {
  // شغّل كل حاجة في نفس الـ Zone علشان مايحصلش Zone mismatch
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // لوج أخطاء Flutter (build/layout/rendering)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('⚠️ FlutterError: ${details.exceptionAsString()}');
        if (details.stack != null) debugPrint(details.stack.toString());
      };

      // لوج لأي أخطاء async غير ممسوكة (Timers/Futures…)
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('⚠️ Uncaught async error: $error');
        debugPrint(stack.toString());
        return true; // مايقفلش الأب
      };

      // تهيئة Firebase مرة واحدة هنا فقط
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  CashierViewModel(CashierRepository(CashierDataSource())),
            ),
          ],
          child: const MyApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      debugPrint('⚠️ Zone error: $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home:
          SplashScreen(), // تأكد إن SplashScreen مفيهوش Firebase.initializeApp تاني
    );
  }
}
