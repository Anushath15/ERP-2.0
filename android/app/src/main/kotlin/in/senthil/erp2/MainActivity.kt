package `in`.senthil.erp2

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// The few things only Android can do for the program (lib/core/android_bridge.dart is the other side):
///  * openUrl: a web or WhatsApp link, in the app that handles it;
///  * saveToDownloads: a file into the phone's Downloads/ASK ERP 2.0 folder, where the Files app shows it;
///  * share: a file (with words) to another app. With a phone number, straight into that person's WhatsApp chat; otherwise the phone's
///    Share menu, where the person picks the app;
///  * copyFileToDownloads / shareFile: the same two for a big file that already lies in the program's own folder (the backup), copied
///    by path so it never has to pass through memory. The Downloads copy REPLACES the one of the same name (one rolling copy, not a pile).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "in.senthil.erp2/bridge").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openUrl" -> result.success(openUrl(call.argument<String>("url") ?: ""))
                    "saveToDownloads" -> result.success(saveToDownloads(call.argument<ByteArray>("bytes") ?: ByteArray(0), call.argument<String>("name") ?: "", call.argument<String>("mime") ?: "application/octet-stream"))
                    "share" -> result.success(share(call.argument<ByteArray>("bytes") ?: ByteArray(0), call.argument<String>("name") ?: "", call.argument<String>("mime") ?: "application/octet-stream", call.argument<String>("text") ?: "", call.argument<String>("phone") ?: ""))
                    "copyFileToDownloads" -> result.success(copyFileToDownloads(call.argument<String>("path") ?: "", call.argument<String>("name") ?: "", call.argument<String>("mime") ?: "application/octet-stream"))
                    "shareFile" -> result.success(shareFile(call.argument<String>("path") ?: "", call.argument<String>("name") ?: "", call.argument<String>("mime") ?: "application/octet-stream", call.argument<String>("text") ?: ""))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(null)
            }
        }
    }

    /// SECURITY: only web and WhatsApp links are opened (never a file or another app's private link).
    private fun openUrl(url: String): Boolean {
        if (!(url.startsWith("https://") || url.startsWith("http://") || url.startsWith("whatsapp://"))) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /// A file name with no folder in it (the program cleans it too).
    private fun clean(name: String): String {
        val n = name.replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "-").trim().trimStart('.')
        return if (n.isEmpty()) "file" else n.take(120)
    }

    /// Downloads/ASK ERP 2.0/<name> (a second file of the same name gets a number from Android). Null on Android 9 and older, where the program
    /// offers the Share menu instead.
    private fun saveToDownloads(bytes: ByteArray, name: String, mime: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || bytes.isEmpty()) return null
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, clean(name))
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/ASK ERP 2.0")
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
        val out = contentResolver.openOutputStream(uri) ?: return null
        out.use { it.write(bytes) }
        return "Downloads/ASK ERP 2.0/" + clean(name)
    }

    /// A file of the program's own folder (never any other place), or null.
    private fun ownFile(path: String): File? {
        if (path.isEmpty()) return null
        val f = File(path)
        return try {
            if (f.isFile && f.canonicalPath.startsWith(filesDir.canonicalPath + File.separator)) f else null
        } catch (e: Exception) {
            null
        }
    }

    /// Downloads/ASK ERP 2.0/<name>, copied from a file of the program's folder. When this program already put a file of that name there it is
    /// overwritten (one rolling copy). Null on Android 9 and older.
    private fun copyFileToDownloads(path: String, name: String, mime: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val src = ownFile(path) ?: return null
        val display = clean(name)
        val folder = Environment.DIRECTORY_DOWNLOADS + "/ASK ERP 2.0"
        var uri: Uri? = null
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID),
            MediaStore.MediaColumns.DISPLAY_NAME + "=? AND " + MediaStore.MediaColumns.RELATIVE_PATH + " LIKE ?",
            arrayOf(display, "$folder%"),
            null,
        )?.use { c ->
            if (c.moveToFirst()) uri = android.content.ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, c.getLong(0))
        }
        if (uri == null) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, display)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            }
            uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
        }
        val out = contentResolver.openOutputStream(uri!!, "wt") ?: return null
        out.use { o -> src.inputStream().use { it.copyTo(o) } }
        return "Downloads/ASK ERP 2.0/$display"
    }

    /// The Share menu for a file of the program's folder ("menu"), or null when nothing could open.
    private fun shareFile(path: String, name: String, mime: String, text: String): String? {
        val src = ownFile(path) ?: return null
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, clean(name))
        src.inputStream().use { i -> file.outputStream().use { o -> i.copyTo(o) } }
        return sendFile(file, mime, text, "")
    }

    /// "whatsapp" when the person's chat opened with the file, "menu" when the Share menu opened, null when nothing could open.
    private fun share(bytes: ByteArray, name: String, mime: String, text: String, phone: String): String? {
        if (bytes.isEmpty()) return null
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        dir.listFiles()?.forEach { if (System.currentTimeMillis() - it.lastModified() > 24 * 3600 * 1000L) it.delete() } // old shared copies go
        val file = File(dir, clean(name))
        file.writeBytes(bytes)
        return sendFile(file, mime, text, phone)
    }

    private fun sendFile(file: File, mime: String, text: String, phone: String): String? {
        val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
        fun send() = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (phone.all { it.isDigit() } && phone.length in 8..15) {
            for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                try {
                    startActivity(send().setPackage(pkg).putExtra("jid", "$phone@s.whatsapp.net"))
                    return "whatsapp"
                } catch (e: ActivityNotFoundException) {
                    // this WhatsApp is not on the phone: the next one, then the Share menu
                }
            }
        }
        return try {
            startActivity(Intent.createChooser(send(), null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            "menu"
        } catch (e: ActivityNotFoundException) {
            null
        }
    }
}
