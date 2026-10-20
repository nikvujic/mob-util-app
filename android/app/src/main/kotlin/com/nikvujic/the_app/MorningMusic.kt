package com.nikvujic.the_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.SystemClock
import android.view.KeyEvent
import java.util.Calendar
import kotlin.math.roundToInt

/// Spotify in the morning (Round 93): at the time set on its page, on its
/// days, the music volume is set and play is pressed, so Spotify (or
/// whatever played last) carries on. Kept here, not in Dart, so it plays
/// with the app closed: each time it plays it sets the next one, and a
/// restart (or an update) sets it again.
object MorningMusic {
    private const val PREFS = "morning_music"
    const val ACTION_PLAY = "com.nikvujic.the_app.MORNING_MUSIC"
    private const val REQUEST = 931

    /// The page's settings, from Dart, kept for the alarm.
    fun save(context: Context, on: Boolean, minutes: Int, weekdays: List<Int>, volume: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("on", on)
            .putInt("minutes", minutes)
            .putString("weekdays", weekdays.joinToString(","))
            .putInt("volume", volume)
            .apply()
    }

    /// Sets the next one (or none, while off).
    fun schedule(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST,
            Intent(context, MorningMusicReceiver::class.java).setAction(ACTION_PLAY),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.cancel(pending)
        val weekdays = (prefs.getString("weekdays", "") ?: "")
            .split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
        val at = next(
            prefs.getBoolean("on", false),
            prefs.getInt("minutes", 7 * 60),
            weekdays,
            Calendar.getInstance(),
        ) ?: return
        // Exact where Android lets it (the app declares USE_EXACT_ALARM),
        // else as near as it allows.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } else {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    /// The next time after [now] on one of [weekdays] (Monday 1 … Sunday
    /// 7, as Dart counts) at [minutes]; null while off or with no day.
    fun next(on: Boolean, minutes: Int, weekdays: Set<Int>, now: Calendar): Long? {
        if (!on || weekdays.isEmpty()) return null
        for (days in 0..7) {
            val at = (now.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, days)
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val sunday = Calendar.SUNDAY
            val day = at.get(Calendar.DAY_OF_WEEK)
            val weekday = if (day == sunday) 7 else day - 1
            if (at.after(now) && weekday in weekdays) return at.timeInMillis
        }
        return null
    }

    /// Now: the music volume as set, then play pressed (down and up), for
    /// whichever app had the music last.
    fun play(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val volume = prefs.getInt("volume", 30).coerceIn(0, 100)
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        try {
            audio.setStreamVolume(
                AudioManager.STREAM_MUSIC, (max * volume / 100.0).roundToInt(), 0
            )
        } catch (_: SecurityException) {
            // Do Not Disturb can refuse it: play at the volume there is.
        }
        val time = SystemClock.uptimeMillis()
        audio.dispatchMediaKeyEvent(
            KeyEvent(time, time, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY, 0)
        )
        audio.dispatchMediaKeyEvent(
            KeyEvent(time, time, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY, 0)
        )
    }
}

/// The alarm going off (play, then the next one), and the phone restarted
/// or the app updated (the next one set again).
class MorningMusicReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == MorningMusic.ACTION_PLAY) MorningMusic.play(context)
        MorningMusic.schedule(context)
    }
}
