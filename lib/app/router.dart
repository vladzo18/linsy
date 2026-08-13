import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/controllers/auth_state.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/room/presentation/pages/create_room_page.dart';
import '../features/room/presentation/pages/join_room_page.dart';
import '../features/room/presentation/pages/room_page.dart';
import '../features/auth/presentation/pages/email_confirmation_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      if (previous?.status != next.status) {
        refreshNotifier.value++;
      }
    },
  );

  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/',

    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final isLoginRoute = location == '/login';
      final isRegisterRoute = location == '/register';
      final isConfirmationRoute = location == '/auth/confirmed';

      final isAuthRoute =
        isLoginRoute ||
        isRegisterRoute ||
        isConfirmationRoute;

      switch (authState.status) {
        case AuthStatus.initializing:
        case AuthStatus.authenticating:
          return null;

        case AuthStatus.unauthenticated:
          return isAuthRoute ? null : '/login';

        case AuthStatus.authenticated:
          return isAuthRoute ? '/' : null;

        case AuthStatus.emailConfirmationRequired:
          return isRegisterRoute ? null : '/register';

        case AuthStatus.error:
          return isAuthRoute ? null : '/login';
      }
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),

      GoRoute(
        path: '/room/create',
        builder: (context, state) => const CreateRoomPage(),
      ),

      GoRoute(
        path: '/room/join',
        builder: (context, state) => const JoinRoomPage(),
      ),

      GoRoute(
        path: '/auth/confirmed',
        builder: (context, state) => const EmailConfirmationPage(),
      ),

      GoRoute(
        path: '/room/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;

          return RoomPage(
            roomId: roomId,
          );
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});