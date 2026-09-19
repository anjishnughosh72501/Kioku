/// App Router — GoRouter configuration for Kioku navigation
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/crypto/key_store.dart';
import 'core/models/memory.dart';
import 'features/auth/presentation/screens/join_screen.dart';
import 'features/auth/presentation/screens/recovery_key_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/feed/presentation/screens/feed_screen.dart';
import 'package:flutter_mobile/shared/widgets/kioku_shell.dart';
import 'features/flashbacks/presentation/screens/flashbacks_screen.dart';
import 'features/upload/presentation/screens/upload_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/media_viewer/presentation/screens/photo_viewer_screen.dart';
import 'features/media_viewer/presentation/screens/video_player_screen.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/migration_screen.dart';
import 'features/profile/presentation/screens/storage_setup_screen.dart';
import 'features/albums/presentation/screens/albums_screen.dart';
import 'features/albums/presentation/screens/album_detail_screen.dart';
import 'features/friends/presentation/screens/friends_screen.dart';
import 'features/friends/presentation/widgets/invite_accept_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Global root navigator key for deep links, dialogs, and notifications
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider with auth state listener
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isRecovery = state.matchedLocation == '/recovery';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isAuth = authState.isAuthenticated;
      final isJoinScreen = state.matchedLocation == '/join';
      final isInvite = state.matchedLocation.startsWith('/invite');

      if (KeyStore.instance.needsRecovery) {
        if (!isRecovery) return '/recovery';
        return null;
      }
      if (isRecovery) {
        return '/';
      }

      if (isSplash || isOnboarding) {
        return null;
      }

      if (authState.isLoading) return null;

      if (!isAuth && !isJoinScreen) {
        if (isInvite) {
          final uri = state.uri;
          String? code;
          if (uri.pathSegments.length > 1 &&
              (uri.pathSegments.first == 'i' || uri.pathSegments.first == 'invite')) {
            code = uri.pathSegments[1].trim().toUpperCase();
          } else if (uri.host == 'i' || uri.host == 'invite') {
            if (uri.pathSegments.isNotEmpty) {
              code = uri.pathSegments.first.trim().toUpperCase();
            }
          }
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('pending_deep_link', uri.toString());
            if (code != null && code.isNotEmpty) {
              prefs.setString('pending_invite_code', code);
            }
          });
        }
        return '/join';
      }

      if (isAuth && isJoinScreen) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/recovery',
        name: 'recovery',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RecoveryKeyScreen(),
        ),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/join',
        name: 'join',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const JoinScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return KiokuShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'feed',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FeedScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/albums',
                name: 'albums',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AlbumsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                name: 'friends',
                pageBuilder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  final initialTab = tab != null ? int.tryParse(tab) ?? 0 : 0;
                  return NoTransitionPage(
                    child: FriendsScreen(initialTabIndex: initialTab),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/flashbacks',
        name: 'flashbacks',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: const FlashbacksScreen(),
        ),
      ),
      GoRoute(
        path: '/albums/:id',
        name: 'album-detail',
        pageBuilder: (context, state) {
          final albumId = state.pathParameters['id']!;
          final album = state.extra as Album?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: AlbumDetailScreen(albumId: albumId, album: album),
            transitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/album/:id',
        name: 'album-alias',
        redirect: (context, state) {
          final id = state.pathParameters['id']!;
          return '/albums/$id';
        },
      ),
      GoRoute(
        path: '/invite',
        name: 'invite',
        redirect: (context, state) {
          final uri = state.uri;
          final code = uri.queryParameters['code'];
          if (code != null && code.trim().isNotEmpty) {
            return '/i/${code.trim()}';
          }
          // Redirect legacy query parameters to /friends without direct state mutation
          return '/friends';
        },
      ),
      GoRoute(
        path: '/i/:code',
        name: 'short-invite',
        redirect: (context, state) {
          final code = state.pathParameters['code'];
          if (code != null && code.isNotEmpty) {
            if (!authState.isAuthenticated) {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('pending_invite_code', code);
              });
              return '/join';
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navContext = rootNavigatorKey.currentContext ?? context;
              InviteAcceptDialog.show(navContext, code);
            });
          }
          return '/';
        },
      ),
      GoRoute(
        path: '/invite/:code',
        name: 'invite-alias',
        redirect: (context, state) {
          final code = state.pathParameters['code']!;
          return '/i/$code';
        },
      ),
      GoRoute(
        path: '/upload',
        name: 'upload',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const UploadScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.14),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/media/:id',
        name: 'media-detail',
        pageBuilder: (context, state) {
          final mediaId = state.pathParameters['id']!;
          final memory = state.extra as KiokuMemory?;
          final child = (memory?.isVideo == true)
              ? VideoPlayerScreen(mediaId: mediaId, memory: memory)
              : PhotoViewerScreen(mediaId: mediaId, memory: memory);
          return CustomTransitionPage(
            key: state.pageKey,
            child: child,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/storage-setup',
        name: 'storage-setup',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: const StorageSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/migration',
        name: 'migration',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: MigrationScreen(
            onComplete: () => context.go('/'),
          ),
        ),
      ),
    ],
  );
});

/// iOS-style push transition: subtle horizontal slide (Offset(0.06, 0) -> 0) + fade
Page<dynamic> buildPushTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}