import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/settings/presentation/pages/settings_page.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../../../profile/application/profile_store.dart';

import '../widgets/home_welcome_section.dart';
import '../widgets/home_room_actions.dart';
import '../widgets/home_rooms_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final homeAsync = ref.watch(homeControllerProvider);

    final user = authState.user;

    final profile = user == null
        ? null
        : ref.watch(profileByIdProvider(user.id));

    final profileName = profile?.displayName?.trim();

    final displayName = profileName != null && profileName.isNotEmpty
        ? profileName
        : user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Linsy'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 8),
        ],
      ),

      // BODY
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(homeControllerProvider.notifier).refresh();
          },

          // -----------------------------------------------------------
          // Important:
          //
          // ListView itself occupies the full window width.
          // The content is centered INSIDE it.
          //
          // So scrollbars stay at the window edge.
          // -----------------------------------------------------------
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // WELCOME
                      HomeWelcomeSection(userName: displayName),

                      const SizedBox(height: 24),

                      // ACTIONS
                      const HomeRoomActions(),

                      const SizedBox(height: 34),

                      // ROOMS HEADER
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Rooms',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh rooms',
                            onPressed: () {
                              ref
                                  .read(homeControllerProvider.notifier)
                                  .refresh();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ROOMS
                      homeAsync.when(
                        loading: () => const HomeRoomsLoading(),

                        error: (error, stackTrace) {
                          return HomeErrorCard(
                            onRetry: () {
                              ref
                                  .read(homeControllerProvider.notifier)
                                  .refresh();
                            },
                          );
                        },

                        data: (state) {
                          return HomeRoomsSection(state: state);
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
