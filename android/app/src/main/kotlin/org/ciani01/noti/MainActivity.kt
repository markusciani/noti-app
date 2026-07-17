package org.ciani01.noti

import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SPLASH_THEME_CHANNEL = "org.ciani01.noti/splash_theme"
        private const val MUSIC_DIRECTORY_CHANNEL = "org.ciani01.noti/music_directory"
        private const val DIRECTOR_WIDGET_CHANNEL = "org.ciani01.noti/director_widget"
        private const val DEVICE_AUTH_CHANNEL = "org.ciani01.noti/device_auth"
        const val DIRECTOR_WIDGET_ACTION = "org.ciani01.noti.OPEN_DIRECTOR_SONG_DELIVERY"

        private const val SPLASH_PREFERENCES = "noti_splash_theme"
        private const val SPLASH_COLOR_KEY = "background_color"
        private const val MUSIC_PREFERENCES = "noti_music_directory"
        private const val MUSIC_DIRECTORY_URI_KEY = "tree_uri"
        private const val DEFAULT_SPLASH_COLOR = 0xFF5D55F6.toInt()
        private const val REQUEST_MUSIC_DIRECTORY = 7301
        private const val REQUEST_MUSIC_FILE = 7302
        private const val REQUEST_DEVICE_AUTH = 7303
    }

    private var pendingMusicDirectoryResult: MethodChannel.Result? = null
    private var pendingMusicFileResult: MethodChannel.Result? = null
    private var directorWidgetChannel: MethodChannel? = null
    private var pendingDeviceAuthResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 12 shows its static system splash first. Once the activity
        // starts, use the last Flutter theme color for the remaining transition.
        val color = getSharedPreferences(SPLASH_PREFERENCES, MODE_PRIVATE)
            .getInt(SPLASH_COLOR_KEY, DEFAULT_SPLASH_COLOR)
        window.setBackgroundDrawable(ColorDrawable(color))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == DIRECTOR_WIDGET_ACTION) {
            directorWidgetChannel?.invokeMethod("openDirectorSongDelivery", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPLASH_THEME_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "cacheBackgroundColor") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                // Dart's standard message codec represents integer values as a
                // Long on Android, even when the ARGB value fits in an Int.
                val color = (call.argument<Number>("argbColor"))?.toInt()
                if (color == null) {
                    result.error("invalid_color", "A splash color is required.", null)
                    return@setMethodCallHandler
                }

                getSharedPreferences(SPLASH_PREFERENCES, MODE_PRIVATE)
                    .edit()
                    .putInt(SPLASH_COLOR_KEY, color)
                    .apply()
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MUSIC_DIRECTORY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMusicDirectory" -> result.success(savedMusicDirectory()?.toString())
                    "chooseMusicDirectory", "requestMusicAccess" -> chooseMusicDirectory(result)
                    "pickMusicFile" -> pickMusicFile(result)
                    "openMusicFile" -> openMusicFile(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }

        directorWidgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DIRECTOR_WIDGET_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "getLaunchAction") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(intent?.action == DIRECTOR_WIDGET_ACTION)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_AUTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "authenticateDevice") {
                    authenticateDevice(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_MUSIC_DIRECTORY -> completeMusicDirectorySelection(resultCode, data)
            REQUEST_MUSIC_FILE -> completeMusicFileSelection(resultCode, data)
            REQUEST_DEVICE_AUTH -> completeDeviceAuthentication(resultCode)
        }
    }

    @Suppress("DEPRECATION")
    private fun authenticateDevice(result: MethodChannel.Result) {
        if (pendingDeviceAuthResult != null) {
            result.error("auth_busy", "Device authentication is already open.", null)
            return
        }
        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        val biometricManager = BiometricManager.from(this)
        if (biometricManager.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS) {
            val executor = ContextCompat.getMainExecutor(this)
            val prompt = BiometricPrompt(
                this,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        completeDeviceAuthentication(true)
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence,
                    ) {
                        completeDeviceAuthentication(false)
                    }
                },
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Director access")
                .setSubtitle("Use fingerprint, face unlock, or the tablet lock screen")
                .setAllowedAuthenticators(authenticators)
                .build()
            pendingDeviceAuthResult = result
            prompt.authenticate(promptInfo)
            return
        }

        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguard.isKeyguardSecure) {
            result.error(
                "device_lock_missing",
                "Set a device PIN, pattern, or password first.",
                null,
            )
            return
        }
        val intent = keyguard.createConfirmDeviceCredentialIntent(
            "Director access",
            "Confirm your device PIN, pattern, password, or biometric to open Noti Director.",
        )
        if (intent == null) {
            result.error("device_auth_unavailable", "Device authentication is unavailable.", null)
            return
        }
        pendingDeviceAuthResult = result
        startActivityForResult(intent, REQUEST_DEVICE_AUTH)
    }

    private fun completeDeviceAuthentication(resultCode: Int) {
        completeDeviceAuthentication(resultCode == RESULT_OK)
    }

    private fun completeDeviceAuthentication(success: Boolean) {
        val result = pendingDeviceAuthResult ?: return
        pendingDeviceAuthResult = null
        result.success(success)
    }

    private fun chooseMusicDirectory(result: MethodChannel.Result) {
        if (pendingMusicDirectoryResult != null) {
            result.error("picker_busy", "The music folder picker is already open.", null)
            return
        }
        pendingMusicDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, REQUEST_MUSIC_DIRECTORY)
    }

    private fun completeMusicDirectorySelection(resultCode: Int, data: Intent?) {
        val result = pendingMusicDirectoryResult ?: return
        pendingMusicDirectoryResult = null
        val selectedUri = data?.data
        if (resultCode != RESULT_OK || selectedUri == null) {
            result.success(null)
            return
        }

        val flags = data.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        try {
            contentResolver.takePersistableUriPermission(selectedUri, flags)
            val musicUri = findMusicDirectory(selectedUri)
            if (musicUri == null) {
                result.error(
                    "music_folder_missing",
                    "Noti could not find a Music folder in the selected storage location.",
                    null,
                )
                return
            }
            getSharedPreferences(MUSIC_PREFERENCES, MODE_PRIVATE)
                .edit()
                .putString(MUSIC_DIRECTORY_URI_KEY, musicUri.toString())
                .apply()
            result.success(musicUri.toString())
        } catch (error: SecurityException) {
            result.error("folder_access_denied", "Noti could not keep access to this folder.", error.message)
        }
    }

    private fun findMusicDirectory(storageTreeUri: Uri): Uri? {
        val treeDocumentId = DocumentsContract.getTreeDocumentId(storageTreeUri)
        val selectedName = displayName(storageTreeUri, "")
        if (selectedName.equals("Music", ignoreCase = true)) return storageTreeUri

        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            storageTreeUri,
            treeDocumentId,
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameIndex).orEmpty()
                val mime = cursor.getString(mimeIndex).orEmpty()
                if (name.equals("Music", ignoreCase = true) &&
                    mime == DocumentsContract.Document.MIME_TYPE_DIR
                ) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        storageTreeUri,
                        cursor.getString(idIndex),
                    )
                }
            }
        }
        return null
    }

    private fun pickMusicFile(result: MethodChannel.Result) {
        if (savedMusicDirectory() == null) {
            result.error("music_folder_missing", "Choose the shared music folder first.", null)
            return
        }
        if (pendingMusicFileResult != null) {
            result.error("picker_busy", "The song picker is already open.", null)
            return
        }
        pendingMusicFileResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_MUSIC_FILE)
    }

    private fun completeMusicFileSelection(resultCode: Int, data: Intent?) {
        val result = pendingMusicFileResult ?: return
        pendingMusicFileResult = null
        val selectedUri = data?.data
        if (resultCode != RESULT_OK || selectedUri == null) {
            result.success(null)
            return
        }

        val treeUri = savedMusicDirectory()
        if (treeUri == null) {
            result.error("music_folder_missing", "Choose the shared music folder first.", null)
            return
        }

        try {
            val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
            val fileDocumentId = DocumentsContract.getDocumentId(selectedUri)
            val prefix = "$treeDocumentId/"
            if (fileDocumentId != treeDocumentId && !fileDocumentId.startsWith(prefix)) {
                result.error(
                    "outside_music_folder",
                    "Choose a song inside the selected shared music folder.",
                    null,
                )
                return
            }
            val relativePath = fileDocumentId.removePrefix(prefix)
            if (relativePath.isBlank()) {
                result.error("invalid_song", "Choose a song file, not the music folder itself.", null)
                return
            }
            result.success(
                mapOf(
                    "relativePath" to relativePath,
                    "fileName" to displayName(selectedUri, relativePath.substringAfterLast('/')),
                    "mimeType" to (contentResolver.getType(selectedUri) ?: "application/octet-stream"),
                ),
            )
        } catch (error: Exception) {
            result.error("song_selection_failed", "Noti could not read that song file.", error.message)
        }
    }

    private fun openMusicFile(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val relativePath = (arguments?.get("relativePath") as? String)?.trim().orEmpty()
        val mimeType = (arguments?.get("mimeType") as? String)?.trim().orEmpty()
        if (relativePath.isBlank() || relativePath.startsWith('/') || relativePath.split('/').contains("..")) {
            result.error("invalid_song", "The song path is invalid.", null)
            return
        }
        val treeUri = savedMusicDirectory()
        if (treeUri == null) {
            result.error(
                "music_folder_missing",
                "Open Noti and choose the shared music folder before opening songs.",
                null,
            )
            return
        }

        try {
            val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
            val songUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                "$treeDocumentId/$relativePath",
            )
            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(songUri, mimeType.ifBlank { "application/octet-stream" })
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(viewIntent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "no_file_app",
                "No installed app can open this song file type.",
                error.message,
            )
        } catch (error: Exception) {
            result.error("song_open_failed", "Noti could not open this song file.", error.message)
        }
    }

    private fun savedMusicDirectory(): Uri? {
        val stored = getSharedPreferences(MUSIC_PREFERENCES, MODE_PRIVATE)
            .getString(MUSIC_DIRECTORY_URI_KEY, null)
            ?: return null
        return Uri.parse(stored)
    }

    private fun displayName(uri: Uri, fallback: String): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index) ?: fallback
            }
        }
        return fallback
    }
}
