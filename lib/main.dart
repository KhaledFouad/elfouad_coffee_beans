import 'dart:async';
import 'dart:ui' as ui;
import 'package:elfouad_coffee_beans/Presentation/features/cashier_page/view/cashier_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show
        GlobalMaterialLocalizations,
        GlobalWidgetsLocalizations,
        GlobalCupertinoLocalizations;
import 'package:provider/provider.dart';
import 'Presentation/features/cashier_page/data/cashier_datasource.dart';
import 'Presentation/features/cashier_page/domain/cashier_repository.dart';
import 'Presentation/features/cashier_page/viewmodel/cashier_viewmodel.dart';
// import 'Presentation/splash screen/splash_screen.dart';
import 'core/services/firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
        if (details.stack != null) debugPrint(details.stack.toString());
      };

      ui.PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
            debugPrint('Uncaught async error: $error');
            debugPrint(stack.toString());
            return true;
          };

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
      debugPrint('Zone error: $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: const CashierHome(),
    );
  }
}
