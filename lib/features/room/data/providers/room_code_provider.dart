import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomCodeProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  roomId,
) async {
  final row = await Supabase.instance.client
      .from('rooms')
      .select('room_code')
      .eq('id', roomId)
      .maybeSingle();

  if (row == null) {
    return null;
  }

  return row['room_code'] as String?;
});
