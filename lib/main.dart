import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:provider/provider.dart'; // Import Provider
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:firebase_app_check/firebase_app_check.dart'; // Import App Check
import 'package:flutter/foundation.dart'; // Import kDebugMode
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'firebase_options.dart'; // Import generated options
import 'src/services/auth_service.dart'; // Import AuthService
import 'src/services/database_service.dart'; // Import DatabaseService
import 'src/services/storage_service.dart'; // Import StorageService
import 'src/services/invitation_service.dart'; // Import InvitationService
import 'src/services/deep_link_service.dart'; // Import DeepLinkService
// Import the wrapper
import 'src/features/authentication/presentation/auth_wrapper.dart';
import 'src/features/invitation/presentation/join_project_screen.dart'; // Import JoinProjectScreen
// TODO: Import home screen (e.g., HomeScreen) if needed directly by main routes later

// Use global flag to disable texture mipmaps for Impeller
bool _initialUriIsHandled = false;

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use generated options
  );
  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    // Conditionally set providers based on kDebugMode
    androidProvider: kDebugMode 
        ? AndroidProvider.debug 
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode 
        ? AppleProvider.debug 
        : AppleProvider.appAttest,
    // TODO: Configure web provider if needed (replace placeholder)
    // webProvider: kDebugMode 
    //   ? ReCaptchaV3Provider('recaptcha-v3-site-key') 
    //   : ReCaptchaEnterpriseProvider('your-recaptcha-enterprise-site-key'), 
  );
  // Removed TODO comment

  // Create service instances
  final authService = AuthService();
  final databaseService = DatabaseService();
  final storageService = StorageService();
  final deepLinkService = DeepLinkService(
    navigatorKey: GlobalKey<NavigatorState>(),
    onMomentIdReceived: (String momentId) {
      print('Received moment ID: $momentId');
      // Navigation will be handled in the MyApp widget
    },
  );

  // Initialize deep link handling
  await deepLinkService.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Provide the AuthService instance
        Provider<AuthService>(
          create: (_) => authService,
        ),
        // Provide the auth state changes stream
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null, // Or FirebaseAuth.instance.currentUser if needed immediately
        ),
        // Database Provider
        Provider<DatabaseService>(
           create: (_) => databaseService,
        ),
        // Provide StorageService
        Provider<StorageService>(
          create: (_) => storageService,
        ),
        // Provide InvitationService
        Provider<InvitationService>(
          create: (_) => InvitationService(),
        ),
        Provider<DeepLinkService>(
          create: (_) => deepLinkService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initDeepLinkHandling(DeepLinkService deepLinkService) async {
  // Initialize the deep link service
  await deepLinkService.initialize();
  print('Deep link handling initialized');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final InvitationService _invitationService = InvitationService();
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    // No need for extra initialization, handled in main
  }
  
  void _handleDynamicLink(Uri deepLink) {
    print('Got deep link: $deepLink');
    
    final deepLinkService = Provider.of<DeepLinkService>(context, listen: false);
    deepLinkService.handleUri(deepLink);
    
    // Handle join project links
    if (deepLink.pathSegments.contains('join')) {
      final String? projectId = deepLink.queryParameters['projectId'];
      final String? inviterId = deepLink.queryParameters['inviterId'];
      
      if (projectId != null) {
        // Navigate to the JoinProjectScreen
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => JoinProjectScreen(
                projectId: projectId,
                inviterId: inviterId,
              ),
            ),
          );
        });
      }
    }
  }

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
        // Provide StorageService
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        // Provide InvitationService
        Provider<InvitationService>(
          create: (_) => InvitationService(),
        ),
      ],
      child: MaterialApp(
        title: 'Moments for Mom', // Updated App Title
        navigatorKey: _navigatorKey, // Add navigator key for deep link navigation
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
