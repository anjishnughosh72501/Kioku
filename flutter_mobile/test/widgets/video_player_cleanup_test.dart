import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/media_viewer/presentation/screens/video_player_screen.dart';

void main() {
  group('VideoPlayerScreen temp-file cleanup tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kioku_video_cleanup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('sweepStaleTempVideos removes dec_*.mp4 files from temp directory', () async {
      // Create leftover decrypted files and an unrelated file
      final stale1 = File('${tempDir.path}/dec_video_1.mp4');
      stale1.writeAsStringSync('dummy video 1');
      final stale2 = File('${tempDir.path}/dec_video_2.mp4');
      stale2.writeAsStringSync('dummy video 2');
      final keepFile = File('${tempDir.path}/unrelated_cache.txt');
      keepFile.writeAsStringSync('should not be deleted');

      expect(stale1.existsSync(), isTrue);
      expect(stale2.existsSync(), isTrue);
      expect(keepFile.existsSync(), isTrue);

      // Run sweep
      await VideoPlayerScreen.sweepStaleTempVideos(tempDir);

      // Verify decrypted temp videos are deleted
      expect(stale1.existsSync(), isFalse);
      expect(stale2.existsSync(), isFalse);
      // Verify unrelated files are untouched
      expect(keepFile.existsSync(), isTrue);
    });
  });
}
