import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_state.dart';
import '../../features/room/data/providers/room_repository_provider.dart';
import 'app_session_state.dart';

final appSessionControllerProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
  AppSessionController.new,
);

class AppSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        _handleAuthState(next);
      },
      fireImmediately: true,
    );

    return const AppSessionState.initializing();
  }

  Future<void> _handleAuthState(
    AuthState authState,
  ) async {
    switch (authState.status) {
      case AuthStatus.initializing:
      case AuthStatus.authenticating:
        state = const AppSessionState.initializing();
        return;

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.emailConfirmationRequired:
      case AuthStatus.passwordResetRequested:
      case AuthStatus.passwordRecovery:
        state = const AppSessionState.unauthenticated();
        return;

      case AuthStatus.authenticated:
        final user = authState.user;

        if (user == null) {
          state = const AppSessionState.unauthenticated();
          return;
        }

        await _loadCurrentRoom(user.id);
        return;
    }
  }

  Future<void> _loadCurrentRoom(
    String userId,
  ) async {
    state = const AppSessionState.initializing();

    try {
      final repository = ref.read(roomRepositoryProvider);

      final room =
          await repository.getCurrentUserRoom(userId);

      if (room == null) {
        state = const AppSessionState.noRoom();
        return;
      }

      state = AppSessionState.inRoom(room.id);
    } catch (error) {
      state = AppSessionState.error(
        'Failed to restore your current room.',
      );
    }
  }

  Future<void> refresh() async {
    final authState =
        ref.read(authControllerProvider);

    await _handleAuthState(authState);
  }

  void enterRoom(String roomId) {
    state = AppSessionState.inRoom(roomId);
  }
}