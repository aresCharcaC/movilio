import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:joya_express/core/network/api_client.dart';
import 'package:joya_express/data/datasources/auth_local_datasource.dart';
import 'package:joya_express/data/datasources/auth_remote_datasource.dart';
import 'package:joya_express/data/repositories_impl/auth_repository_impl.dart';
import 'package:joya_express/presentation/modules/auth/Driver/viewmodels/driver_auth_viewmodel.dart';
import 'package:joya_express/presentation/modules/auth/Driver/viewmodels/driver_home_viewmodel.dart';
import 'package:joya_express/presentation/modules/auth/Passenger/viewmodels/auth_viewmodel.dart';
import 'package:joya_express/presentation/modules/home/viewmodels/map_viewmodel.dart';
import 'package:joya_express/data/services/enhanced_vehicle_trip_service.dart';
import 'package:joya_express/core/di/service_locator.dart';
import 'package:joya_express/presentation/modules/home/viewmodels/ofertas_viewmodel.dart';
import 'package:joya_express/core/services/auth_initialization_service.dart';
import 'package:joya_express/data/services/driver_session_service.dart';
import 'package:provider/provider.dart';
import 'presentation/modules/routes/app_routes.dart';
import 'presentation/providers/ride_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Asegurarse de que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ========== CONFIGURACIÓN DE DEBUG COMPLETO ==========
  // Capturar todos los errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🔥 FLUTTER ERROR CAPTURADO:');
    print('Exception: ${details.exception}');
    print('Library: ${details.library}');
    print('Context: ${details.context}');
    print('Stack trace:');
    print(details.stack);
    print('==========================================');

    // En modo debug, también mostrar en pantalla roja
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // Capturar errores asincrónicos no manejados
  PlatformDispatcher.instance.onError = (error, stack) {
    print('🔥 ERROR ASÍNCRONO NO MANEJADO:');
    print('Error: $error');
    print('Stack trace:');
    print(stack);
    print('==========================================');
    return true;
  };
  // ===================================================

  // ========== INICIALIZAR DEPENDENCIAS INYECTADAS ==========
  print('🔧 Inicializando sistema de inyección de dependencias...');
  await initializeDependencies();
  diagnosticDependencies();
  print('✅ Sistema de inyección configurado');
  // =========================================================

  // ========== CONFIGURACIÓN MANUAL DE AUTH (LEGACY) ==========
  print('🚀 Iniciando Joya Express con autenticación REAL...');

  final apiClient = ApiClient();
  final remoteDataSource = AuthRemoteDataSource(apiClient: apiClient);
  final localDataSource = AuthLocalDataSource();

  final authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );

  print('✅ Repositorio de autenticación configurado (manual)');
  // ===========================================================

  // ========== INICIALIZACIÓN DE SERVICIOS DE RUTA ==========

  // =========================================================

  // ========== INICIALIZACIÓN DE AUTENTICACIÓN MEJORADA ==========
  print('🔐 Inicializando servicio de autenticación...');
  final authInitService = AuthInitializationService();
  final authInitResult = await authInitService.initializeAuth();

  print('🔍 Resultado de inicialización: $authInitResult');

  final authViewModel = AuthViewModel(authRepository: authRepository);

  // Solo cargar usuario si la inicialización indica que hay sesión activa
  if (authInitResult.isAuthenticated) {
    try {
      await authViewModel.loadCurrentUser();
      print('✅ Usuario actual cargado');
    } catch (e, stackTrace) {
      print('⚠️ Error cargando usuario actual: $e');
      print('Stack trace: $stackTrace');
    }
  }

  try {
    await authViewModel.initializeFromPersistedState();
    print('✅ Estado de autenticación inicializado');
  } catch (e, stackTrace) {
    print('⚠️ No hay estado previo de autenticación: $e');
    print('Stack trace: $stackTrace');
  }
  // ============================================================

  // ====================================================

  // ========== INICIAR APLICACIÓN ==========
  runApp(
    MultiProvider(
      providers: [
        // ========== PROVIDERS MANUALES (LEGACY) ==========
        // Provider de autenticación con repositorio real
        ChangeNotifierProvider.value(value: authViewModel),

        // Provider del mapa
        ChangeNotifierProvider(create: (_) => MapViewModel()),

        // DriverHomeViewModel (manual)
        ChangeNotifierProvider(create: (_) => DriverHomeViewModel()),
        // =================================================

        // ========== PROVIDERS CON INYECCIÓN DE DEPENDENCIAS ==========
        // DriverAuthViewModel usando service locator
        ChangeNotifierProvider<DriverAuthViewModel>(
          create: (_) {
            final viewModel = sl<DriverAuthViewModel>();
            // Inicializar de forma segura después de la construcción
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.initialize();
            });
            return viewModel;
          },
        ),

        // RideProvider usando service locator
        ChangeNotifierProvider<RideProvider>.value(value: sl<RideProvider>()),
        // OfertasViewModel usando service locator
        ChangeNotifierProvider<OfertasViewModel>.value(
          value: sl<OfertasViewModel>(),
        ),
        // =============================================================
      ],
      child: const MyApp(),
    ),
  );

  print('🎉 Joya Express iniciado correctamente');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _initialRoute = AppRoutes.welcome;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('🔄 Inicializando aplicación...');

      // Determinar la ruta inicial sin acceder al contexto durante build
      String initialRoute = AppRoutes.welcome;

      // Verificar estado de autenticación de conductor usando servicios directamente
      final hasActiveDriverSession =
          await DriverSessionService.hasActiveDriverSession();
      final isDriverModeActive =
          await DriverSessionService.isDriverModeActive();

      if (hasActiveDriverSession && isDriverModeActive) {
        print('🚀 Sesión de conductor activa detectada');
        initialRoute = AppRoutes.driverHome;
      } else {
        // Verificar sesión de usuario usando SharedPreferences directamente
        final prefs = await SharedPreferences.getInstance();
        final userSessionActive = prefs.getBool('user_session_active') ?? false;

        if (userSessionActive) {
          print('🚀 Sesión de usuario activa detectada');
          initialRoute = AppRoutes.home;
        } else {
          print('🚀 No hay sesiones activas, mostrando bienvenida');
          initialRoute = AppRoutes.welcome;
        }
      }

      if (mounted) {
        setState(() {
          _initialRoute = initialRoute;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Error inicializando aplicación: $e');
      if (mounted) {
        setState(() {
          _initialRoute = AppRoutes.welcome;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'Joya Express',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Joya Express',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Configuración adicional del tema
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: AppRoutes.routes[_initialRoute]!(context),
      routes: AppRoutes.routes,
      onGenerateRoute: (RouteSettings settings) {
        // Handle any route that's not defined in the routes map
        final String? name = settings.name;
        final WidgetBuilder? pageContentBuilder = AppRoutes.routes[name];

        if (pageContentBuilder != null) {
          return MaterialPageRoute<dynamic>(
            builder: pageContentBuilder,
            settings: settings,
          );
        }

        // If route is not found, return to welcome screen
        return MaterialPageRoute<dynamic>(
          builder: (context) => AppRoutes.routes[AppRoutes.welcome]!(context),
          settings: settings,
        );
      },
    );
  }
}
