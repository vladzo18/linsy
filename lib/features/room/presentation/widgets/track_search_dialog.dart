import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/application/saved_tracks_controller.dart';
import '../../../library/domain/models/saved_track.dart';
import '../../domain/models/track_search_result.dart';
import '../controllers/track_search_controller.dart';
import '../../data/providers/track_search_suggestions_repository_provider.dart';

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

  final _searchFocusNode = FocusNode();

  final _suggestionsMenuController = MenuController();

  Timer? _suggestionsDebounce;

  List<String> _suggestions = const [];

  int _suggestionsRequestId = 0;

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
    _suggestionsDebounce?.cancel();

    _suggestionsRequestId++;

    _searchFocusNode.dispose();

    _searchController.dispose();

    super.dispose();
  }

  // ===================================================================
  // SEARCH SUGGESTIONS
  // ===================================================================

  void _onSearchChanged(String value) {
    _suggestionsDebounce?.cancel();

    _suggestionsDebounce = null;

    final requestId = ++_suggestionsRequestId;

    final query = value.trim();

    // Старые подсказки больше
    // не должны оставаться на экране.
    _hideSuggestions();

    if (_mode != _TrackPickerMode.search) {
      return;
    }

    if (query.length < 2) {
      return;
    }

    // Если вставили YouTube URL,
    // autocomplete не нужен.
    if (_looksLikeUrl(query)) {
      return;
    }

    _suggestionsDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadSuggestions(query, requestId);
    });
  }

  // ===================================================================
  // LOAD SUGGESTIONS
  // ===================================================================

  Future<void> _loadSuggestions(String query, int requestId) async {
    try {
      final repository = ref.read(trackSearchSuggestionsRepositoryProvider);

      final suggestions = await repository.suggest(query);

      if (!mounted) {
        return;
      }

      // ===============================================================
      // STALE RESPONSE PROTECTION
      // ===============================================================

      if (requestId != _suggestionsRequestId) {
        return;
      }

      if (_mode != _TrackPickerMode.search) {
        return;
      }

      if (_searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _suggestions = suggestions;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (requestId != _suggestionsRequestId) {
          return;
        }

        if (_suggestions.isEmpty || !_searchFocusNode.hasFocus) {
          if (_suggestionsMenuController.isOpen) {
            _suggestionsMenuController.close();
          }

          return;
        }

        if (!_suggestionsMenuController.isOpen) {
          _suggestionsMenuController.open();
        }
      });
    } catch (_) {
      // Suggestions — вспомогательная фича.
      //
      // Ошибка здесь НЕ должна ломать
      // основной поиск.

      if (!mounted || requestId != _suggestionsRequestId) {
        return;
      }

      _hideSuggestions();
    }
  }

  // ===================================================================
  // SELECT SUGGESTION
  // ===================================================================

  Future<void> _selectSuggestion(String suggestion) async {
    _suggestionsDebounce?.cancel();

    _suggestionsDebounce = null;

    _suggestionsRequestId++;

    _searchController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );

    _hideSuggestions();

    await _search();
  }

  // ===================================================================
  // HIDE SUGGESTIONS
  // ===================================================================

  void _hideSuggestions() {
    if (_suggestionsMenuController.isOpen) {
      _suggestionsMenuController.close();
    }

    if (_suggestions.isEmpty) {
      return;
    }

    setState(() {
      _suggestions = const [];
    });
  }

  // ===================================================================
  // URL
  // ===================================================================

  bool _looksLikeUrl(String value) {
    final lower = value.trim().toLowerCase();

    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('youtube.com/') ||
        lower.startsWith('www.youtube.com/') ||
        lower.startsWith('m.youtube.com/') ||
        lower.startsWith('music.youtube.com/') ||
        lower.startsWith('youtu.be/');
  }

  // ===================================================================
  // SEARCH
  // ===================================================================

  Future<void> _search() async {
    _suggestionsDebounce?.cancel();

    _suggestionsDebounce = null;

    _suggestionsRequestId++;

    _hideSuggestions();

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

                  final nextMode = selection.first;

                  _suggestionsDebounce?.cancel();

                  _suggestionsDebounce = null;

                  _suggestionsRequestId++;

                  if (_suggestionsMenuController.isOpen) {
                    _suggestionsMenuController.close();
                  }

                  setState(() {
                    _mode = nextMode;

                    _suggestions = const [];
                  });

                  if (nextMode == _TrackPickerMode.search) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }

                      _searchFocusNode.requestFocus();
                    });
                  }
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth;

                        return MenuAnchor(
                          controller: _suggestionsMenuController,

                          crossAxisUnconstrained: false,

                          consumeOutsideTap: false,

                          style: MenuStyle(
                            fixedSize: WidgetStatePropertyAll(
                              Size.fromWidth(fieldWidth),
                            ),

                            maximumSize: WidgetStatePropertyAll(
                              Size(fieldWidth, 320),
                            ),
                          ),

                          menuChildren: [
                            for (final suggestion in _suggestions)
                              MenuItemButton(
                                style: ButtonStyle(
                                  minimumSize: WidgetStatePropertyAll(
                                    Size(fieldWidth, 44),
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),

                                leadingIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                ),

                                onPressed: () {
                                  _selectSuggestion(suggestion);
                                },

                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    suggestion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],

                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            textInputAction: TextInputAction.search,

                            onChanged: _onSearchChanged,

                            onSubmitted: (_) {
                              _search();
                            },

                            decoration: const InputDecoration(
                              labelText: 'Search tracks',
                              hintText: 'Linkin Park Numb',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        );
                      },
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
