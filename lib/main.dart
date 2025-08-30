// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'Presentation/features/cashier_page/data/cashier_datasource.dart';
import 'Presentation/features/cashier_page/domain/cashier_repository.dart';
import 'Presentation/features/cashier_page/viewmodel/cashier_viewmodel.dart';
import 'Presentation/splash screen/splash_screen.dart';

import 'core/services/firebase_options.dart';
// import 'data/datasources/seedProducts.dart';
// import 'data/datasources/seed_blends.dart';
// import 'data/datasources/seedDrinks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // await seedProducts();
  // await seedBlends();
  // await seedDrinks();

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
