import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_share_sheet.dart';
import 'package:flutter_mobile/shared/design_system/index.dart';

class _InviteMock {
  int inviteCallCount = 0;
  Completer<InviteCreation?>? inviteCompleter;
  InviteCreation? nextInvite;
  bool shouldThrow = false;
  String throwMessage =
      'Network connection failed (SocketException: Host unreachable)';

  Future<InviteCreation?> createInvite({String? myName}) async {
    inviteCallCount++;
    if (shouldThrow) {
      throw FriendException(throwMessage);
    }
    if (inviteCompleter != null) {
      return inviteCompleter!.future;
    }
    return nextInvite ??
        const InviteCreation(code: 'TEST77', url: 'https://kioku.app/i/TEST77');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InviteController Unit & Lifecycle Tests', () {
    test('initial state is idle and has no active invite', () {
      final mock = _InviteMock();
      final controller = InviteController(createInviteFn: mock.createInvite);

      expect(controller.state.isIdle, isTrue);
      expect(controller.state.hasValidInvite, isFalse);
      expect(mock.inviteCallCount, 0);
    });

    test('deduplicates concurrent calls to ensureInviteGenerated', () async {
      final mock = _InviteMock();
      mock.inviteCompleter = Completer<InviteCreation?>();
      final controller = InviteController(createInviteFn: mock.createInvite);

      // Trigger twice concurrently
      final f1 = controller.ensureInviteGenerated();
      final f2 = controller.ensureInviteGenerated();

      expect(controller.state.isGenerating, isTrue);
      expect(mock.inviteCallCount, 1);

      // Complete the in-flight request
      mock.inviteCompleter!.complete(
        const InviteCreation(code: 'TEST99', url: 'https://kioku.app/i/TEST99'),
      );
      await Future.wait([f1, f2]);

      expect(controller.state.isReady, isTrue);
      expect(controller.state.invite?.code, 'TEST99');
      expect(mock.inviteCallCount, 1);

      // Subsequent call when ready and valid does not call service again
      await controller.ensureInviteGenerated();
      expect(mock.inviteCallCount, 1);
    });

    test('refreshes when cached invite is expired', () async {
      final mock = _InviteMock();
      final controller = InviteController(createInviteFn: mock.createInvite);

      // Seed with an expired invite
      final expiredMs = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      controller.state = InviteUiState.ready(
        InviteCreation(
          code: 'EXPIRED1',
          url: 'https://kioku.app/i/EXPIRED1',
          expiresAt: expiredMs,
        ),
      );

      expect(controller.state.invite!.isExpired, isTrue);
      expect(controller.state.hasValidInvite, isFalse);

      mock.nextInvite = const InviteCreation(
        code: 'FRESH1',
        url: 'https://kioku.app/i/FRESH1',
      );

      await controller.ensureInviteGenerated();

      expect(mock.inviteCallCount, 1);
      expect(controller.state.isReady, isTrue);
      expect(controller.state.invite?.code, 'FRESH1');
    });

    test(
      'captures error state cleanly without exposing raw exception',
      () async {
        final mock = _InviteMock()..shouldThrow = true;
        final controller = InviteController(createInviteFn: mock.createInvite);

        await controller.ensureInviteGenerated();

        expect(controller.state.isError, isTrue);
        expect(
          controller.state.errorMessage,
          "Couldn't generate an invite link.",
        );
        // Ensure raw technical text is NOT set in errorMessage
        expect(
          controller.state.errorMessage,
          isNot(contains('SocketException')),
        );
      },
    );

    test('retry forces fresh invite generation', () async {
      final mock = _InviteMock();
      final controller = InviteController(createInviteFn: mock.createInvite);

      await controller.ensureInviteGenerated();
      expect(mock.inviteCallCount, 1);

      // Retry forces a second call
      await controller.retry();
      expect(mock.inviteCallCount, 2);
    });
  });

  group('InviteShareSheet Widget Integration Tests', () {
    testWidgets(
      'displays friend code immediately and starts generation post-frame',
      (tester) async {
        final mock = _InviteMock();
        mock.inviteCompleter = Completer<InviteCreation?>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inviteControllerProvider.overrideWith(
                (ref) => InviteController(createInviteFn: mock.createInvite),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.coffeeLight(),
              home: const Scaffold(body: InviteShareSheet()),
            ),
          ),
        );

        // Initial frame: Friend code visible immediately, generation in progress
        await tester.pump();
        expect(find.text('Your Friend Code'), findsOneWidget);
        expect(find.text('Generating secure invite...'), findsOneWidget);

        // Complete generation
        mock.inviteCompleter!.complete(
          const InviteCreation(
            code: 'READY123',
            url: 'https://kioku.app/i/READY123',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('kioku.app/i/READY123'), findsOneWidget);
        expect(find.text('Copy Link'), findsOneWidget);
        expect(find.text('Share'), findsOneWidget);
        expect(find.byType(KiokuBottomSheet), findsOneWidget);
      },
    );

    testWidgets('repeated rebuilds do NOT trigger duplicate invite generation', (
      tester,
    ) async {
      final mock = _InviteMock();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteControllerProvider.overrideWith(
              (ref) => InviteController(createInviteFn: mock.createInvite),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.coffeeLight(),
            home: const Scaffold(body: InviteShareSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mock.inviteCallCount, 1);

      // Simulate multiple widget tree rebuilds (e.g. keyboard open, MediaQuery change)
      for (int i = 0; i < 5; i++) {
        tester.binding.scheduleFrame();
        await tester.pump();
      }

      // Invite call count must remain 1
      expect(mock.inviteCallCount, 1);
    });

    testWidgets(
      'on error, shows user-friendly message and keeps Friend Code usable',
      (tester) async {
        final mock = _InviteMock()..shouldThrow = true;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inviteControllerProvider.overrideWith(
                (ref) => InviteController(createInviteFn: mock.createInvite),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.coffeeLight(),
              home: const Scaffold(body: InviteShareSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Friend Code remains visible and accessible
        expect(find.text('Your Friend Code'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);

        // User-friendly error message is displayed
        expect(find.text("Couldn't generate an invite link."), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Internal framework / exception strings are strictly NEVER rendered
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.textContaining('markNeedsBuild'), findsNothing);
        expect(find.textContaining('setState()'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);

        // Tapping Retry recovers if service recovers
        mock.shouldThrow = false;
        mock.nextInvite = const InviteCreation(
          code: 'RECOVERED',
          url: 'https://kioku.app/i/RECOVERED',
        );

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('kioku.app/i/RECOVERED'), findsOneWidget);
        expect(find.text('Copy Link'), findsOneWidget);
      },
    );
  });

  group('KiokuLayout & SnackBar Geometry Tests', () {
    testWidgets('KiokuLayout.bottomDockClearance calculates valid clearance', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final clearance = KiokuLayout.bottomDockClearance(context);
              final snackBarMargin = KiokuLayout.floatingSnackBarBottomMargin(
                context,
                aboveBottomNav: true,
              );

              expect(
                clearance,
                greaterThanOrEqualTo(
                  KiokuLayout.bottomDockHeight +
                      KiokuLayout.bottomDockMarginBottom,
                ),
              );
              expect(snackBarMargin, greaterThan(clearance));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
