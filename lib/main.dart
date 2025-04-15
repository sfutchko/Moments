import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:provider/provider.dart'; // Import Provider
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

import 'firebase_options.dart'; // Import generated options
import 'src/services/auth_service.dart'; // Import AuthService
import 'src/services/database_service.dart'; // Import DatabaseService
// Import the wrapper
import 'src/features/authentication/presentation/auth_wrapper.dart';
// TODO: Import home screen (e.g., HomeScreen) if needed directly by main routes later

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use generated options
  );
  // Removed TODO comment
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Wrap with MultiProvider to provide services
    return MultiProvider(
      providers: [
        // Provide the AuthService instance
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // Provide the auth state changes stream
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null, // Or FirebaseAuth.instance.currentUser if needed immediately
        ),
        // Database Provider
        Provider<DatabaseService>(
           create: (_) => DatabaseService(),
        ),
        // TODO: Add other providers (e.g., DatabaseService)
      ],
      child: MaterialApp(
        title: 'Moments for Mom', // Updated App Title
        themeMode: ThemeMode.dark, // Force dark theme for now based on design
        theme: _buildTheme(Brightness.light), // Define light theme (optional)
        darkTheme: _buildTheme(Brightness.dark), // Define dark theme
        // TODO: Replace placeholder home with an AuthWrapper/Landing Page
        home: const AuthWrapper(), // Use the imported AuthWrapper
      ),
    );
  }

  // Helper function to build theme data
  ThemeData _buildTheme(Brightness brightness) {
    var baseTheme = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    // --- Refined Colors for Dark Theme --- 
    Color primaryColor = const Color(0xFF6A5ACD); // Example: SlateBlue like purple
    Color scaffoldBackgroundColor = Colors.black;
    Color cardColor = const Color(0xFF2C2C2E); // Slightly lighter dark grey
    Color buttonBackgroundColor = primaryColor; // Use primary color for button background
    Color buttonTextColor = Colors.white; // White text on button
    Color headingTextColor = Colors.white;
    Color bodyTextColor = Colors.grey[500]!; // Slightly lighter grey for body text
    Color subtleTextColor = Colors.grey[600]!; // For less important text
    Color accentColor = Colors.blue; // Example accent for links/text buttons if needed

    return baseTheme.copyWith(
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: headingTextColor,
          fontSize: 22, // Slightly larger AppBar title
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: headingTextColor),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0), // More pronounced rounding
        ),
         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjust margins
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackgroundColor, // Primary color background
          foregroundColor: buttonTextColor, // White text
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32), // Adjust padding
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
       // Style FloatingActionButton specifically if needed (can differ from ElevatedButton)
       floatingActionButtonTheme: FloatingActionButtonThemeData(
         backgroundColor: buttonBackgroundColor,
         foregroundColor: buttonTextColor,
         extendedTextStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
       ),
      textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            foregroundColor: accentColor, // Use accent for text buttons
         )
      ),
      inputDecorationTheme: InputDecorationTheme(
         filled: true,
         fillColor: cardColor,
         border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
         ),
         hintStyle: TextStyle(color: subtleTextColor), // Use subtle color for hints
         labelStyle: TextStyle(color: bodyTextColor), // Style for labels if used
      ),
      listTileTheme: ListTileThemeData( // Style ListTiles used for moments
         iconColor: headingTextColor,
         titleTextStyle: TextStyle(color: headingTextColor, fontSize: 18, fontWeight: FontWeight.w600),
         subtitleTextStyle: TextStyle(color: bodyTextColor, fontSize: 14),
         shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(20.0)), // Match card rounding if needed
      ),
      textTheme: baseTheme.textTheme.copyWith(
        headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
          color: headingTextColor,
          fontSize: 24, // Adjust size as needed
          fontWeight: FontWeight.bold,
        ),
         bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
           color: bodyTextColor, 
           fontSize: 16, // Adjust size
         ),
         bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
           color: subtleTextColor, // For less prominent text
           fontSize: 14,
         ),
         labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: buttonTextColor, // Ensure button text color is applied
            fontSize: 16
         )
      ).apply(
         bodyColor: bodyTextColor,
         displayColor: headingTextColor,
      ),
      colorScheme: baseTheme.colorScheme.copyWith(
         brightness: brightness,
         primary: primaryColor,
         onPrimary: buttonTextColor,
         secondary: accentColor, // Define secondary/accent
         onSecondary: Colors.white,
         surface: cardColor,
         onSurface: headingTextColor,
         background: scaffoldBackgroundColor,
         onBackground: headingTextColor,
         error: Colors.redAccent,
         onError: Colors.white,
      ),
    );
  }
}
