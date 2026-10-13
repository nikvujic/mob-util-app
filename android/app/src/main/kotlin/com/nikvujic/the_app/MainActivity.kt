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
    private var inflate = 0
    private var pop = 0
    private var fill = 0

    /// The hold-to-take sound playing (Round 24), to stop on letting go.
    private var filling = 0

    /// The Placard's inflating sound while it plays (0: none), to stop it.
    private var inflating = 0

    companion object {
        private const val CLICK_VOLUME = 0.35f
        /// The medicine's gulp and Placard's sounds at full volume
        /// (Round 24: louder; the files are louder too).
        private const val DONE_VOLUME = 1f
        private const val PLACARD_VOLUME = 1f
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
        // The Placard (Round 17): rising while held, then a pop.
        inflate = pool.load(this, R.raw.inflate, 1)
        pop = pool.load(this, R.raw.pop, 1)
        // An important medicine's hold-to-take (Round 24): a glass filling.
        fill = pool.load(this, R.raw.fill, 1)
        sounds = pool
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/sound")
            .setMethodCallHandler { call, result ->
                val pool = sounds
                when (call.method) {
                    // Quieter than full: it's heard many times in a row.
                    "click" -> pool?.play(click, CLICK_VOLUME, CLICK_VOLUME, 1, 0, 1f)
                    "done" -> pool?.play(done, DONE_VOLUME, DONE_VOLUME, 1, 0, 1f)
                    // Silent: wakes the audio path, so the first real
                    // click isn't late against its buzz (Round 18).
                    "warm" -> pool?.play(click, 0f, 0f, 0, 0, 1f)
                    "inflate" -> {
                        if (inflating != 0) pool?.stop(inflating)
                        inflating = pool?.play(
                            inflate, PLACARD_VOLUME, PLACARD_VOLUME, 1, 0, 1f
                        ) ?: 0
                    }
                    "stopInflate" -> {
                        if (inflating != 0) pool?.stop(inflating)
                        inflating = 0
                    }
                    "pop" -> pool?.play(pop, PLACARD_VOLUME, PLACARD_VOLUME, 2, 0, 1f)
                    "fill" -> {
                        if (filling != 0) pool?.stop(filling)
                        filling = pool?.play(
                            fill, DONE_VOLUME, DONE_VOLUME, 1, 0, 1f
                        ) ?: 0
                    }
                    "stopFill" -> {
                        if (filling != 0) pool?.stop(filling)
                        filling = 0
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            }
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
