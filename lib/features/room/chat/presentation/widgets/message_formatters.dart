import 'package:flutter/widgets.dart';

String messageInitial(String? name) {
  final normalized = name?.trim() ?? '';

  if (normalized.isEmpty) {
    return '?';
  }

  return normalized.characters.first.toUpperCase();
}

String formatMessageTime(DateTime dateTime) {
  final local = dateTime.toLocal();

  final hours = local.hour.toString().padLeft(2, '0');

  final minutes = local.minute.toString().padLeft(2, '0');

  return '$hours:$minutes';
}
