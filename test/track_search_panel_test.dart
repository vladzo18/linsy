import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/library/application/saved_tracks_controller.dart';
import 'package:linsy/features/library/domain/models/saved_track.dart';
import 'package:linsy/features/room/domain/models/track_search_result.dart';
import 'package:linsy/features/room/presentation/controllers/track_search_controller.dart';
import 'package:linsy/features/room/presentation/widgets/track_search_dialog.dart';

class _Saved extends SavedTracksController {
  @override
  Future<List<SavedTrack>> build() async => [];
}

class _Search extends TrackSearchController {
  @override
  Future<void> search(String query) async {
    state = const AsyncData([
      TrackSearchResult(
        source: 'youtube',
        trackId: 'id',
        title: 'Test song',
        channelTitle: 'Artist',
        thumbnailUrl: null,
        durationMs: 120000,
      ),
    ]);
  }
}

void main() {
  for (final member in [false, true]) {
    testWidgets('embedded picker selects track, member=$member', (
      tester,
    ) async {
      TrackSearchResult? selected;
      late BuildContext page;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedTracksControllerProvider.overrideWith(_Saved.new),
            trackSearchControllerProvider.overrideWith(_Search.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  page = context;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 360,
                      height: 300,
                      child: TrackSearchPanel(
                        confirmRequest: member,
                        onClose: () {},
                        onSelected: (track) => selected = track,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(ModalRoute.of(page)!.isCurrent, isTrue);
      await tester.tap(find.text('Test song'));
      await tester.pumpAndSettle();
      if (member) {
        expect(selected, isNull);
        await tester.tap(find.text('Send request'));
      }
      expect(selected?.trackId, 'id');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
