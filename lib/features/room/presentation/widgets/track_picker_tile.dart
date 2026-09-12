import 'package:flutter/material.dart';

class TrackPickerTile extends StatelessWidget {
  const TrackPickerTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.saved,
    required this.favoriteEnabled,
    required this.favoriteBusy,
    required this.onFavorite,
    required this.onTap,
  });

  final String title;

  final String subtitle;

  final String? thumbnailUrl;

  final int? durationMs;

  final bool saved;

  final bool favoriteEnabled;

  final bool favoriteBusy;

  final VoidCallback onFavorite;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),

      leading: _Thumbnail(url: thumbnailUrl),

      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),

      subtitle: Row(
        children: [
          Expanded(
            child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),

          if (durationMs != null) Text(_formatDuration(durationMs!)),
        ],
      ),

      trailing: favoriteBusy
          ? const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : IconButton(
              tooltip: saved ? 'Remove from saved' : 'Save track',
              onPressed: favoriteEnabled ? onFavorite : null,
              icon: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
            ),

      onTap: onTap,
    );
  }
}

// THUMBNAIL

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        height: 54,
        child: url == null || url!.isEmpty
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.music_note),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.music_note),
                  );
                },
              ),
      ),
    );
  }
}

// DURATION

String _formatDuration(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;

  final hours = totalSeconds ~/ 3600;

  final minutes = (totalSeconds % 3600) ~/ 60;

  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '$minutes:'
      '${seconds.toString().padLeft(2, '0')}';
}
