import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomNameProvider = FutureProvider.family<String, String>((
  ref,
  roomId,
) async {
  final data = await Supabase.instance.client
      .from('rooms')
      .select('name')
      .eq('id', roomId)
      .single();

  final name = data['name'];

  if (name is! String || name.trim().isEmpty) {
    return 'Room';
  }

  return name.trim();
});
