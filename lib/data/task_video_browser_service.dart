import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import 'task_photo_browser_service.dart';
import 'task_photo_models.dart';

class TaskVideoBrowserService {
  static const int maxDurationSeconds = 60;
  static const int maxPreparedBytes = 8 * 1024 * 1024;
  static const Duration pickerTimeout = Duration(seconds: 90);
  static const MethodChannel _channel = MethodChannel(
    'ru.appstroy.skbs/task_videos',
  );

  const TaskVideoBrowserService._();

  static Future<List<TaskPhotoFile>> pickVideoFiles({
    void Function(int completed, int total)? onPrepareProgress,
  }) async {
    if (kIsWeb) {
      return _pickWebVideos(onPrepareProgress: onPrepareProgress);
    }

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final videos = await _pickNativeVideos();
      if (videos.isNotEmpty) {
        onPrepareProgress?.call(videos.length, videos.length);
      }
      return videos;
    }

    return _pickDesktopVideos(onPrepareProgress: onPrepareProgress);
  }

  static Future<List<TaskPhotoFile>> _pickNativeVideos() async {
    final rows = await _channel.invokeListMethod<dynamic>(
      'pickVideos',
      const <String, dynamic>{
        'maxDurationMs': maxDurationSeconds * 1000,
        'targetBytes': 6 * 1024 * 1024,
        'maxWidth': 960,
        'maxHeight': 960,
      },
    );
    if (rows == null || rows.isEmpty) return <TaskPhotoFile>[];

    final videos = <TaskPhotoFile>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<dynamic, dynamic>.from(raw);
      final rawBytes = row['bytes'];
      final bytes = switch (rawBytes) {
        Uint8List value => value,
        ByteData value => value.buffer.asUint8List(),
        _ => null,
      };
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > maxPreparedBytes) {
        throw Exception(
          'После сжатия видео всё ещё слишком большое. Максимум 8 МБ.',
        );
      }

      final durationSeconds =
          (row['durationSeconds'] as num?)?.round() ?? maxDurationSeconds;
      if (durationSeconds > maxDurationSeconds) {
        throw Exception('Видео должно быть не длиннее 1 минуты.');
      }

      final originalName = row['name']?.toString().trim();
      videos.add(
        TaskPhotoFile(
          originalName: originalName == null || originalName.isEmpty
              ? 'video_${videos.length + 1}.mp4'
              : originalName,
          contentType: row['contentType']?.toString().trim().isNotEmpty == true
              ? row['contentType'].toString().trim()
              : 'video/mp4',
          extension: row['extension']?.toString().trim().isNotEmpty == true
              ? row['extension'].toString().trim().toLowerCase()
              : 'mp4',
          bytes: bytes,
          mediaType: 'video',
          durationSeconds: durationSeconds,
        ),
      );
    }

    if (videos.isEmpty) {
      throw Exception('Не удалось подготовить выбранные видео.');
    }
    return videos;
  }

  static Future<List<TaskPhotoFile>> _pickWebVideos({
    void Function(int completed, int total)? onPrepareProgress,
  }) async {
    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = 'video/mp4,video/quicktime,video/webm,.mp4,.mov,.m4v,.webm';
    input.style.display = 'none';
    html.document.body?.append(input);

    final completer = Completer<List<html.File>>();
    late final StreamSubscription<html.Event> subscription;
    subscription = input.onChange.listen((_) {
      if (completer.isCompleted) return;
      completer.complete(input.files?.toList(growable: false) ?? <html.File>[]);
    });

    try {
      input.click();
      final files = await completer.future.timeout(
        pickerTimeout,
        onTimeout: () => <html.File>[],
      );
      if (files.isEmpty) return <TaskPhotoFile>[];

      final result = <TaskPhotoFile>[];
      onPrepareProgress?.call(0, files.length);
      for (final file in files) {
        if (file.size > maxPreparedBytes) {
          throw Exception(
            'В браузере видео должно быть не больше 8 МБ. '
            'В Android/iOS приложение само сжимает большие видео.',
          );
        }
        final duration = await _webVideoDuration(file);
        if (duration > maxDurationSeconds + 0.25) {
          throw Exception('Видео должно быть не длиннее 1 минуты.');
        }
        final extension = _extensionFromName(file.name);
        final bytes = await TaskPhotoBrowserService.readFileBytes(file);
        result.add(
          TaskPhotoFile(
            originalName: file.name,
            contentType: file.type.isEmpty
                ? _contentTypeForExtension(extension)
                : file.type,
            extension: extension.isEmpty ? 'mp4' : extension,
            bytes: bytes,
            mediaType: 'video',
            durationSeconds: duration.ceil(),
          ),
        );
        onPrepareProgress?.call(result.length, files.length);
      }
      return result;
    } finally {
      await subscription.cancel();
      input.remove();
    }
  }

  static Future<double> _webVideoDuration(html.File file) async {
    final objectUrl = html.Url.createObjectUrlFromBlob(file);
    final video = html.VideoElement()
      ..preload = 'metadata'
      ..src = objectUrl;
    try {
      await Future.any<void>(<Future<void>>[
        video.onLoadedMetadata.first.then((_) {}),
        video.onError.first.then<void>((_) {
          throw Exception('Не удалось определить длительность видео.');
        }),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('Не удалось определить длительность видео.'),
      );
      final duration = video.duration;
      if (duration.isNaN || duration.isInfinite || duration <= 0) {
        throw Exception('Не удалось определить длительность видео.');
      }
      return duration.toDouble();
    } finally {
      video.src = '';
      html.Url.revokeObjectUrl(objectUrl);
    }
  }

  static Future<List<TaskPhotoFile>> _pickDesktopVideos({
    void Function(int completed, int total)? onPrepareProgress,
  }) async {
    const typeGroup = XTypeGroup(
      label: 'Видео',
      extensions: <String>['mp4', 'mov', 'm4v'],
    );
    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
      confirmButtonText: 'Добавить',
    );
    if (files.isEmpty) return <TaskPhotoFile>[];

    final result = <TaskPhotoFile>[];
    onPrepareProgress?.call(0, files.length);
    for (final file in files) {
      final length = await file.length();
      if (length > maxPreparedBytes) {
        throw Exception(
          'На компьютере видео должно быть не больше 8 МБ. '
          'Автоматическое сжатие доступно в Android/iOS.',
        );
      }
      final bytes = await file.readAsBytes();
      final duration = _mp4DurationSeconds(bytes);
      if (duration == null) {
        throw Exception(
          'Не удалось определить длительность видео. '
          'Используйте MP4/MOV длительностью до 1 минуты.',
        );
      }
      if (duration > maxDurationSeconds + 0.25) {
        throw Exception('Видео должно быть не длиннее 1 минуты.');
      }
      final extension = _extensionFromName(file.name);
      result.add(
        TaskPhotoFile(
          originalName: file.name,
          contentType: _contentTypeForExtension(extension),
          extension: extension.isEmpty ? 'mp4' : extension,
          bytes: bytes,
          mediaType: 'video',
          durationSeconds: duration.ceil(),
        ),
      );
      onPrepareProgress?.call(result.length, files.length);
    }
    return result;
  }

  static String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    final extension = name.substring(dot + 1).toLowerCase();
    return const <String>{'mp4', 'mov', 'm4v', 'webm'}.contains(extension)
        ? extension
        : '';
  }

  static String _contentTypeForExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }

  static double? _mp4DurationSeconds(Uint8List bytes) {
    if (bytes.length < 32) return null;
    const mvhd = <int>[0x6d, 0x76, 0x68, 0x64];
    for (var i = 4; i <= bytes.length - 36; i++) {
      if (bytes[i] != mvhd[0] ||
          bytes[i + 1] != mvhd[1] ||
          bytes[i + 2] != mvhd[2] ||
          bytes[i + 3] != mvhd[3]) {
        continue;
      }

      final version = bytes[i + 4];
      if (version == 0 && i + 24 <= bytes.length) {
        final timescale = _readUint32(bytes, i + 16);
        final duration = _readUint32(bytes, i + 20);
        if (timescale > 0 && duration > 0) {
          return duration / timescale;
        }
      }
      if (version == 1 && i + 36 <= bytes.length) {
        final timescale = _readUint32(bytes, i + 24);
        final duration = _readUint64(bytes, i + 28);
        if (timescale > 0 && duration > 0) {
          return duration / timescale;
        }
      }
    }
    return null;
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _readUint64(Uint8List bytes, int offset) {
    final high = _readUint32(bytes, offset);
    final low = _readUint32(bytes, offset + 4);
    return high * 0x100000000 + low;
  }
}
