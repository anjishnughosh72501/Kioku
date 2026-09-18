import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/features/friends/presentation/screens/friends_screen.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_share_sheet.dart';

class FakeFriendsListNotifier extends FriendsListNotifier {
  FakeFriendsListNotifier(Ref ref, List<FriendUser> list) : super(ref) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> refresh() async {}
}

class FakeIncomingRequestsNotifier extends IncomingRequestsNotifier {
  FakeIncomingRequestsNotifier(Ref ref, List<FriendRequest> list) : super(ref) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> refresh({bool silent = false}) async {}
}

class FakeSentRequestsNotifier extends SentRequestsNotifier {
  FakeSentRequestsNotifier(Ref ref, List<SentFriendRequest> list) : super(ref) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> refresh({bool silent = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderWindows.registerWith();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.instance.httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'friends': [],
          'requests': [],
          'sent': [],
          'code': '8F3KD2',
          'url': 'https://kioku.app/i/8F3KD2',
          'status': 'valid',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  Widget createSubject({
    List<FriendUser>? friends,
    List<FriendRequest>? incoming,
    List<SentFriendRequest>? sent,
    int initialTabIndex = 0,
  }) {
    return ProviderScope(
      overrides: [
        if (friends != null)
          friendsListProvider.overrideWith((ref) => FakeFriendsListNotifier(ref, friends)),
        if (incoming != null)
          incomingRequestsProvider.overrideWith((ref) => FakeIncomingRequestsNotifier(ref, incoming)),
        if (sent != null)
          sentRequestsProvider.overrideWith((ref) => FakeSentRequestsNotifier(ref, sent)),
      ],
      child: MaterialApp(
        theme: AppTheme.coffeeLight(),
        home: FriendsScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  group('FriendsScreen 4-Tab Hub', () {
    testWidgets('renders all 4 tabs and displays empty state on Friends tab', (tester) async {
      await tester.pumpWidget(createSubject(friends: []));
      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      expect(find.text('No friends yet'), findsOneWidget);
      expect(find.text('Invite someone to begin sharing encrypted memories & shared albums.'), findsOneWidget);
    });

    testWidgets('renders friend item when friends list is populated', (tester) async {
      final friends = [
        const FriendUser(friendCode: 'KIOKU-ALICE', username: 'Alice'),
      ];

      await tester.pumpWidget(createSubject(friends: friends));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining('KIOKU-ALICE'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('navigates to Add tab and shows Method A and Method B', (tester) async {
      await tester.pumpWidget(createSubject(initialTabIndex: 3));
      await tester.pumpAndSettle();

      expect(find.text('Method A — Friend Code'), findsOneWidget);
      expect(find.text('Method B — Short Link / QR Code'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Add Friend'), findsOneWidget);
      expect(find.text('Open Invite Confirmation'), findsOneWidget);
    });

    testWidgets('displays badge on Incoming tab when requests are pending', (tester) async {
      final incoming = [
        const FriendRequest(
          id: 'req_1',
          fromCode: 'KIOKU-BOB',
          toCode: 'KIOKU-SELF',
          fromName: 'Bob',
          createdAt: 1700000000,
        ),
      ];

      await tester.pumpWidget(createSubject(incoming: incoming));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });
  });

  group('InviteShareSheet Widget', () {
    testWidgets('displays invite share sheet UI elements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userInviteProvider.overrideWith((ref) {
              final n = UserInviteNotifier();
              n.state = const AsyncValue.data(
                InviteCreation(code: '8F3KD2', url: 'https://kioku.app/i/8F3KD2'),
              );
              return n;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.coffeeLight(),
            home: const Scaffold(
              body: InviteShareSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invite Friends'), findsOneWidget);
      expect(find.text('kioku.app/i/8F3KD2'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });
  });
}
