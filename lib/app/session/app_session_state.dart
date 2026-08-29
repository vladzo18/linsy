enum AppSessionStatus {
  initializing,
  unauthenticated,
  noRoom,
  inRoom,
  error,
}

class AppSessionState {
  final AppSessionStatus status;
  final String? roomId;
  final String? errorMessage;

  const AppSessionState({
    required this.status,
    this.roomId,
    this.errorMessage,
  });

  const AppSessionState.initializing()
      : status = AppSessionStatus.initializing,
        roomId = null,
        errorMessage = null;

  const AppSessionState.unauthenticated()
      : status = AppSessionStatus.unauthenticated,
        roomId = null,
        errorMessage = null;

  const AppSessionState.noRoom()
      : status = AppSessionStatus.noRoom,
        roomId = null,
        errorMessage = null;

  const AppSessionState.inRoom(String this.roomId)
      : status = AppSessionStatus.inRoom,
        errorMessage = null;

  const AppSessionState.error(String message)
      : status = AppSessionStatus.error,
        roomId = null,
        errorMessage = message;
}