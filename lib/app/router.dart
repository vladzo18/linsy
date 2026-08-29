import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/controllers/auth_state.dart';
import '../features/auth/presentation/pages/email_confirmation_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/room/presentation/pages/create_room_page.dart';
import '../features/room/presentation/pages/join_room_page.dart';
import '../features/room/presentation/pages/room_page.dart';
import 'session/app_session_controller.dart';
import 'session/app_session_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.status != next.status ||
        previous?.user?.id != next.user?.id) {
      refreshNotifier.value++;
    }
  });

  ref.listen<AppSessionState>(appSessionControllerProvider, (previous, next) {
    if (previous?.status != next.status || previous?.roomId != next.roomId) {
      refreshNotifier.value++;
    }
  });

  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/',

    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);

      final sessionState = ref.read(appSessionControllerProvider);

      final location = state.matchedLocation;

      final isLoginRoute = location == '/login';

      final isRegisterRoute = location == '/register';

      final isForgotPasswordRoute = location == '/forgot-password';

      final isResetPasswordRoute = location == '/auth/reset-password';

      final isConfirmationRoute = location == '/auth/confirmed';

      final isGoogleCallbackRoute = location == '/auth/google';

      final isAuthRoute =
          isLoginRoute ||
          isRegisterRoute ||
          isForgotPasswordRoute ||
          isResetPasswordRoute ||
          isConfirmationRoute ||
          isGoogleCallbackRoute;

      switch (authState.status) {
        case AuthStatus.initializing:
          return null;

        case AuthStatus.authenticating:
          return null;

        case AuthStatus.unauthenticated:
          return isAuthRoute ? null : '/login';

        case AuthStatus.emailConfirmationRequired:
          return isRegisterRoute ? null : '/register';

        case AuthStatus.passwordResetRequested:
          return isForgotPasswordRoute ? null : '/forgot-password';

        case AuthStatus.passwordRecovery:
          return isResetPasswordRoute ? null : '/auth/reset-password';

        case AuthStatus.error:
          return isAuthRoute ? null : '/login';

        case AuthStatus.authenticated:
          switch (sessionState.status) {
            case AppSessionStatus.initializing:
              return null;

            case AppSessionStatus.unauthenticated:
              return '/login';

            case AppSessionStatus.error:
              return '/';

            case AppSessionStatus.noRoom:
              final canAccessWithoutRoom =
                  location == '/' ||
                  location == '/room/create' ||
                  location == '/room/join' || 
                  location == '/youtube-windows-test';

              if (isAuthRoute) {
                return '/';
              }

              return canAccessWithoutRoom ? null : '/';

            case AppSessionStatus.inRoom:
              final roomId = sessionState.roomId;

              if (roomId == null) {
                return '/';
              }

              final roomLocation = '/room/$roomId';

              if (location != roomLocation) {
                return roomLocation;
              }

              return null;
          }
      }
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const LoginPage();
        },
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) {
          return const RegisterPage();
        },
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          return const ForgotPasswordPage();
        },
      ),

      GoRoute(
        path: '/auth/confirmed',
        builder: (context, state) {
          return const EmailConfirmationPage();
        },
      ),

      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) {
          return const ResetPasswordPage();
        },
      ),

      GoRoute(
        path: '/auth/google',
        builder: (context, state) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),

      GoRoute(
        path: '/',
        builder: (context, state) {
          return const HomePage();
        },
      ),

      GoRoute(
        path: '/room/create',
        builder: (context, state) {
          return const CreateRoomPage();
        },
      ),

      GoRoute(
        path: '/room/join',
        builder: (context, state) {
          return const JoinRoomPage();
        },
      ),

      GoRoute(
        path: '/room/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;

          return RoomPage(roomId: roomId);
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});
