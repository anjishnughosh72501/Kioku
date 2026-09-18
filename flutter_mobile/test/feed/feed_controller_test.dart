import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/feed/presentation/controllers/feed_controller.dart';

void main() {
  group('FeedController', () {
    test('pageSize is enforced to 20 items per page', () {
      expect(FeedController.pageSize, 20);
    });

    test('shouldPrefetch returns true when offset is >= 80% of maxScrollExtent', () {
      expect(
        FeedController.shouldPrefetch(offset: 800, maxScrollExtent: 1000),
        isTrue,
      );
      expect(
        FeedController.shouldPrefetch(offset: 850, maxScrollExtent: 1000),
        isTrue,
      );
      expect(
        FeedController.shouldPrefetch(offset: 500, maxScrollExtent: 2000),
        isFalse,
      );
    });

    test('shouldPrefetch returns true when within 400px of maxScrollExtent', () {
      expect(
        FeedController.shouldPrefetch(offset: 1650, maxScrollExtent: 2000),
        isTrue,
      );
      expect(
        FeedController.shouldPrefetch(offset: 1500, maxScrollExtent: 2000),
        isFalse,
      );
    });

    test('shouldPrefetch returns false when maxScrollExtent <= 0', () {
      expect(
        FeedController.shouldPrefetch(offset: 0, maxScrollExtent: 0),
        isFalse,
      );
    });
  });
}
