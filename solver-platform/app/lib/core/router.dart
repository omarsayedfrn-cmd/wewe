import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/engine/engine_detail_screen.dart';
import '../screens/engine/solving_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/support/chat_screen.dart';

/// App router with auth redirect logic.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final currentPath = state.uri.path;

      // While auth is loading, stay on splash
      if (authState is AsyncLoading && currentPath == '/splash') {
        return null;
      }

      // Read directly from the client: it is updated synchronously by the
      // auth call, avoiding any provider propagation delay during sign-in.
      final user = ref.read(supabaseProvider).auth.currentUser;
      final isLoggedIn = user != null;

      // Not logged in → login
      if (!isLoggedIn) {
        if (currentPath == '/login') return null;
        return '/login';
      }

      // Logged in but on login → check profile for onboarding
      if (currentPath == '/login' || currentPath == '/splash') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/engine/:code',
        builder: (_, state) => EngineDetailScreen(
          engineCode: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/engine/:code/solve',
        builder: (_, state) => SolvingScreen(
          engineCode: state.pathParameters['code']!,
          trialChapters:
              int.tryParse(state.uri.queryParameters['trial'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (_, __) => const SupportScreen(),
      ),
      GoRoute(
        path: '/support/:threadId',
        builder: (_, state) => ChatScreen(
          threadId: state.pathParameters['threadId']!,
        ),
      ),
    ],
  );
});
