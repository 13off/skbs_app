package ru.appstroy.skbs

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val THEME_CHANNEL = "ru.appstroy.skbs/theme"
        private const val TASK_VOICE_CHANNEL = "ru.appstroy.skbs/task_voice"
        private const val TASK_PHOTO_CHANNEL = "ru.appstroy.skbs/task_photos"
        private const val TASK_VOICE_PERMISSION_REQUEST = 7401
        private const val TASK_PHOTO_PICK_REQUEST = 7402
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
    }

    private fun requestTaskPhotos(
        maxDimension: Int,
        jpegQuality: Int,
        result: MethodChannel.Result,
    ) {
        if (photoPickerResult != null) {
            result.error("photo_busy", "Выбор фотографий уже открыт.", null)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != TASK_PHOTO_PICK_REQUEST) return

        val callback = photoPickerResult ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            photoPickerResult = null
            callback.success(emptyList<Map<String, Any>>())
            return
        }

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
