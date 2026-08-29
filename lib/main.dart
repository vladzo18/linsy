import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/deep_links/app_links_provider.dart';
import 'package:linsy/core/platform/windows/window_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:linsy/core/network/network_monitor_provider.dart';
import 'app/app.dart';
import 'app/app_exit_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ptgyzoaiabrmwjjwdxbu.supabase.co',
    publishableKey: 'sb_publishable_LkYIfHG7IB9vxbgZOS4XAQ_fg6-0-ud',
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  final container = ProviderContainer();

  // ===================================================================
  // NETWORK
  // ===================================================================

  await container.read(networkMonitorProvider).start();

  await container.read(networkRecoveryCoordinatorProvider).start();

  // ===================================================================
  // APP EXIT
  // ===================================================================

  final appExitService = AppExitService(container);

  // ===================================================================
  // DEEP LINKS
  // ===================================================================

  await container.read(appLinksServiceProvider).initialize();

  // ===================================================================
  // WINDOW
  // ===================================================================

  final windowService = PlatformWindowService(
    onCloseRequested: appExitService.leaveCurrentRoom,
  );

  await windowService.initialize();

  // ===================================================================
  // APP
  // ===================================================================

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: LinsyApp(appExitService: appExitService),
    ),
  );
}
