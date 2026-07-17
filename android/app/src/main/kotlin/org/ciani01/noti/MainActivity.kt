package org.ciani01.noti

import android.Manifest
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SPLASH_THEME_CHANNEL = "org.ciani01.noti/splash_theme"
        private const val MUSIC_DIRECTORY_CHANNEL = "org.ciani01.noti/music_directory"
        private const val DIRECTOR_WIDGET_CHANNEL = "org.ciani01.noti/director_widget"
        private const val DEVICE_AUTH_CHANNEL = "org.ciani01.noti/device_auth"
        const val DIRECTOR_WIDGET_ACTION = "org.ciani01.noti.OPEN_DIRECTOR_SONG_DELIVERY"

        private const val SPLASH_PREFERENCES = "noti_splash_theme"
        private const val SPLASH_COLOR_KEY = "background_color"
        private const val DEFAULT_SPLASH_COLOR = 0xFF5D55F6.toInt()
        private const val REQUEST_MUSIC_DIRECTORY = 7301
        private const val REQUEST_MUSIC_FILE = 7302
        private const val REQUEST_DEVICE_AUTH = 7303
        private const val REQUEST_MUSIC_PERMISSION = 7304
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
                    "getMusicDirectory" -> {
                        result.success(
                            if (hasDefaultMusicFolderAccess()) defaultMusicDirectory().absolutePath else null,
                        )
                    }
                    "chooseMusicDirectory", "requestMusicAccess" -> chooseMusicDirectory(result)
                    "pickMusicFile" -> pickMusicFile(result)
                    "listMusicFiles" -> result.success(listMusicFiles())
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
                when (call.method) {
                    "authenticateDevice" -> authenticateDevice(result)
                    "hasSecureDeviceCredential" -> result.success(hasSecureDeviceCredential())
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_MUSIC_DIRECTORY -> completeMusicDirectoryPermissionRequest()
            REQUEST_MUSIC_FILE -> completeMusicFileSelection(resultCode, data)
            REQUEST_DEVICE_AUTH -> completeDeviceAuthentication(resultCode)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_MUSIC_PERMISSION) {
            completeMusicDirectoryPermissionRequest()
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

    private fun hasSecureDeviceCredential(): Boolean {
        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        val biometricManager = BiometricManager.from(this)
        if (biometricManager.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS) {
            return true
        }

        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguard.isKeyguardSecure
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
        if (hasDefaultMusicFolderAccess()) {
            result.success(defaultMusicDirectory().absolutePath)
            return
        }
        pendingMusicDirectoryResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = try {
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName"),
                )
            } catch (_: Exception) {
                Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
            }
            startActivityForResult(intent, REQUEST_MUSIC_DIRECTORY)
            return
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
            REQUEST_MUSIC_PERMISSION,
        )
    }

    private fun completeMusicDirectoryPermissionRequest() {
        val result = pendingMusicDirectoryResult ?: return
        pendingMusicDirectoryResult = null
        if (!hasDefaultMusicFolderAccess()) {
            result.error(
                "folder_access_denied",
                "Noti needs storage access to use the shared Music folder.",
                null,
            )
            return
        }
        val musicDirectory = defaultMusicDirectory()
        if (!musicDirectory.exists()) {
            musicDirectory.mkdirs()
        }
        result.success(musicDirectory.absolutePath)
    }

    private fun hasDefaultMusicFolderAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    @Suppress("DEPRECATION")
    private fun defaultMusicDirectory(): File {
        return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
    }

    private fun pickMusicFile(result: MethodChannel.Result) {
        if (!hasDefaultMusicFolderAccess()) {
            result.error("music_folder_missing", "Allow Music folder access first.", null)
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
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/pdf",
                    "audio/*",
                    "text/*",
                    "application/msword",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    "application/vnd.ms-powerpoint",
                    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                ),
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            buildMusicInitialUri()?.let { initialUri ->
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
            }
        }
        startActivityForResult(intent, REQUEST_MUSIC_FILE)
    }

    private fun buildMusicInitialUri(): Uri? {
        return try {
            DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                "primary:${Environment.DIRECTORY_MUSIC}",
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun listMusicFiles(): List<Map<String, String>> {
        if (!hasDefaultMusicFolderAccess()) return emptyList()
        val root = defaultMusicDirectory()
        if (!root.exists()) return emptyList()
        val files = mutableListOf<Map<String, String>>()
        collectMusicFiles(root = root, current = root, prefix = "", files = files)
        return files.sortedBy { it["fileName"].orEmpty().lowercase() }
    }

    private fun collectMusicFiles(
        root: File,
        current: File,
        prefix: String,
        files: MutableList<Map<String, String>>,
    ) {
        val children = current.listFiles()?.sortedBy { it.name.lowercase() } ?: return
        for (child in children) {
            val name = child.name
            if (name.isBlank() || name.startsWith(".")) continue
            if (child.isDirectory) {
                collectMusicFiles(
                    root = root,
                    current = child,
                    prefix = if (prefix.isBlank()) name else "$prefix/$name",
                    files = files,
                )
            } else {
                val relativePath = if (prefix.isBlank()) name else "$prefix/$name"
                files.add(
                    mapOf(
                        "relativePath" to relativePath,
                        "fileName" to name,
                        "mimeType" to guessMimeType(name),
                    ),
                )
            }
        }
    }

    private fun completeMusicFileSelection(resultCode: Int, data: Intent?) {
        val result = pendingMusicFileResult ?: return
        pendingMusicFileResult = null
        val selectedUri = data?.data
        if (resultCode != RESULT_OK || selectedUri == null) {
            result.success(null)
            return
        }

        try {
            val songFile = uriToFile(selectedUri)
            if (songFile == null) {
                result.error(
                    "song_selection_failed",
                    "Noti could not read that file from Android.",
                    null,
                )
                return
            }
            val musicRoot = defaultMusicDirectory().canonicalFile
            val canonicalSong = songFile.canonicalFile
            if (!canonicalSong.path.startsWith(musicRoot.path)) {
                result.error(
                    "outside_music_folder",
                    "Choose a song or PDF inside the Music folder.",
                    null,
                )
                return
            }
            val relativePath = canonicalSong.relativeTo(musicRoot).invariantSeparatorsPath
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
        if (!hasDefaultMusicFolderAccess()) {
            result.error(
                "music_folder_missing",
                "Open Noti and allow Music folder access before opening songs.",
                null,
            )
            return
        }

        try {
            val songFile = File(defaultMusicDirectory(), relativePath)
            if (!songFile.exists() || !songFile.isFile) {
                result.error("invalid_song", "The song file could not be found in Music.", null)
                return
            }
            val songUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                songFile,
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

    private fun displayName(uri: Uri, fallback: String): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index) ?: fallback
            }
        }
        return fallback
    }

    private fun uriToFile(uri: Uri): File? {
        if (uri.scheme == "file") {
            return uri.path?.let(::File)
        }
        val displayName = displayName(uri, "")
        if (displayName.isBlank()) return null
        return findFileByName(defaultMusicDirectory(), displayName)
    }

    private fun findFileByName(root: File, targetName: String): File? {
        val children = root.listFiles() ?: return null
        for (child in children) {
            if (child.isDirectory) {
                val nested = findFileByName(child, targetName)
                if (nested != null) return nested
            } else if (child.name.equals(targetName, ignoreCase = true)) {
                return child
            }
        }
        return null
    }

    private fun guessMimeType(fileName: String): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".pdf") -> "application/pdf"
            lower.endsWith(".mp3") -> "audio/mpeg"
            lower.endsWith(".wav") -> "audio/wav"
            lower.endsWith(".m4a") -> "audio/mp4"
            lower.endsWith(".aac") -> "audio/aac"
            lower.endsWith(".flac") -> "audio/flac"
            lower.endsWith(".ogg") -> "audio/ogg"
            lower.endsWith(".txt") -> "text/plain"
            lower.endsWith(".doc") -> "application/msword"
            lower.endsWith(".docx") -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            lower.endsWith(".ppt") -> "application/vnd.ms-powerpoint"
            lower.endsWith(".pptx") -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            else -> "application/octet-stream"
        }
    }
}
