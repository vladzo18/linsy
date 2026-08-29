import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/application/saved_tracks_controller.dart';
import '../../../library/domain/models/saved_track.dart';
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

enum _TrackPickerMode { search, saved }

class _TrackSearchDialog extends ConsumerStatefulWidget {
  const _TrackSearchDialog();

  @override
  ConsumerState<_TrackSearchDialog> createState() => _TrackSearchDialogState();
}

class _TrackSearchDialogState extends ConsumerState<_TrackSearchDialog> {
  final _searchController = TextEditingController();

  final Set<String> _favoriteMutations = {};

  _TrackPickerMode _mode = _TrackPickerMode.search;

  // ===================================================================
  // INIT
  // ===================================================================

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

  // ===================================================================
  // DISPOSE
  // ===================================================================

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // ===================================================================
  // SEARCH
  // ===================================================================

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.length < 2) {
      return;
    }

    await ref.read(trackSearchControllerProvider.notifier).search(query);
  }

  // ===================================================================
  // FAVORITE KEY
  // ===================================================================

  String _favoriteKey({required String source, required String trackId}) {
    return '$source:$trackId';
  }

  // ===================================================================
  // TOGGLE FAVORITE
  // ===================================================================

  Future<void> _toggleFavorite(TrackSearchResult track) async {
    final key = _favoriteKey(source: track.source, trackId: track.trackId);

    if (_favoriteMutations.contains(key)) {
      return;
    }

    setState(() {
      _favoriteMutations.add(key);
    });

    final controller = ref.read(savedTracksControllerProvider.notifier);

    try {
      final saved = controller.isSaved(
        source: track.source,
        trackId: track.trackId,
      );

      if (saved) {
        await controller.removeTrack(
          source: track.source,
          trackId: track.trackId,
        );
      } else {
        await controller.saveTrack(
          source: track.source,
          trackId: track.trackId,
          title: track.title,
          channelTitle: track.channelTitle,
          thumbnailUrl: track.thumbnailUrl,
          durationMs: track.durationMs,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update saved tracks: '
              '$error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteMutations.remove(key);
        });
      }
    }
  }

  // ===================================================================
  // SAVED → SEARCH RESULT
  // ===================================================================

  TrackSearchResult _fromSavedTrack(SavedTrack track) {
    return TrackSearchResult(
      trackId: track.trackId,
      title: track.title,
      channelTitle: track.channelTitle,
      thumbnailUrl: track.thumbnailUrl,
      durationMs: track.durationMs,
      source: track.source,
    );
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(trackSearchControllerProvider);

    final savedState = ref.watch(savedTracksControllerProvider);

    final savedTracks = savedState.value ?? const <SavedTrack>[];

    final savedKeys = savedTracks.map((track) => track.key).toSet();

    return AlertDialog(
      title: const Text('Add track'),
      content: SizedBox(
        width: 600,
        height: 520,
        child: Column(
          children: [
            // =====================================================
            // MODE
            // =====================================================
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_TrackPickerMode>(
                segments: const [
                  ButtonSegment(
                    value: _TrackPickerMode.search,
                    icon: Icon(Icons.search_rounded),
                    label: Text('Search'),
                  ),

                  ButtonSegment(
                    value: _TrackPickerMode.saved,
                    icon: Icon(Icons.favorite_rounded),
                    label: Text('Saved'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }

                  setState(() {
                    _mode = selection.first;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // =====================================================
            // SEARCH INPUT
            // =====================================================
            if (_mode == _TrackPickerMode.search) ...[
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
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton.filled(
                    tooltip: 'Search',
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],

            // =====================================================
            // CONTENT
            // =====================================================
            Expanded(
              child: _mode == _TrackPickerMode.search
                  ? _buildSearchResults(
                      searchState,
                      savedKeys,
                      savedState.value != null,
                    )
                  : _buildSavedTracks(savedState),
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

  // ===================================================================
  // SEARCH RESULTS
  // ===================================================================

  Widget _buildSearchResults(
    AsyncValue<List<TrackSearchResult>> searchState,
    Set<String> savedKeys,
    bool favoritesReady,
  ) {
    return searchState.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (error, stackTrace) => Center(
        child: Text('Search failed: $error', textAlign: TextAlign.center),
      ),

      data: (results) {
        if (results.isEmpty) {
          return const Center(child: Text('Search for a track.'));
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final track = results[index];

            final key = _favoriteKey(
              source: track.source,
              trackId: track.trackId,
            );

            final saved = savedKeys.contains(key);

            final mutating = _favoriteMutations.contains(key);

            return _TrackTile(
              title: track.title,
              subtitle: track.channelTitle,
              thumbnailUrl: track.thumbnailUrl,
              durationMs: track.durationMs,
              saved: saved,
              favoriteEnabled: favoritesReady && !mutating,
              favoriteBusy: mutating,
              onFavorite: () {
                _toggleFavorite(track);
              },
              onTap: () {
                Navigator.of(context).pop(track);
              },
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // SAVED
  // ===================================================================

  Widget _buildSavedTracks(AsyncValue<List<SavedTrack>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded),

            const SizedBox(height: 8),

            const Text('Failed to load saved tracks.'),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () {
                ref.read(savedTracksControllerProvider.notifier).reload();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),

      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),

                const SizedBox(height: 10),

                Text(
                  'No saved tracks yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  'Tap the heart next to a search result '
                  'to save it here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: tracks.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final savedTrack = tracks[index];

            final track = _fromSavedTrack(savedTrack);

            final key = savedTrack.key;

            final mutating = _favoriteMutations.contains(key);

            return _TrackTile(
              title: savedTrack.title,
              subtitle: savedTrack.channelTitle,
              thumbnailUrl: savedTrack.thumbnailUrl,
              durationMs: savedTrack.durationMs,
              saved: true,
              favoriteEnabled: !mutating,
              favoriteBusy: mutating,
              onFavorite: () {
                _toggleFavorite(track);
              },
              onTap: () {
                Navigator.of(context).pop(track);
              },
            );
          },
        );
      },
    );
  }
}

// =====================================================================
// TRACK TILE
// =====================================================================

class _TrackTile extends StatelessWidget {
  const _TrackTile({
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

// =====================================================================
// THUMBNAIL
// =====================================================================

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

// =====================================================================
// DURATION
// =====================================================================

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
