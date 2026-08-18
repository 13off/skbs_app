import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const int _chunkSize = 512 * 1024;
const int _maxAttempts = 2;
const Duration _connectTimeout = Duration(seconds: 20);
const Duration _chunkTimeout = Duration(seconds: 18);
const Duration _responseTimeout = Duration(seconds: 60);
const Duration _retryDelay = Duration(milliseconds: 650);

Future<void> uploadTaskPhotoNative({
  required Uri uri,
  required String apiKey,
  required String accessToken,
  required Uint8List bytes,
  required String contentType,
  required void Function(int loadedBytes) onProgress,
}) async {
  Object? lastError;

  for (var attempt = 1; attempt <= _maxAttempts; attempt += 1) {
    try {
      if (attempt > 1) onProgress(0);
      await _uploadAttempt(
        uri: uri,
        apiKey: apiKey,
        accessToken: accessToken,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
      return;
    } catch (error) {
      lastError = error;
      if (attempt > 1 &&
          error is _NativeTaskPhotoHttpException &&
          error.status == 409) {
        onProgress(bytes.length);
        return;
      }
      if (attempt >= _maxAttempts || !_isRetryable(error)) rethrow;
      await Future<void>.delayed(_retryDelay * attempt);
    }
  }

  throw lastError ?? Exception('Не удалось загрузить фотографию');
}

bool _isRetryable(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is HttpException) {
    return true;
  }
  if (error is _NativeTaskPhotoHttpException) {
    return error.status == 408 ||
        error.status == 425 ||
        error.status == 429 ||
        error.status >= 500;
  }
  return false;
}

Future<void> _uploadAttempt({
  required Uri uri,
  required String apiKey,
  required String accessToken,
  required Uint8List bytes,
  required String contentType,
  required void Function(int loadedBytes) onProgress,
}) async {
  final client = HttpClient()..connectionTimeout = _connectTimeout;
  try {
    final request = await client.postUrl(uri).timeout(_connectTimeout);
    request.headers.set('apikey', apiKey);
    request.headers.set('Authorization', 'Bearer $accessToken');
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.headers.set(HttpHeaders.cacheControlHeader, 'max-age=3600');
    request.contentLength = bytes.length;

    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + _chunkSize < bytes.length)
          ? sent + _chunkSize
          : bytes.length;
      request.add(Uint8List.sublistView(bytes, sent, end));
      await request.flush().timeout(_chunkTimeout);
      sent = end;
      onProgress(sent);
    }

    final response = await request.close().timeout(_responseTimeout);
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      onProgress(bytes.length);
      return;
    }

    throw _NativeTaskPhotoHttpException(
      response.statusCode,
      body.trim().isEmpty
          ? 'Storage вернул ошибку ${response.statusCode}'
          : 'Storage вернул ошибку ${response.statusCode}: ${body.trim()}',
    );
  } finally {
    client.close(force: true);
  }
}

class _NativeTaskPhotoHttpException implements Exception {
  final int status;
  final String message;

  const _NativeTaskPhotoHttpException(this.status, this.message);

  @override
  String toString() => message;
}
