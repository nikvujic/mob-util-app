package com.nikvujic.the_app

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: Android's fingerprint prompt (biometric_storage) needs
// one.
class MainActivity: FlutterFragmentActivity() {
    private var sounds: SoundPool? = null
    private var click = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The counters' click (U6): our own short sound, so it plays even
        // with the phone's "touch sounds" off. Sonification follows the
        // system volume and stays quiet in silent mode.
        val pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
        click = pool.load(this, R.raw.click, 1)
        sounds = pool
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "click") {
                    sounds?.play(click, 1f, 1f, 1, 0, 1f)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
