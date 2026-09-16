import 'dart:typed_data';

class EncryptedEnvelope {
  static const List<int> magicBytes = [0x4B, 0x49, 0x4F, 0x31]; // 'KIO1'

  final String objectId;
  final Uint8List wrappedFileKey;
  final Uint8List fileKeyNonce;
  final Uint8List encryptedMetadata;
  final Uint8List metadataNonce;
  final Uint8List? encryptedThumbnail;
  final Uint8List? thumbnailNonce;
  final List<Uint8List> cipherChunks;

  const EncryptedEnvelope({
    required this.objectId,
    required this.wrappedFileKey,
    required this.fileKeyNonce,
    required this.encryptedMetadata,
    required this.metadataNonce,
    this.encryptedThumbnail,
    this.thumbnailNonce,
    required this.cipherChunks,
  });

  /// Serializes the entire envelope into a single opaque binary blob
  Uint8List toBlob() {
    final hasThumb = encryptedThumbnail != null &&
        encryptedThumbnail!.isNotEmpty &&
        thumbnailNonce != null;
    final thumbBytes = hasThumb ? encryptedThumbnail! : Uint8List(0);
    final thumbNonce = hasThumb ? thumbnailNonce! : Uint8List(0);

    // Calculate total size
    int chunksTotalSize = 4; // count (uint32)
    for (final c in cipherChunks) {
      chunksTotalSize += 4 + c.length; // len + bytes
    }

    final totalSize = 4 + // magic
        2 +
        wrappedFileKey.length +
        fileKeyNonce.length + // 24
        4 +
        encryptedMetadata.length +
        metadataNonce.length + // 24
        1 + // hasThumb flag
        (hasThumb ? (4 + thumbBytes.length + thumbNonce.length) : 0) +
        chunksTotalSize;

    final result = Uint8List(totalSize);
    final bdata = ByteData.sublistView(result);
    int offset = 0;

    // 1. Magic
    result.setRange(offset, offset + 4, magicBytes);
    offset += 4;

    // 2. Wrapped file key
    bdata.setUint16(offset, wrappedFileKey.length);
    offset += 2;
    result.setRange(offset, offset + wrappedFileKey.length, wrappedFileKey);
    offset += wrappedFileKey.length;

    // 3. File key nonce
    result.setRange(offset, offset + fileKeyNonce.length, fileKeyNonce);
    offset += fileKeyNonce.length;

    // 4. Encrypted metadata
    bdata.setUint32(offset, encryptedMetadata.length);
    offset += 4;
    result.setRange(offset, offset + encryptedMetadata.length, encryptedMetadata);
    offset += encryptedMetadata.length;

    // 5. Metadata nonce
    result.setRange(offset, offset + metadataNonce.length, metadataNonce);
    offset += metadataNonce.length;

    // 6. Thumbnail
    bdata.setUint8(offset, hasThumb ? 1 : 0);
    offset += 1;
    if (hasThumb) {
      bdata.setUint32(offset, thumbBytes.length);
      offset += 4;
      result.setRange(offset, offset + thumbNonce.length, thumbNonce);
      offset += thumbNonce.length;
      result.setRange(offset, offset + thumbBytes.length, thumbBytes);
      offset += thumbBytes.length;
    }

    // 7. Cipher chunks
    bdata.setUint32(offset, cipherChunks.length);
    offset += 4;
    for (final chunk in cipherChunks) {
      bdata.setUint32(offset, chunk.length);
      offset += 4;
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Deserializes an envelope from an opaque binary blob
  static EncryptedEnvelope fromBlob(Uint8List blob, {required String objectId}) {
    if (blob.length < 4) {
      throw const FormatException('Invalid blob: too short for magic bytes');
    }
    for (int i = 0; i < 4; i++) {
      if (blob[i] != magicBytes[i]) {
        throw const FormatException('Invalid blob: magic header does not match KIO1');
      }
    }

    final bdata = ByteData.sublistView(blob);
    int offset = 4;

    // 2. Wrapped file key
    final wrappedKeyLen = bdata.getUint16(offset);
    offset += 2;
    final wrappedFileKey = Uint8List.sublistView(blob, offset, offset + wrappedKeyLen);
    offset += wrappedKeyLen;

    // 3. File key nonce (24 bytes for secretbox)
    const nonceLen = 24;
    final fileKeyNonce = Uint8List.sublistView(blob, offset, offset + nonceLen);
    offset += nonceLen;

    // 4. Encrypted metadata
    final metadataLen = bdata.getUint32(offset);
    offset += 4;
    final encryptedMetadata = Uint8List.sublistView(blob, offset, offset + metadataLen);
    offset += metadataLen;

    // 5. Metadata nonce
    final metadataNonce = Uint8List.sublistView(blob, offset, offset + nonceLen);
    offset += nonceLen;

    // 6. Thumbnail
    final hasThumb = bdata.getUint8(offset) == 1;
    offset += 1;
    Uint8List? encryptedThumbnail;
    Uint8List? thumbNonce;
    if (hasThumb) {
      final thumbLen = bdata.getUint32(offset);
      offset += 4;
      thumbNonce = Uint8List.sublistView(blob, offset, offset + nonceLen);
      offset += nonceLen;
      encryptedThumbnail = Uint8List.sublistView(blob, offset, offset + thumbLen);
      offset += thumbLen;
    }

    // 7. Cipher chunks
    final chunkCount = bdata.getUint32(offset);
    offset += 4;
    final chunks = <Uint8List>[];
    for (int i = 0; i < chunkCount; i++) {
      final cLen = bdata.getUint32(offset);
      offset += 4;
      chunks.add(Uint8List.sublistView(blob, offset, offset + cLen));
      offset += cLen;
    }

    return EncryptedEnvelope(
      objectId: objectId,
      wrappedFileKey: wrappedFileKey,
      fileKeyNonce: fileKeyNonce,
      encryptedMetadata: encryptedMetadata,
      metadataNonce: metadataNonce,
      encryptedThumbnail: encryptedThumbnail,
      thumbnailNonce: thumbNonce,
      cipherChunks: chunks,
    );
  }
}
