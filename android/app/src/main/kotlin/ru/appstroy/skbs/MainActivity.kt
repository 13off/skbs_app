package ru.appstroy.skbs

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val THEME_CHANNEL = "ru.appstroy.skbs/theme"
        private const val PREFERENCES_FILE = "FlutterSharedPreferences"
        private const val THEME_PREFERENCE = "flutter.app_theme_mode"
        private const val LIGHT_LAUNCHER = "ru.appstroy.skbs.LauncherLight"
        private const val DARK_LAUNCHER = "ru.appstroy.skbs.LauncherDark"
    }

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
