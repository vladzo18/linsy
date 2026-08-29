import '../models/room_action_request.dart';

abstract interface class ActionRequestRepository {
  Future<RoomActionRequest> createRequest({
    required String roomId,
    required String userId,
    required RoomAction action,
    Map<String, dynamic>? payload,
  });

  Future<void> cancelRequest({required String requestId});

  Future<void> resolveRequest({
    required String requestId,
    required RoomActionRequestStatus status,
  });

  Stream<List<RoomActionRequest>> watchRoomRequests(String roomId);

  Stream<List<RoomActionRequest>> watchMyRequests(String roomId, String userId);
}
