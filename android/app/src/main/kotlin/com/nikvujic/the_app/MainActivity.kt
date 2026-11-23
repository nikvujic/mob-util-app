package com.nikvujic.the_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.provider.MediaStore
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.provider.DocumentsContract
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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
    private var fanfare = 0

    /// The notification sounds, heard when picking one.
    private val notifySounds = mutableMapOf<String, Int>()

    /// The hold-to-take sound playing, to stop on letting go.
    private var filling = 0

    /// The Placard's inflating sound while it plays (0: none), to stop it.
    private var inflating = 0

    /// Automatic backup: the folder picker's answer goes here.
    private var folderPicked: MethodChannel.Result? = null
    private val pickFolder = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri -> folderChosen(uri) }

    companion object {
        /// The ending of a backup still being written.
        private const val PARTIAL = ".partial"

        private const val CLICK_VOLUME = 0.35f
        /// The medicine's gulp and Placard's sounds at full volume (the
        /// files are loud too).
        private const val DONE_VOLUME = 1f
        private const val PLACARD_VOLUME = 1f

        /// The pop stays quiet; only the inflating is loud.
        private const val POP_VOLUME = 0.3f
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pip's charging station: whether the phone is plugged
        // in (no permission needed), now and as it changes while the app
        // is open.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/power")
            .setMethodCallHandler { call, result ->
                if (call.method == "plugged") result.success(isPlugged())
                else result.notImplemented()
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/power_changes")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var receiver: BroadcastReceiver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val listening = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            events.success(intent.action == Intent.ACTION_POWER_CONNECTED)
                        }
                    }
                    receiver = listening
                    // System broadcasts only: not open to other apps.
                    ContextCompat.registerReceiver(
                        this@MainActivity,
                        listening,
                        IntentFilter().apply {
                            addAction(Intent.ACTION_POWER_CONNECTED)
                            addAction(Intent.ACTION_POWER_DISCONNECTED)
                        },
                        ContextCompat.RECEIVER_NOT_EXPORTED,
                    )
                }

                override fun onCancel(arguments: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                }
            })
        // Spotify in the morning: the page's settings, kept for
        // the alarm (MorningMusic.kt), which is set again from them.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/morning_music")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                MorningMusic.save(
                    this,
                    call.argument<Boolean>("on") ?: false,
                    call.argument<Int>("minutes") ?: 7 * 60,
                    call.argument<List<Int>>("weekdays") ?: emptyList(),
                    call.argument<Int>("volume") ?: 30,
                )
                MorningMusic.schedule(this)
                result.success(null)
            }
        // A recipe open: the screen stays on while the app is in
        // front (Android lets it go dark again in the background).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/screen")
            .setMethodCallHandler { call, result ->
                // A barcode shown: the screen at full brightness (only this
                // window, only while it's in front); null gives it back.
                if (call.method == "brightness") {
                    val level = (call.arguments as? Number)?.toFloat()
                    val attributes = window.attributes
                    attributes.screenBrightness = level
                        ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    window.attributes = attributes
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "keepOn") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
        // Documents' Download: a copy of a picture into the phone's gallery.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/gallery")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name") ?: "Document"
                if (bytes == null) {
                    result.success(false)
                } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                    ContextCompat.checkSelfPermission(
                        this, Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    // Older Android asks first; the next try saves.
                    ActivityCompat.requestPermissions(
                        this, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 41
                    )
                    result.success(false)
                } else {
                    Thread {
                        val ok = try {
                            saveToGallery(bytes, name)
                        } catch (e: Exception) {
                            false
                        }
                        runOnUiThread { result.success(ok) }
                    }.start()
                }
            }
        // Automatic backup to a folder picked once.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/backup_folder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> {
                        folderPicked?.success(null)
                        folderPicked = result
                        pickFolder.launch(null)
                    }
                    "write" -> {
                        val folder = call.argument<String>("folder")
                        val name = call.argument<String>("name")
                        val bytes = call.argument<ByteArray>("bytes")
                        val prefix = call.argument<String>("prefix") ?: ""
                        val keep = call.argument<Int>("keep") ?: 7
                        if (folder == null || name == null || bytes == null) {
                            result.success(false)
                        } else {
                            // Off the main thread: it's file work.
                            Thread {
                                val ok = try {
                                    writeToFolder(Uri.parse(folder), name, bytes, prefix, keep)
                                } catch (e: Exception) {
                                    false
                                }
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    "list" -> {
                        val folder = call.argument<String>("folder")
                        val prefix = call.argument<String>("prefix") ?: ""
                        if (folder == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val found = try {
                                    val uri = Uri.parse(folder)
                                    dropPartials(uri, prefix)
                                    backupsIn(uri, prefix).map {
                                        mapOf(
                                            "name" to it.name,
                                            "bytes" to it.bytes,
                                            "modified" to it.modified
                                        )
                                    }
                                } catch (e: Exception) {
                                    null
                                }
                                runOnUiThread { result.success(found) }
                            }.start()
                        }
                    }
                    "prune" -> {
                        val folder = call.argument<String>("folder")
                        val prefix = call.argument<String>("prefix") ?: ""
                        val keep = call.argument<Int>("keep") ?: 7
                        if (folder == null) {
                            result.success(false)
                        } else {
                            Thread {
                                val ok = try {
                                    prune(Uri.parse(folder), prefix, keep)
                                    true
                                } catch (e: Exception) {
                                    false
                                }
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // The counters' click (U6): our own short sound, so it plays even
        // with the phone's "touch sounds" off. Played as game audio, so it
        // follows the media volume rather than the louder system volume.
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
        // A dose ticked off (medicine): a soft gulp.
        done = pool.load(this, R.raw.done, 1)
        // The Placard: rising while held, then a pop.
        inflate = pool.load(this, R.raw.inflate, 1)
        pop = pool.load(this, R.raw.pop, 1)
        // An important medicine's hold-to-take: a glass filling.
        fill = pool.load(this, R.raw.fill, 1)
        // Pip registered as an adventurer: his fanfare, his
        // only sound; on the media volume, like the rest.
        fanfare = pool.load(this, R.raw.fanfare, 1)
        // The notification sounds to pick from (8-bit ones); notifications
        // play them themselves, this is for hearing one when picking.
        notifySounds["notify_coin"] = pool.load(this, R.raw.notify_coin, 1)
        notifySounds["notify_powerup"] = pool.load(this, R.raw.notify_powerup, 1)
        notifySounds["notify_blip"] = pool.load(this, R.raw.notify_blip, 1)
        notifySounds["notify_alert"] = pool.load(this, R.raw.notify_alert, 1)
        notifySounds["notify_zap"] = pool.load(this, R.raw.notify_zap, 1)
        notifySounds["notify_jingle"] = pool.load(this, R.raw.notify_jingle, 1)
        sounds = pool
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_app/sound")
            .setMethodCallHandler { call, result ->
                val pool = sounds
                when (call.method) {
                    // Quieter than full: it's heard many times in a row.
                    "click" -> pool?.play(click, CLICK_VOLUME, CLICK_VOLUME, 1, 0, 1f)
                    "done" -> pool?.play(done, DONE_VOLUME, DONE_VOLUME, 1, 0, 1f)
                    // Silent: wakes the audio path, so the first real
                    // click isn't late against its buzz.
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
                    "pop" -> pool?.play(pop, POP_VOLUME, POP_VOLUME, 2, 0, 1f)
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
                    "fanfare" -> pool?.play(fanfare, 1f, 1f, 2, 0, 1f)
                    // At the volume picked (0 to 1).
                    "notify" -> {
                        val args = call.arguments as? Map<*, *>
                        val name = args?.get("sound") as? String ?: call.arguments as? String
                        val volume = (args?.get("volume") as? Number)?.toFloat() ?: 1f
                        val id = name?.let { notifySounds[it] }
                        if (id != null) pool?.play(id, volume, volume, 1, 0, 1f)
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            }
    }

    /// A folder picked: kept writable across restarts, and told to Dart
    /// with its name (null: cancelled).
    private fun folderChosen(uri: Uri?) {
        val result = folderPicked ?: return
        folderPicked = null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            result.success(mapOf("uri" to uri.toString(), "name" to folderName(uri)))
        } catch (e: Exception) {
            result.error("folder", e.message, null)
        }
    }

    /// The folder's own document, from its tree [uri].
    private fun folderDocument(uri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            uri, DocumentsContract.getTreeDocumentId(uri)
        )

    private fun folderName(uri: Uri): String {
        contentResolver.query(
            folderDocument(uri),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null
        )?.use { if (it.moveToFirst()) return it.getString(0) }
        return uri.lastPathSegment ?: "Folder"
    }

    /// A backup in the folder: its document id, name, size and when it
    /// was last changed (milliseconds since 1970).
    private data class FolderBackup(
        val id: String, val name: String, val bytes: Long, val modified: Long
    )

    /// The files in the folder [uri] whose names start with [prefix].
    private fun filesIn(uri: Uri, prefix: String): List<FolderBackup> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            uri, DocumentsContract.getTreeDocumentId(uri)
        )
        val found = mutableListOf<FolderBackup>()
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED
            ),
            null, null, null
        )?.use {
            while (it.moveToNext()) {
                val shown = it.getString(1) ?: continue
                if (!shown.startsWith(prefix)) continue
                found.add(
                    FolderBackup(
                        it.getString(0),
                        shown,
                        if (it.isNull(2)) 0L else it.getLong(2),
                        if (it.isNull(3)) 0L else it.getLong(3)
                    )
                )
            }
        }
        return found
    }

    /// The finished backups in the folder, newest first (a name holds
    /// its date and time).
    private fun backupsIn(uri: Uri, prefix: String): List<FolderBackup> =
        filesIn(uri, prefix)
            .filter { !it.name.endsWith(PARTIAL) }
            .sortedByDescending { it.name }

    private fun deleteIn(uri: Uri, id: String) {
        try {
            DocumentsContract.deleteDocument(
                contentResolver, DocumentsContract.buildDocumentUriUsingTree(uri, id)
            )
        } catch (_: Exception) {
        }
    }

    /// Deletes backups left half-written (the app closed while writing).
    private fun dropPartials(uri: Uri, prefix: String) {
        for (file in filesIn(uri, prefix)) {
            if (file.name.endsWith(PARTIAL)) deleteIn(uri, file.id)
        }
    }

    /// Deletes the oldest backups beyond [keep].
    private fun prune(uri: Uri, prefix: String, keep: Int) {
        for (file in backupsIn(uri, prefix).drop(keep)) deleteIn(uri, file.id)
    }

    /// Writes [bytes] as a new [name] file in the folder [uri]: first under
    /// a temporary name, renamed once complete, so a backup is never
    /// half-written. Then deletes leftovers and the oldest files starting
    /// with [prefix] beyond [keep].
    private fun writeToFolder(
        uri: Uri, name: String, bytes: ByteArray, prefix: String, keep: Int
    ): Boolean {
        dropPartials(uri, prefix)
        val file = DocumentsContract.createDocument(
            contentResolver, folderDocument(uri), "application/octet-stream",
            name + PARTIAL
        ) ?: return false
        try {
            contentResolver.openOutputStream(file, "w")?.use { it.write(bytes) }
                ?: throw IllegalStateException("no stream")
            DocumentsContract.renameDocument(contentResolver, file, name)
                ?: throw IllegalStateException("not renamed")
        } catch (e: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, file)
            } catch (_: Exception) {
            }
            return false
        }
        prune(uri, prefix, keep)
        return true
    }

    /// Saves [bytes] (a JPEG or PNG) into Pictures/The App as [name].
    private fun saveToGallery(bytes: ByteArray, name: String): Boolean {
        val png = bytes.size > 4 && bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte()
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name + if (png) ".png" else ".jpg")
            put(MediaStore.Images.Media.MIME_TYPE, if (png) "image/png" else "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/The App")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
        ) ?: return false
        try {
            contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                ?: throw IllegalStateException("no stream")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            return false
        }
        return true
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }

    /// Plugged in (charger, USB or wireless), charging or already full:
    /// the battery's last state, which Android keeps for anyone to read.
    private fun isPlugged(): Boolean {
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        return (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
    }
}
