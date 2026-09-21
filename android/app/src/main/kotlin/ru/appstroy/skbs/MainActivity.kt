package ru.appstroy.skbs

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val THEME_CHANNEL = "ru.appstroy.skbs/theme"
        private const val TASK_VOICE_CHANNEL = "ru.appstroy.skbs/task_voice"
        private const val TASK_PHOTO_CHANNEL = "ru.appstroy.skbs/task_photos"
        private const val TASK_VIDEO_CHANNEL = "ru.appstroy.skbs/task_videos"
        private const val TASK_VOICE_PERMISSION_REQUEST = 7401
        private const val TASK_PHOTO_PICK_REQUEST = 7402
        private const val TASK_VIDEO_PICK_REQUEST = 7403
        private const val PREFERENCES_FILE = "FlutterSharedPreferences"
        private const val THEME_PREFERENCE = "flutter.app_theme_mode"
        private const val LIGHT_LAUNCHER = "ru.appstroy.skbs.LauncherLight"
        private const val DARK_LAUNCHER = "ru.appstroy.skbs.LauncherDark"
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var speechResult: MethodChannel.Result? = null
    private var pendingSpeechLocale = "ru-RU"
    private var photoPickerResult: MethodChannel.Result? = null
    private var photoMaxDimension = 1440
    private var photoJpegQuality = 78
    private var videoPickerResult: MethodChannel.Result? = null
    private var videoMaxDurationMs = 60_000L
    private var videoTargetBytes = 6L * 1024L * 1024L
    private var videoMaxWidth = 960
    private var videoMaxHeight = 960

    override fun onCreate(savedInstanceState: Bundle?) {
        val dark = storedThemeIsDark()
        setTheme(if (dark) R.style.LaunchTheme_Dark else R.style.LaunchTheme)
        super.onCreate(savedInstanceState)
        applyWindowBackground(dark)
        applyLauncherIcon(dark)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THEME_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "applyTheme") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val dark = call.argument<Boolean>("dark") == true
                applyWindowBackground(dark)
                applyLauncherIcon(dark)
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "recognizeTask") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val locale = call.argument<String>("locale")?.trim().orEmpty()
                requestTaskSpeech(if (locale.isEmpty()) "ru-RU" else locale, result)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_PHOTO_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickPhotos") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val maxDimension = call.argument<Int>("maxDimension") ?: 1440
                val jpegQuality = call.argument<Int>("jpegQuality") ?: 78
                requestTaskPhotos(maxDimension, jpegQuality, result)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_VIDEO_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickVideos") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val maxDurationMs =
                    (call.argument<Number>("maxDurationMs")?.toLong() ?: 60_000L)
                        .coerceIn(1_000L, 60_000L)
                val targetBytes =
                    (call.argument<Number>("targetBytes")?.toLong()
                        ?: 6L * 1024L * 1024L)
                        .coerceIn(1L * 1024L * 1024L, 8L * 1024L * 1024L)
                val maxWidth = (call.argument<Int>("maxWidth") ?: 960)
                    .coerceIn(320, 1920)
                val maxHeight = (call.argument<Int>("maxHeight") ?: 960)
                    .coerceIn(320, 1920)
                requestTaskVideos(
                    maxDurationMs,
                    targetBytes,
                    maxWidth,
                    maxHeight,
                    result,
                )
            }
    }

    private fun requestTaskPhotos(
        maxDimension: Int,
        jpegQuality: Int,
        result: MethodChannel.Result,
    ) {
        if (photoPickerResult != null || videoPickerResult != null) {
            result.error("photo_busy", "Выбор медиа уже открыт.", null)
            return
        }

        photoPickerResult = result
        photoMaxDimension = maxDimension.coerceIn(640, 4096)
        photoJpegQuality = jpegQuality.coerceIn(45, 95)

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(
            Intent.createChooser(intent, "Выберите фотографии"),
            TASK_PHOTO_PICK_REQUEST,
        )
    }

    private fun requestTaskVideos(
        maxDurationMs: Long,
        targetBytes: Long,
        maxWidth: Int,
        maxHeight: Int,
        result: MethodChannel.Result,
    ) {
        if (photoPickerResult != null || videoPickerResult != null) {
            result.error("video_busy", "Выбор медиа уже открыт.", null)
            return
        }

        videoPickerResult = result
        videoMaxDurationMs = maxDurationMs
        videoTargetBytes = targetBytes
        videoMaxWidth = maxWidth
        videoMaxHeight = maxHeight

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(
            Intent.createChooser(intent, "Выберите видео"),
            TASK_VIDEO_PICK_REQUEST,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            TASK_PHOTO_PICK_REQUEST -> handleTaskPhotoPickerResult(resultCode, data)
            TASK_VIDEO_PICK_REQUEST -> handleTaskVideoPickerResult(resultCode, data)
        }
    }

    private fun handleTaskPhotoPickerResult(resultCode: Int, data: Intent?) {
        val callback = photoPickerResult ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            photoPickerResult = null
            callback.success(emptyList<Map<String, Any>>())
            return
        }

        val uris = collectUris(data)
        if (uris.isEmpty()) {
            photoPickerResult = null
            callback.success(emptyList<Map<String, Any>>())
            return
        }

        val maxDimension = photoMaxDimension
        val jpegQuality = photoJpegQuality
        Thread {
            try {
                val photos = uris.mapIndexed { index, uri ->
                    normalizePhoto(uri, index, maxDimension, jpegQuality)
                }
                runOnUiThread {
                    val current = photoPickerResult ?: return@runOnUiThread
                    photoPickerResult = null
                    current.success(photos)
                }
            } catch (error: Throwable) {
                runOnUiThread {
                    val current = photoPickerResult ?: return@runOnUiThread
                    photoPickerResult = null
                    current.error(
                        "photo_prepare_failed",
                        error.message ?: "Не удалось подготовить фотографию.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun handleTaskVideoPickerResult(resultCode: Int, data: Intent?) {
        val callback = videoPickerResult ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            videoPickerResult = null
            callback.success(emptyList<Map<String, Any>>())
            return
        }

        val uris = collectUris(data)
        if (uris.isEmpty()) {
            videoPickerResult = null
            callback.success(emptyList<Map<String, Any>>())
            return
        }

        val prepared = mutableListOf<Map<String, Any>>()
        prepareTaskVideo(
            uris = uris,
            index = 0,
            prepared = prepared,
            onDone = {
                val current = videoPickerResult ?: return@prepareTaskVideo
                videoPickerResult = null
                current.success(prepared)
            },
            onError = { error ->
                val current = videoPickerResult ?: return@prepareTaskVideo
                videoPickerResult = null
                current.error(
                    "video_prepare_failed",
                    error.message ?: "Не удалось подготовить видео.",
                    null,
                )
            },
        )
    }

    private fun collectUris(data: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        val clipData = data.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(index).uri
                if (!uris.contains(uri)) uris.add(uri)
            }
        }
        data.data?.let { uri ->
            if (!uris.contains(uri)) uris.add(uri)
        }
        return uris
    }

    @androidx.annotation.OptIn(UnstableApi::class)
    private fun prepareTaskVideo(
        uris: List<Uri>,
        index: Int,
        prepared: MutableList<Map<String, Any>>,
        onDone: () -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        if (index >= uris.size) {
            onDone()
            return
        }

        val uri = uris[index]
        val metadata = MediaMetadataRetriever()
        val durationMs: Long
        try {
            metadata.setDataSource(this, uri)
            durationMs = metadata
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: throw IllegalStateException("Не удалось определить длительность видео.")
        } catch (error: Throwable) {
            metadata.release()
            onError(error)
            return
        } finally {
            try {
                metadata.release()
            } catch (_: Throwable) {
                // ignore
            }
        }

        if (durationMs <= 0L || durationMs > videoMaxDurationMs) {
            onError(IllegalArgumentException("Видео должно быть не длиннее 1 минуты."))
            return
        }

        val durationSeconds = durationMs / 1000.0
        val audioBitrate = 96_000
        val targetTotalBitrate =
            ((videoTargetBytes.toDouble() * 8.0) / durationSeconds).toInt()
        val videoBitrate =
            (targetTotalBitrate - audioBitrate).coerceIn(450_000, 1_800_000)

        val outputFile = File(
            cacheDir,
            "task_video_${System.currentTimeMillis()}_${index + 1}.mp4",
        )
        if (outputFile.exists()) outputFile.delete()

        val presentation = Presentation.createForWidthAndHeight(
            videoMaxWidth,
            videoMaxHeight,
            Presentation.LAYOUT_SCALE_TO_FIT,
        )
        val mediaItem = MediaItem.fromUri(uri)
        val editedMediaItem = EditedMediaItem.Builder(mediaItem)
            .setEffects(Effects(emptyList(), listOf(presentation)))
            .build()

        val encoderFactory = DefaultEncoderFactory.Builder(this)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder()
                    .setBitrate(videoBitrate)
                    .build(),
            )
            .setRequestedAudioEncoderSettings(
                AudioEncoderSettings.Builder()
                    .setBitrate(audioBitrate)
                    .build(),
            )
            .build()

        val transformer = Transformer.Builder(this)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .addListener(
                object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: ExportResult,
                    ) {
                        Thread {
                            try {
                                val bytes = outputFile.readBytes()
                                if (bytes.isEmpty()) {
                                    throw IllegalStateException(
                                        "После сжатия видео получилось пустым.",
                                    )
                                }
                                if (bytes.size > 8 * 1024 * 1024) {
                                    throw IllegalStateException(
                                        "После сжатия видео всё ещё больше 8 МБ.",
                                    )
                                }
                                val sourceName = displayName(uri)
                                    .ifBlank { "video_${index + 1}" }
                                val baseName = sourceName.substringBeforeLast(
                                    '.',
                                    sourceName,
                                )
                                prepared.add(
                                    mapOf(
                                        "name" to "$baseName.mp4",
                                        "contentType" to "video/mp4",
                                        "extension" to "mp4",
                                        "durationSeconds" to
                                            kotlin.math.ceil(durationSeconds).toInt(),
                                        "bytes" to bytes,
                                    ),
                                )
                                outputFile.delete()
                                runOnUiThread {
                                    prepareTaskVideo(
                                        uris,
                                        index + 1,
                                        prepared,
                                        onDone,
                                        onError,
                                    )
                                }
                            } catch (error: Throwable) {
                                outputFile.delete()
                                runOnUiThread { onError(error) }
                            }
                        }.start()
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        outputFile.delete()
                        onError(exportException)
                    }
                },
            )
            .build()

        try {
            transformer.start(editedMediaItem, outputFile.absolutePath)
        } catch (error: Throwable) {
            outputFile.delete()
            onError(error)
        }
    }

    private fun normalizePhoto(
        uri: Uri,
        index: Int,
        maxDimension: Int,
        jpegQuality: Int,
    ): Map<String, Any> {
        val source = decodePhoto(uri)
            ?: throw IllegalStateException("Не удалось открыть выбранную фотографию.")
        val longestSide = maxOf(source.width, source.height)
        val target = if (longestSide > maxDimension) {
            val scale = maxDimension.toDouble() / longestSide.toDouble()
            val width = (source.width * scale).toInt().coerceAtLeast(1)
            val height = (source.height * scale).toInt().coerceAtLeast(1)
            Bitmap.createScaledBitmap(source, width, height, true)
        } else {
            source
        }

        val bytes = ByteArrayOutputStream().use { output ->
            val success = target.compress(
                Bitmap.CompressFormat.JPEG,
                jpegQuality,
                output,
            )
            if (!success) {
                throw IllegalStateException("Не удалось преобразовать фотографию в JPEG.")
            }
            output.toByteArray()
        }

        if (target !== source) target.recycle()
        source.recycle()

        val originalName = displayName(uri).ifBlank { "photo_${index + 1}" }
        val baseName = originalName.substringBeforeLast('.', originalName)
        return mapOf(
            "name" to "$baseName.jpg",
            "contentType" to "image/jpeg",
            "extension" to "jpg",
            "bytes" to bytes,
        )
    }

    private fun decodePhoto(uri: Uri): Bitmap? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(contentResolver, uri)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        } else {
            contentResolver.openInputStream(uri)?.use { stream ->
                BitmapFactory.decodeStream(stream)
            }
        }
    }

    private fun displayName(uri: Uri): String {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use ""
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column < 0) "" else cursor.getString(column).orEmpty()
            }.orEmpty()
        } catch (_: Throwable) {
            ""
        }
    }

    private fun requestTaskSpeech(locale: String, result: MethodChannel.Result) {
        if (speechResult != null) {
            result.error("speech_busy", "Голосовой ввод уже запущен.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            speechResult = result
            pendingSpeechLocale = locale
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                TASK_VOICE_PERMISSION_REQUEST,
            )
            return
        }

        startTaskSpeech(locale, result)
    }

    private fun startTaskSpeech(locale: String, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error(
                "speech_unavailable",
                "На телефоне недоступна служба распознавания речи.",
                null,
            )
            return
        }

        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        speechResult = result

        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit

            override fun onBeginningOfSpeech() = Unit

            override fun onRmsChanged(rmsdB: Float) = Unit

            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() = Unit

            override fun onError(error: Int) {
                finishSpeechError(speechErrorMessage(error))
            }

            override fun onResults(results: Bundle?) {
                val values = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = values?.firstOrNull()?.trim().orEmpty()
                if (text.isEmpty()) {
                    finishSpeechError("Речь не распознана. Попробуйте сказать задачу ещё раз.")
                } else {
                    finishSpeechSuccess(text)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) = Unit

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
        }
        recognizer.startListening(intent)
    }

    private fun finishSpeechSuccess(text: String) {
        val result = speechResult ?: return
        speechResult = null
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
        result.success(text)
    }

    private fun finishSpeechError(message: String) {
        val result = speechResult ?: return
        speechResult = null
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        result.error("speech_failed", message, null)
    }

    private fun speechErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                "Разрешите AppСтрой доступ к микрофону и повторите."
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                "Не услышал задачу. Попробуйте ещё раз."
            SpeechRecognizer.ERROR_AUDIO ->
                "Микрофон недоступен."
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
                "Не удалось распознать речь из-за сети. Попробуйте ещё раз."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                "Распознавание речи занято. Попробуйте ещё раз."
            else -> "Не удалось распознать голос. Попробуйте ещё раз."
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != TASK_VOICE_PERMISSION_REQUEST) return

        val result = speechResult ?: return
        speechResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error(
                "microphone_denied",
                "Разрешите AppСтрой доступ к микрофону и повторите.",
                null,
            )
            return
        }
        startTaskSpeech(pendingSpeechLocale, result)
    }

    override fun onDestroy() {
        speechResult?.error("speech_cancelled", "Голосовой ввод остановлен.", null)
        speechResult = null
        photoPickerResult?.error(
            "photo_cancelled",
            "Выбор фотографий остановлен.",
            null,
        )
        photoPickerResult = null
        videoPickerResult?.error(
            "video_cancelled",
            "Выбор видео остановлен.",
            null,
        )
        videoPickerResult = null
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        super.onDestroy()
    }

    private fun storedThemeIsDark(): Boolean {
        return getSharedPreferences(PREFERENCES_FILE, MODE_PRIVATE)
            .getString(THEME_PREFERENCE, "light") == "dark"
    }

    private fun applyWindowBackground(dark: Boolean) {
        window.setBackgroundDrawableResource(
            if (dark) R.color.app_splash_dark_background
            else R.color.app_splash_light_background,
        )
    }

    private fun applyLauncherIcon(dark: Boolean) {
        val manager = packageManager
        val lightComponent = ComponentName(this, LIGHT_LAUNCHER)
        val darkComponent = ComponentName(this, DARK_LAUNCHER)

        setComponentEnabled(manager, darkComponent, dark)
        setComponentEnabled(manager, lightComponent, !dark)
    }

    private fun setComponentEnabled(
        manager: PackageManager,
        component: ComponentName,
        enabled: Boolean,
    ) {
        val desiredState = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }

        if (manager.getComponentEnabledSetting(component) == desiredState) return

        manager.setComponentEnabledSetting(
            component,
            desiredState,
            PackageManager.DONT_KILL_APP,
        )
    }
}
