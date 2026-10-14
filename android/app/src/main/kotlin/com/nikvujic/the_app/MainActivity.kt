package com.nikvujic.the_app

import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.result.contract.ActivityResultContracts
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

    /// The notification sounds (Round 31), heard when picking one.
    private val notifySounds = mutableMapOf<String, Int>()

    /// The hold-to-take sound playing (Round 24), to stop on letting go.
    private var filling = 0

    /// The Placard's inflating sound while it plays (0: none), to stop it.
    private var inflating = 0

    /// Automatic backup (Round 39): the folder picker's answer goes here.
    private var folderPicked: MethodChannel.Result? = null
    private val pickFolder = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri -> folderChosen(uri) }

    companion object {
        private const val CLICK_VOLUME = 0.35f
        /// The medicine's gulp and Placard's sounds at full volume
        /// (Round 24: louder; the files are louder too).
        private const val DONE_VOLUME = 1f
        private const val PLACARD_VOLUME = 1f

        /// The pop stays as quiet as before (Round 25: only the inflating
        /// got louder).
        private const val POP_VOLUME = 0.3f
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Automatic backup to a folder picked once (Round 39).
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
                    else -> result.notImplemented()
                }
            }
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
        // The notification sounds to pick from (Round 31); notifications
        // play them themselves, this is for hearing one when picking.
        // Round 39: 8-bit ones.
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
                    "notify" -> {
                        val id = (call.arguments as? String)?.let { notifySounds[it] }
                        if (id != null) pool?.play(id, 1f, 1f, 1, 0, 1f)
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

    /// Writes [bytes] as a new [name] file in the folder [uri], then
    /// deletes the oldest files starting with [prefix] beyond [keep].
    private fun writeToFolder(
        uri: Uri, name: String, bytes: ByteArray, prefix: String, keep: Int
    ): Boolean {
        val file = DocumentsContract.createDocument(
            contentResolver, folderDocument(uri), "application/json", name
        ) ?: return false
        contentResolver.openOutputStream(file, "w")?.use { it.write(bytes) }
            ?: return false
        // Older ones, by name (a name holds its date and time).
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            uri, DocumentsContract.getTreeDocumentId(uri)
        )
        val ours = mutableListOf<Pair<String, String>>()
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null, null, null
        )?.use {
            while (it.moveToNext()) {
                val shown = it.getString(1) ?: continue
                if (shown.startsWith(prefix)) ours.add(it.getString(0) to shown)
            }
        }
        for ((id, _) in ours.sortedByDescending { it.second }.drop(keep)) {
            try {
                DocumentsContract.deleteDocument(
                    contentResolver, DocumentsContract.buildDocumentUriUsingTree(uri, id)
                )
            } catch (_: Exception) {
            }
        }
        return true
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
