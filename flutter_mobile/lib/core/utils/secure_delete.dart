import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class SecureDelete {
  SecureDelete._();

  /// Overwrites file content with zeros, flushes to disk, and then unlinks (deletes) the file.
  static Future<void> secureDeleteFile(File file) async {
    try {
      if (!await file.exists()) return;
      final length = await file.length();
      if (length > 0) {
        final raf = await file.open(mode: FileMode.write);
        try {
          const chunkSize = 64 * 1024;
          final zeroBuffer = Uint8List(min(length, chunkSize));
          int remaining = length;
          while (remaining > 0) {
            final toWrite = min(remaining, zeroBuffer.length);
            await raf.writeFrom(zeroBuffer, 0, toWrite);
            remaining -= toWrite;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      }
      await file.delete();
    } catch (_) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Synchronous version of secureDeleteFile for synchronous dispose / sweep routines
  static void secureDeleteFileSync(File file) {
    try {
      if (!file.existsSync()) return;
      final length = file.lengthSync();
      if (length > 0) {
        final raf = file.openSync(mode: FileMode.write);
        try {
          const chunkSize = 64 * 1024;
          final zeroBuffer = Uint8List(min(length, chunkSize));
          int remaining = length;
          while (remaining > 0) {
            final toWrite = min(remaining, zeroBuffer.length);
            raf.writeFromSync(zeroBuffer, 0, toWrite);
            remaining -= toWrite;
          }
          raf.flushSync();
        } finally {
          raf.closeSync();
        }
      }
      file.deleteSync();
    } catch (_) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }
}
