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
    private var done = 0

    companion object {
        private const val CLICK_VOLUME = 0.35f
        private const val DONE_VOLUME = 0.7f
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The counters' click (U6): our own short sound, so it plays even
        // with the phone's "touch sounds" off. Played as game audio, so it
        // follows the media volume (Round 16: it had followed the system
        // volume, too loud).
        val pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
        click = pool.load(this, R.raw.click, 1)
        // A dose ticked off (medicine): a soft gulp (Round 16).
        done = pool.load(this, R.raw.done, 1)
        sounds = pool
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "click") {
                    // Quieter than full: it's heard many times in a row.
                    sounds?.play(click, CLICK_VOLUME, CLICK_VOLUME, 1, 0, 1f)
                    result.success(null)
                } else if (call.method == "done") {
                    sounds?.play(done, DONE_VOLUME, DONE_VOLUME, 1, 0, 1f)
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
