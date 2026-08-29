enum UiSound {
  message(
    'sounds/message.wav',
  ),

  request(
    'sounds/request.wav',
  ),

  memberJoin(
    'sounds/member_join.wav',
  ),

  memberLeave(
    'sounds/member_leave.wav',
  );

  const UiSound(
    this.assetPath,
  );

  final String assetPath;
}