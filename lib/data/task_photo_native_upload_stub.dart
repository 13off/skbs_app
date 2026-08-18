import 'dart:typed_data';

Future<void> uploadTaskPhotoNative({
  required Uri uri,
  required String apiKey,
  required String accessToken,
  required Uint8List bytes,
  required String contentType,
  required void Function(int loadedBytes) onProgress,
}) {
  throw UnsupportedError('Native task photo upload is unavailable');
}
