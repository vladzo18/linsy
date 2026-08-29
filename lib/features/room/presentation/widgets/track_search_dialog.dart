import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track_search_result.dart';
import '../controllers/track_search_controller.dart';

Future<TrackSearchResult?> showTrackSearchDialog(BuildContext context) {
  return showDialog<TrackSearchResult>(
    context: context,
    builder: (context) {
      return const _TrackSearchDialog();
    },
  );
}

class _TrackSearchDialog extends ConsumerStatefulWidget {
  const _TrackSearchDialog();

  @override
  ConsumerState<_TrackSearchDialog> createState() => _TrackSearchDialogState();
}

class _TrackSearchDialogState extends ConsumerState<_TrackSearchDialog> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref.read(trackSearchControllerProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.length < 2) {
      return;
    }

    await ref.read(trackSearchControllerProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(trackSearchControllerProvider);

    return AlertDialog(
      title: const Text('Search YouTube'),
      content: SizedBox(
        width: 600,
        height: 520,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      _search();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search tracks',
                      hintText: 'Linkin Park Numb',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Search',
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: searchState.when(
                loading: () => const Center(child: CircularProgressIndicator()),

                error: (error, stackTrace) => Center(
                  child: Text(
                    'Search failed: $error',
                    textAlign: TextAlign.center,
                  ),
                ),

                data: (results) {
                  if (results.isEmpty) {
                    return const Center(child: Text('Search for a track.'));
                  }

                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final track = results[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),

                        leading: _Thumbnail(url: track.thumbnailUrl),

                        title: Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                track.channelTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            if (track.durationMs != null)
                              Text(_formatDuration(track.durationMs!)),
                          ],
                        ),

                        onTap: () {
                          Navigator.of(context).pop(track);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;

  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        height: 54,
        child: url == null
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
