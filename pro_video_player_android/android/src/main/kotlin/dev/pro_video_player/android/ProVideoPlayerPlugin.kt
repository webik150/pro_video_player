package dev.pro_video_player.android

import android.app.Activity
import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import dev.pro_video_player.pro_video_player_android.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

class ProVideoPlayerPlugin: FlutterPlugin, ActivityAware, Application.ActivityLifecycleCallbacks, ProVideoPlayerHostApi {
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    private lateinit var flutterApi: ProVideoPlayerFlutterApi

    private val players = mutableMapOf<Int, VideoPlayer>()
    private var nextPlayerId = 0

    // Track players that were paused due to app going to background
    private val pausedForBackground = mutableSetOf<Int>()

    // Battery monitoring
    private var batteryReceiver: BroadcastReceiver? = null

    companion object {
        private const val TAG = "ProVideoPlayerPlugin"

        /// Global verbose logging flag for Android video player
        @Volatile
        var isVerboseLoggingEnabled: Boolean = false
            private set

        /// Helper function for verbose logging
        fun verboseLog(message: String, tag: String = TAG) {
            if (isVerboseLoggingEnabled) {
                android.util.Log.d(tag, message)
            }
        }

        /// Set verbose logging (public for Pigeon handler)
        fun setVerboseLogging(enabled: Boolean) {
            isVerboseLoggingEnabled = enabled
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        context = binding.applicationContext

        // Initialize FlutterApi for native → Dart callbacks
        flutterApi = ProVideoPlayerFlutterApi(binding.binaryMessenger)

        // Start battery monitoring
        startBatteryMonitoring()

        // Register the platform view factory
        binding.platformViewRegistry.registerViewFactory(
            "dev.pro_video_player.android/video_view",
            VideoPlayerViewFactory(this)
        )

        // Register the MediaRouteButton platform view factory for Chromecast
        // Note: Uses AppCompat theme overlay to fix "background can not be translucent" error
        binding.platformViewRegistry.registerViewFactory(
            "dev.pro_video_player.android/cast_button",
            MediaRouteButtonViewFactory(binding.binaryMessenger)
        )

        // Register Pigeon API - this plugin implements ProVideoPlayerHostApi directly
        ProVideoPlayerHostApi.setUp(binding.binaryMessenger, this)
    }

    fun getPlayer(playerId: Int): VideoPlayer? = players[playerId]

    fun getActivity(): Activity? = activity

    fun createPlayer(source: Map<String, Any>, options: Map<String, Any>): Int {
        val playerId = nextPlayerId++
        val player = VideoPlayer(
            playerId = playerId,
            context = context,
            messenger = flutterPluginBinding.binaryMessenger,
            source = source,
            options = options
        )
        // Wire up FlutterApi for native → Dart callbacks
        player.flutterApi = flutterApi
        players[playerId] = player
        return playerId
    }

    fun removePlayer(playerId: Int) {
        players.remove(playerId)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        players.values.forEach { it.dispose() }
        players.clear()

        // Stop battery monitoring
        stopBatteryMonitoring()

        // Unregister Pigeon API
        ProVideoPlayerHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.activity.application.registerActivityLifecycleCallbacks(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity?.application?.unregisterActivityLifecycleCallbacks(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.activity.application.registerActivityLifecycleCallbacks(this)
    }

    override fun onDetachedFromActivity() {
        activity?.application?.unregisterActivityLifecycleCallbacks(this)
        activity = null
    }

    // MARK: - Application.ActivityLifecycleCallbacks

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}

    override fun onActivityStarted(activity: Activity) {}

    override fun onActivityResumed(activity: Activity) {
        // Notify all players that app is in foreground (for wake lock management)
        if (activity == this.activity) {
            players.forEach { (_, player) ->
                player.onAppForeground()
            }

            // Resume players that were paused when app went to background
            pausedForBackground.forEach { playerId ->
                players[playerId]?.play()
            }
            pausedForBackground.clear()
        }
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity == this.activity) {
            // Notify all players that app is in background (for wake lock management)
            players.forEach { (_, player) ->
                player.onAppBackground()
            }

            // Pause players that don't allow background playback when app goes to background
            players.forEach { (playerId, player) ->
                if (!player.allowsBackgroundPlayback() && player.isPlaying()) {
                    player.pause()
                    pausedForBackground.add(playerId)
                }
            }
        }
    }

    override fun onActivityStopped(activity: Activity) {}

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    override fun onActivityDestroyed(activity: Activity) {}

    // MARK: - Battery Monitoring

    private fun startBatteryMonitoring() {
        // Register broadcast receiver for battery changes
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }

        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                sendBatteryUpdate()
            }
        }

        context.registerReceiver(batteryReceiver, filter)

        // Send initial battery state
        sendBatteryUpdate()
    }

    private fun stopBatteryMonitoring() {
        // Unregister battery receiver
        batteryReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered, ignore
            }
        }
        batteryReceiver = null
    }

    private fun sendBatteryUpdate() {
        try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (batteryManager == null) {
                return
            }

            val percentage = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            if (percentage < 0 || percentage > 100) {
                return
            }

            val batteryStatus = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                           status == BatteryManager.BATTERY_STATUS_FULL

            val batteryInfo = BatteryInfoMessage(
                percentage = percentage.toLong(),
                isCharging = isCharging
            )
            flutterApi.onBatteryInfoChanged(batteryInfo) {}
        } catch (e: Exception) {
            // Battery info not available - ignore
        }
    }

    // MARK: - ProVideoPlayerHostApi Implementation

    // MARK: - Core Playback Methods

    override fun create(
        source: VideoSourceMessage,
        options: VideoPlayerOptionsMessage,
        callback: (Result<Long>) -> Unit
    ) {
        try {
            // Convert Pigeon messages to Map format expected by plugin
            val sourceMap = convertVideoSourceToMap(source)
            val optionsMap = convertPlayerOptionsToMap(options)

            // Resolve asset path if needed
            val resolvedSource = if (source.type == VideoSourceType.ASSET) {
                resolveAssetPath(sourceMap)
            } else {
                sourceMap
            }

            // Create player using plugin's existing create logic
            val playerId = createPlayer(resolvedSource, optionsMap)
            callback(Result.success(playerId.toLong()))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CREATE_ERROR", e.message, null)))
        }
    }

    private fun resolveAssetPath(source: Map<String, Any>): Map<String, Any> {
        val assetPath = source["assetPath"] as? String ?: return source
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        val resolvedPath = flutterLoader.getLookupKeyForAsset(assetPath)
        return source.toMutableMap().apply {
            put("assetPath", resolvedPath)
        }
    }

    override fun dispose(playerId: Long, callback: (Result<Unit>) -> Unit) {
        try {
            val player = getPlayer(playerId.toInt())
            if (player == null) {
                callback(Result.failure(FlutterError("INVALID_PLAYER", "Player not found", null)))
                return
            }
            player.dispose()
            removePlayer(playerId.toInt())
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("DISPOSE_ERROR", e.message, null)))
        }
    }

    override fun play(playerId: Long, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.play() }, callback)
    }

    override fun pause(playerId: Long, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.pause() }, callback)
    }

    override fun stop(playerId: Long, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.stop() }, callback)
    }

    override fun seekTo(playerId: Long, positionMs: Long, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.seekTo(positionMs) }, callback)
    }

    override fun setPlaybackSpeed(playerId: Long, speed: Double, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.setPlaybackSpeed(speed.toFloat()) }, callback)
    }

    override fun setVolume(playerId: Long, volume: Double, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.setVolume(volume.toFloat()) }, callback)
    }

    override fun getPosition(playerId: Long, callback: (Result<Long>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val position = player.getPosition()
            callback(Result.success(position))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("POSITION_ERROR", e.message, null)))
        }
    }

    override fun getDuration(playerId: Long, callback: (Result<Long>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val duration = player.getDuration()
            callback(Result.success(duration))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("DURATION_ERROR", e.message, null)))
        }
    }

    // MARK: - Configuration Methods

    override fun getPlatformInfo(callback: (Result<PlatformInfoMessage>) -> Unit) {
        try {
            val message = PlatformInfoMessage(
                platformName = "Android",
                nativePlayerType = "ExoPlayer",
                additionalInfo = mapOf(
                    "osVersion" to Build.VERSION.RELEASE,
                    "sdkVersion" to Build.VERSION.SDK_INT,
                    "pipAvailable" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                )
            )
            callback(Result.success(message))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("PLATFORM_INFO_ERROR", e.message, null)))
        }
    }

    override fun setVerboseLogging(enabled: Boolean, callback: (Result<Unit>) -> Unit) {
        try {
            ProVideoPlayerPlugin.setVerboseLogging(enabled)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("LOGGING_ERROR", e.message, null)))
        }
    }

    // MARK: - Platform Capabilities

    override fun supportsPictureInPicture(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O))
    }

    override fun supportsFullscreen(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsBackgroundPlayback(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsCasting(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsAirPlay(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(false))
    }

    override fun supportsChromecast(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsRemotePlayback(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(false))
    }

    override fun supportsQualitySelection(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsPlaybackSpeedControl(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsSubtitles(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsExternalSubtitles(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsAudioTrackSelection(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsChapters(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsVideoMetadataExtraction(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsNetworkMonitoring(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsBandwidthEstimation(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsAdaptiveBitrate(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsHLS(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsDASH(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsDeviceVolumeControl(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun supportsScreenBrightnessControl(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    // MARK: - Codec Compatibility

    override fun checkCodecSupport(codec: CodecInfoMessage, callback: (Result<CodecCompatibilityMessage>) -> Unit) {
        verboseLog("checkCodecSupport() called for codec: ${codec.name} (${codec.fourcc})", TAG)
        try {
            val result = checkCodecSupportInternal(codec)
            callback(Result.success(result))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CODEC_ERROR", e.message, null)))
        }
    }

    override fun checkCodecsSupport(codecs: List<CodecInfoMessage?>, callback: (Result<List<CodecCompatibilityMessage?>>) -> Unit) {
        verboseLog("checkCodecsSupport() called for ${codecs.size} codecs", TAG)
        try {
            val results = codecs.map { codec ->
                codec?.let { checkCodecSupportInternal(it) }
            }
            callback(Result.success(results))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CODEC_ERROR", e.message, null)))
        }
    }

    override fun getSupportedCodecs(callback: (Result<List<String?>>) -> Unit) {
        verboseLog("getSupportedCodecs() called", TAG)
        try {
            val codecsToCheck = listOf(
                // Video codecs
                Triple("H.264", "video/avc", "avc1"),
                Triple("HEVC", "video/hevc", "hvc1"),
                Triple("VP8", "video/x-vnd.on2.vp8", "vp08"),
                Triple("VP9", "video/x-vnd.on2.vp9", "vp09"),
                Triple("AV1", "video/av01", "av01"),
                Triple("MPEG-4", "video/mp4v-es", "mp4v"),
                // Audio codecs
                Triple("AAC", "audio/mp4a-latm", "mp4a"),
                Triple("MP3", "audio/mpeg", ".mp3"),
                Triple("Opus", "audio/opus", "opus"),
                Triple("Vorbis", "audio/vorbis", "vorb"),
                Triple("FLAC", "audio/flac", "flac"),
                Triple("AC-3", "audio/ac3", "ac-3"),
                Triple("E-AC-3", "audio/eac3", "ec-3")
            )

            val supportedCodecs = codecsToCheck
                .filter { (_, mimeType, _) -> isCodecSupportedByMimeType(mimeType) }
                .map { (name, _, _) -> name }

            verboseLog("Supported codecs: ${supportedCodecs.joinToString(", ")}", TAG)
            callback(Result.success(supportedCodecs))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CODEC_ERROR", e.message, null)))
        }
    }

    private fun checkCodecSupportInternal(codec: CodecInfoMessage): CodecCompatibilityMessage {
        val mimeType = buildMimeType(codec)
        if (mimeType == null) {
            return CodecCompatibilityMessage(
                codec = codec,
                supportLevel = CodecSupportLevelEnum.UNKNOWN,
                message = "Unable to determine MIME type for codec ${codec.fourcc}",
                minimumOsVersion = null,
                alternativeCodecs = null
            )
        }

        val isSupported = isCodecSupportedByMimeType(mimeType)

        val supportLevel: CodecSupportLevelEnum
        var message: String?
        var alternativeCodecs: List<String?>? = null

        if (isSupported) {
            supportLevel = CodecSupportLevelEnum.SUPPORTED
            message = "MediaCodecList.findDecoderForFormat found decoder"
        } else {
            supportLevel = CodecSupportLevelEnum.NOT_SUPPORTED
            message = "No decoder available for this codec"
            alternativeCodecs = suggestAlternatives(codec)
        }

        val minimumSdkVersion = getMinimumSdkVersion(codec)

        return CodecCompatibilityMessage(
            codec = CodecInfoMessage(
                fourcc = codec.fourcc,
                name = codec.name,
                codecString = codec.codecString,
                mimeType = mimeType
            ),
            supportLevel = supportLevel,
            message = message,
            minimumOsVersion = minimumSdkVersion,
            alternativeCodecs = alternativeCodecs
        )
    }

    private fun buildMimeType(codec: CodecInfoMessage): String? {
        // If codec already has mimeType, use it
        if (!codec.mimeType.isNullOrEmpty()) {
            // Extract just the MIME type from complex strings like "video/mp4; codecs=..."
            val mimeOnly = codec.mimeType!!.split(";").firstOrNull()?.trim()
            if (mimeOnly?.contains("/") == true) return mimeOnly
        }

        val fourcc = codec.fourcc.lowercase()

        // Video codecs
        return when (fourcc) {
            "avc1", "avc3" -> "video/avc"
            "hvc1", "hev1" -> "video/hevc"
            "vp08" -> "video/x-vnd.on2.vp8"
            "vp09" -> "video/x-vnd.on2.vp9"
            "av01" -> "video/av01"
            "mp4v" -> "video/mp4v-es"
            // Audio codecs
            "mp4a" -> "audio/mp4a-latm"
            "ac-3" -> "audio/ac3"
            "ec-3" -> "audio/eac3"
            "opus" -> "audio/opus"
            "flac" -> "audio/flac"
            "alac" -> "audio/alac"
            "vorb" -> "audio/vorbis"
            "mp3 ", ".mp3" -> "audio/mpeg"
            else -> null
        }
    }

    private fun isCodecSupportedByMimeType(mimeType: String): Boolean {
        return try {
            val format = android.media.MediaFormat.createVideoFormat(mimeType, 1920, 1080)
            val codecList = android.media.MediaCodecList(android.media.MediaCodecList.ALL_CODECS)
            val decoderName = codecList.findDecoderForFormat(format)
            !decoderName.isNullOrEmpty()
        } catch (e: Exception) {
            // For audio or if video format fails, try audio format
            try {
                val format = android.media.MediaFormat.createAudioFormat(mimeType, 48000, 2)
                val codecList = android.media.MediaCodecList(android.media.MediaCodecList.ALL_CODECS)
                val decoderName = codecList.findDecoderForFormat(format)
                !decoderName.isNullOrEmpty()
            } catch (e2: Exception) {
                false
            }
        }
    }

    private fun suggestAlternatives(codec: CodecInfoMessage): List<String?> {
        val fourcc = codec.fourcc.lowercase()

        // Video codec alternatives
        return when (fourcc) {
            "hvc1", "hev1" -> listOf("H.264", "VP9")
            "av01" -> listOf("H.264", "VP9", "HEVC")
            "vp09" -> listOf("H.264", "VP8")
            "vp08" -> listOf("H.264")
            // Audio codec alternatives
            "ac-3", "ec-3" -> listOf("AAC", "MP3")
            "alac" -> listOf("AAC", "FLAC")
            "opus" -> listOf("AAC", "Vorbis")
            else -> emptyList()
        }
    }

    private fun getMinimumSdkVersion(codec: CodecInfoMessage): String? {
        val fourcc = codec.fourcc.lowercase()

        return when (fourcc) {
            "av01" -> "29" // AV1 requires API 29+
            "hvc1", "hev1" -> "21" // HEVC requires API 21+
            "vp09" -> "21" // VP9 requires API 21+
            else -> null
        }
    }

    override fun setLooping(playerId: Long, looping: Boolean, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.setLooping(looping) }, callback)
    }

    override fun setScalingMode(playerId: Long, mode: VideoScalingModeEnum, callback: (Result<Unit>) -> Unit) {
        val modeString = when (mode) {
            VideoScalingModeEnum.FIT -> "fit"
            VideoScalingModeEnum.FILL -> "fill"
            VideoScalingModeEnum.STRETCH -> "stretch"
        }
        delegatePlayerMethod(playerId, { it.setScalingMode(modeString) }, callback)
    }

    override fun setControlsMode(playerId: Long, mode: ControlsModeEnum, callback: (Result<Unit>) -> Unit) {
        val useNativeControls = mode == ControlsModeEnum.NATIVE_CONTROLS
        delegatePlayerMethod(playerId, { it.setControlsMode(useNativeControls) }, callback)
    }

    // MARK: - Device Controls

    override fun getDeviceVolume(callback: (Result<Double>) -> Unit) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val normalizedVolume = if (maxVolume > 0) currentVolume.toDouble() / maxVolume else 1.0
            callback(Result.success(normalizedVolume))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("VOLUME_ERROR", e.message, null)))
        }
    }

    override fun setDeviceVolume(volume: Double, callback: (Result<Unit>) -> Unit) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetVolume = (volume * maxVolume).toInt()
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("VOLUME_ERROR", e.message, null)))
        }
    }

    override fun getScreenBrightness(callback: (Result<Double>) -> Unit) {
        try {
            val activity = getActivity()
            if (activity == null) {
                callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
                return
            }

            val layoutParams = activity.window.attributes
            val brightness = if (layoutParams.screenBrightness < 0) {
                val systemBrightness = android.provider.Settings.System.getInt(
                    context.contentResolver,
                    android.provider.Settings.System.SCREEN_BRIGHTNESS,
                    255
                )
                systemBrightness / 255.0
            } else {
                layoutParams.screenBrightness.toDouble()
            }
            callback(Result.success(brightness))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("BRIGHTNESS_ERROR", e.message, null)))
        }
    }

    override fun setScreenBrightness(brightness: Double, callback: (Result<Unit>) -> Unit) {
        try {
            val activity = getActivity()
            if (activity == null) {
                callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
                return
            }

            val layoutParams = activity.window.attributes
            layoutParams.screenBrightness = brightness.toFloat()
            activity.window.attributes = layoutParams
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("BRIGHTNESS_ERROR", e.message, null)))
        }
    }

    override fun getBatteryInfo(callback: (Result<BatteryInfoMessage?>) -> Unit) {
        try {
            val activity = getActivity()
            if (activity == null) {
                callback(Result.success(null))
                return
            }

            val batteryManager = activity.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (batteryManager == null) {
                callback(Result.success(null))
                return
            }

            val percentage = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            if (percentage < 0 || percentage > 100) {
                callback(Result.success(null))
                return
            }

            val batteryStatus = activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                           status == BatteryManager.BATTERY_STATUS_FULL

            val message = BatteryInfoMessage(
                percentage = percentage.toLong(),
                isCharging = isCharging
            )
            callback(Result.success(message))
        } catch (e: Exception) {
            callback(Result.success(null))
        }
    }

    // MARK: - Subtitle Methods

    override fun setSubtitleTrack(playerId: Long, track: SubtitleTrackMessage?, callback: (Result<Unit>) -> Unit) {
        val trackMap = track?.let { convertSubtitleTrackToMap(it) }
        delegatePlayerMethod(playerId, { it.setSubtitleTrack(trackMap) }, callback)
    }

    override fun setSubtitleRenderMode(playerId: Long, mode: SubtitleRenderModeEnum, callback: (Result<Unit>) -> Unit) {
        val modeString = when (mode) {
            SubtitleRenderModeEnum.AUTO -> "auto"
            SubtitleRenderModeEnum.NATIVE -> "native"
            SubtitleRenderModeEnum.FLUTTER -> "flutter"
        }
        delegatePlayerMethod(playerId, { it.setSubtitleRenderMode(modeString) }, callback)
    }

    override fun addExternalSubtitle(
        playerId: Long,
        source: SubtitleSourceMessage,
        callback: (Result<ExternalSubtitleTrackMessage?>) -> Unit
    ) {
        try {
            val player = getPlayerOrFail(playerId)

            val sourceType = when (source.type) {
                VideoSourceType.NETWORK -> "network"
                VideoSourceType.FILE -> "file"
                VideoSourceType.ASSET -> "asset"
            }

            player.addExternalSubtitle(
                sourceType,
                source.path,
                source.format?.let { convertSubtitleFormatToString(it) },
                source.label,
                source.language,
                source.isDefault,
                source.webvttContent
            ) { trackMap ->
                val message = trackMap?.let { convertMapToExternalSubtitleTrack(it) }
                callback(Result.success(message))
            }
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("SUBTITLE_ERROR", e.message, null)))
        }
    }

    override fun removeExternalSubtitle(playerId: Long, trackId: String, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val success = player.removeExternalSubtitle(trackId)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("SUBTITLE_ERROR", e.message, null)))
        }
    }

    override fun getExternalSubtitles(playerId: Long, callback: (Result<List<ExternalSubtitleTrackMessage?>>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val tracks = player.getExternalSubtitles()
            val messages = tracks.map { convertMapToExternalSubtitleTrack(it) }
            callback(Result.success(messages))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("SUBTITLE_ERROR", e.message, null)))
        }
    }

    // MARK: - Audio Track Methods

    override fun setAudioTrack(playerId: Long, track: AudioTrackMessage?, callback: (Result<Unit>) -> Unit) {
        val trackMap = track?.let { convertAudioTrackToMap(it) }
        delegatePlayerMethod(playerId, { it.setAudioTrack(trackMap) }, callback)
    }

    // MARK: - PiP Methods

    override fun enterPip(playerId: Long, options: PipOptionsMessage, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val activity = getActivity()
            if (activity == null) {
                callback(Result.success(false))
                return
            }
            val success = player.enterPip(activity)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("PIP_ERROR", e.message, null)))
        }
    }

    override fun exitPip(playerId: Long, callback: (Result<Unit>) -> Unit) {
        delegatePlayerMethod(playerId, { it.exitPip() }, callback)
    }

    override fun isPipSupported(callback: (Result<Boolean>) -> Unit) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                callback(Result.success(false))
                return
            }

            val hasSystemFeature = context.packageManager.hasSystemFeature(
                android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE
            )
            callback(Result.success(hasSystemFeature))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("PIP_ERROR", e.message, null)))
        }
    }

    override fun setPipActions(playerId: Long, actions: List<PipActionMessage?>, callback: (Result<Unit>) -> Unit) {
        val actionsList = actions.mapNotNull { it?.let { convertPipActionToMap(it) } }
        delegatePlayerMethod(playerId, { it.setPipActions(actionsList) }, callback)
    }

    // MARK: - Fullscreen Methods

    override fun enterFullscreen(playerId: Long, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val activity = getActivity()
            if (activity == null) {
                callback(Result.success(false))
                return
            }
            val success = player.enterFullscreen(activity)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("FULLSCREEN_ERROR", e.message, null)))
        }
    }

    override fun exitFullscreen(playerId: Long, callback: (Result<Unit>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val activity = getActivity()
            if (activity == null) {
                callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
                return
            }
            player.exitFullscreen(activity)
            callback(Result.success(Unit))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("FULLSCREEN_ERROR", e.message, null)))
        }
    }

    override fun setWindowFullscreen(fullscreen: Boolean, callback: (Result<Unit>) -> Unit) {
        // Not applicable on Android (desktop-only feature)
        callback(Result.success(Unit))
    }

    // MARK: - Background Playback Methods

    override fun setBackgroundPlayback(playerId: Long, enabled: Boolean, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val success = player.setBackgroundPlayback(enabled)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("BACKGROUND_ERROR", e.message, null)))
        }
    }

    override fun isBackgroundPlaybackSupported(callback: (Result<Boolean>) -> Unit) {
        try {
            val serviceIntent = Intent(context, MediaPlaybackService::class.java)
            val resolveInfo = context.packageManager.resolveService(serviceIntent, 0)
            callback(Result.success(resolveInfo != null))
        } catch (e: Exception) {
            callback(Result.success(false))
        }
    }

    // MARK: - Quality/Track Methods

    override fun getVideoQualities(playerId: Long, callback: (Result<List<VideoQualityTrackMessage?>>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val qualities = player.getVideoQualities()
            val messages = qualities.map { convertMapToVideoQualityTrack(it) }
            callback(Result.success(messages))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("QUALITY_ERROR", e.message, null)))
        }
    }

    override fun setVideoQuality(playerId: Long, track: VideoQualityTrackMessage, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val trackMap = convertVideoQualityTrackToMap(track)
            val success = player.setVideoQuality(trackMap)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("QUALITY_ERROR", e.message, null)))
        }
    }

    override fun getCurrentVideoQuality(playerId: Long, callback: (Result<VideoQualityTrackMessage>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val qualityMap = player.getCurrentVideoQuality()
            val message = convertMapToVideoQualityTrack(qualityMap)
            callback(Result.success(message))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("QUALITY_ERROR", e.message, null)))
        }
    }

    override fun isQualitySelectionSupported(playerId: Long, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val supported = player.isQualitySelectionSupported()
            callback(Result.success(supported))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("QUALITY_ERROR", e.message, null)))
        }
    }

    // MARK: - Metadata Methods

    override fun getVideoMetadata(playerId: Long, callback: (Result<VideoMetadataMessage?>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val metadataMap = player.getVideoMetadata()
            val message = metadataMap?.let { convertMapToVideoMetadata(it) }
            callback(Result.success(message))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("METADATA_ERROR", e.message, null)))
        }
    }

    override fun setMediaMetadata(playerId: Long, metadata: MediaMetadataMessage, callback: (Result<Unit>) -> Unit) {
        val metadataMap = convertMediaMetadataToMap(metadata)
        delegatePlayerMethod(playerId, { it.setMediaMetadata(metadataMap) }, callback)
    }

    override fun extractEmbeddedArtwork(source: VideoSourceMessage, callback: (Result<ByteArray?>) -> Unit) {
        verboseLog("extractEmbeddedArtwork() called for source type: ${source.type}", TAG)
        try {
            val retriever = MediaMetadataRetriever()
            try {
                when (source.type) {
                    VideoSourceType.FILE -> {
                        val path = source.path
                        if (path == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "File path is null", null)))
                            return
                        }
                        retriever.setDataSource(path)
                    }
                    VideoSourceType.NETWORK -> {
                        val url = source.url
                        if (url == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "URL is null", null)))
                            return
                        }
                        // Convert headers map to HashMap<String, String> for MediaMetadataRetriever
                        val headers = source.headers?.mapNotNull { (k, v) ->
                            if (k != null && v != null) k to v else null
                        }?.toMap() ?: emptyMap()
                        retriever.setDataSource(url, headers)
                    }
                    VideoSourceType.ASSET -> {
                        val assetPath = source.assetPath
                        if (assetPath == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "Asset path is null", null)))
                            return
                        }
                        // Resolve Flutter asset path
                        val flutterLoader = FlutterInjector.instance().flutterLoader()
                        val resolvedPath = flutterLoader.getLookupKeyForAsset(assetPath)
                        val assetFd = context.assets.openFd(resolvedPath)
                        retriever.setDataSource(assetFd.fileDescriptor, assetFd.startOffset, assetFd.length)
                        assetFd.close()
                    }
                }

                // Get the embedded picture (album art / cover)
                val artwork = retriever.embeddedPicture
                verboseLog("extractEmbeddedArtwork() result: ${if (artwork != null) "${artwork.size} bytes" else "null"}", TAG)
                callback(Result.success(artwork))
            } finally {
                retriever.release()
            }
        } catch (e: Exception) {
            verboseLog("extractEmbeddedArtwork() failed: ${e.message}", TAG)
            // Return null instead of error for unsupported sources (e.g., some network URLs)
            callback(Result.success(null))
        }
    }

    override fun extractVideoFrame(
        source: VideoSourceMessage,
        positionMs: Long,
        maxWidth: Long?,
        maxHeight: Long?,
        quality: Long?,
        callback: (Result<ByteArray?>) -> Unit
    ) {
        verboseLog("extractVideoFrame() called for position: ${positionMs}ms", TAG)
        try {
            val retriever = MediaMetadataRetriever()
            try {
                when (source.type) {
                    VideoSourceType.FILE -> {
                        val path = source.path
                        if (path == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "File path is null", null)))
                            return
                        }
                        retriever.setDataSource(path)
                    }
                    VideoSourceType.NETWORK -> {
                        val url = source.url
                        if (url == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "URL is null", null)))
                            return
                        }
                        val headers = source.headers?.mapNotNull { (k, v) ->
                            if (k != null && v != null) k to v else null
                        }?.toMap() ?: emptyMap()
                        retriever.setDataSource(url, headers)
                    }
                    VideoSourceType.ASSET -> {
                        val assetPath = source.assetPath
                        if (assetPath == null) {
                            callback(Result.failure(FlutterError("INVALID_SOURCE", "Asset path is null", null)))
                            return
                        }
                        val flutterLoader = FlutterInjector.instance().flutterLoader()
                        val resolvedPath = flutterLoader.getLookupKeyForAsset(assetPath)
                        val assetFd = context.assets.openFd(resolvedPath)
                        retriever.setDataSource(assetFd.fileDescriptor, assetFd.startOffset, assetFd.length)
                        assetFd.close()
                    }
                }

                // Extract frame at the specified position (convert ms to us)
                val timeUs = positionMs * 1000
                var bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    retriever.getScaledFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                        maxWidth?.toInt() ?: 512,
                        maxHeight?.toInt() ?: 384
                    )
                } else {
                    retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                }

                if (bitmap == null) {
                    verboseLog("extractVideoFrame() no frame found at position", TAG)
                    callback(Result.success(null))
                    return
                }

                // Scale if needed (for older APIs that don't support getScaledFrameAtTime)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1 && (maxWidth != null || maxHeight != null)) {
                    val targetWidth = maxWidth?.toInt() ?: bitmap.width
                    val targetHeight = maxHeight?.toInt() ?: bitmap.height
                    val scaledBitmap = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
                    if (scaledBitmap != bitmap) {
                        bitmap.recycle()
                        bitmap = scaledBitmap
                    }
                }

                // Convert to JPEG bytes
                val outputStream = java.io.ByteArrayOutputStream()
                val jpegQuality = (quality?.toInt() ?: 80).coerceIn(0, 100)
                bitmap.compress(Bitmap.CompressFormat.JPEG, jpegQuality, outputStream)
                bitmap.recycle()

                val bytes = outputStream.toByteArray()
                verboseLog("extractVideoFrame() result: ${bytes.size} bytes", TAG)
                callback(Result.success(bytes))
            } finally {
                retriever.release()
            }
        } catch (e: Exception) {
            verboseLog("extractVideoFrame() failed: ${e.message}", TAG)
            callback(Result.success(null))
        }
    }

    override fun extractContentFingerprint(
        source: VideoSourceMessage,
        callback: (Result<ContentFingerprintMessage>) -> Unit
    ) {
        verboseLog("extractContentFingerprint() called for source type: ${source.type}", TAG)
        try {
            val sampleSize = 8 * 1024 // 8KB per sample
            val samples = ByteArray(sampleSize * 3) // 3 samples
            var fileSize: Long? = null

            when (source.type) {
                VideoSourceType.FILE -> {
                    val path = source.path
                    if (path == null) {
                        callback(Result.success(ContentFingerprintMessage(error = "File path is null")))
                        return
                    }
                    val file = java.io.File(path)
                    if (!file.exists()) {
                        callback(Result.success(ContentFingerprintMessage(error = "File not found")))
                        return
                    }
                    fileSize = file.length()
                    java.io.RandomAccessFile(file, "r").use { raf ->
                        readSamplesFromFile(raf, fileSize, sampleSize, samples)
                    }
                }
                VideoSourceType.NETWORK -> {
                    val url = source.url
                    if (url == null) {
                        callback(Result.success(ContentFingerprintMessage(error = "URL is null")))
                        return
                    }
                    val headers = source.headers?.mapNotNull { (k, v) ->
                        if (k != null && v != null) k to v else null
                    }?.toMap() ?: emptyMap()
                    val result = readSamplesFromNetwork(url, headers, sampleSize, samples)
                    if (result.error != null) {
                        callback(Result.success(ContentFingerprintMessage(error = result.error)))
                        return
                    }
                    fileSize = result.fileSize
                }
                VideoSourceType.ASSET -> {
                    val assetPath = source.assetPath
                    if (assetPath == null) {
                        callback(Result.success(ContentFingerprintMessage(error = "Asset path is null")))
                        return
                    }
                    val flutterLoader = FlutterInjector.instance().flutterLoader()
                    val resolvedPath = flutterLoader.getLookupKeyForAsset(assetPath)
                    context.assets.openFd(resolvedPath).use { assetFd ->
                        fileSize = assetFd.length
                        java.io.RandomAccessFile(assetFd.fileDescriptor.toString(), "r").use { raf ->
                            // For assets, we use the input stream approach
                            readSamplesFromAsset(assetFd, sampleSize, samples)
                        }
                    }
                }
            }

            // Compute SHA-256 hash
            val digest = java.security.MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(samples)
            val fingerprint = hashBytes.joinToString("") { "%02x".format(it) }

            verboseLog("extractContentFingerprint() result: fingerprint=$fingerprint, fileSize=$fileSize", TAG)
            callback(Result.success(ContentFingerprintMessage(fingerprint = fingerprint, fileSize = fileSize)))
        } catch (e: Exception) {
            verboseLog("extractContentFingerprint() failed: ${e.message}", TAG)
            callback(Result.success(ContentFingerprintMessage(error = e.message ?: "Unknown error")))
        }
    }

    private data class NetworkSampleResult(val fileSize: Long?, val error: String?)

    private fun readSamplesFromFile(raf: java.io.RandomAccessFile, fileSize: Long, sampleSize: Int, samples: ByteArray) {
        // Read from start
        raf.seek(0)
        raf.read(samples, 0, minOf(sampleSize, fileSize.toInt()))

        // Read from middle
        if (fileSize > sampleSize) {
            val middlePos = (fileSize / 2) - (sampleSize / 2)
            raf.seek(maxOf(0L, middlePos))
            raf.read(samples, sampleSize, minOf(sampleSize, (fileSize - middlePos).toInt()))
        }

        // Read from end
        if (fileSize > sampleSize * 2) {
            val endPos = fileSize - sampleSize
            raf.seek(maxOf(0L, endPos))
            raf.read(samples, sampleSize * 2, minOf(sampleSize, (fileSize - endPos).toInt()))
        }
    }

    private fun readSamplesFromAsset(assetFd: android.content.res.AssetFileDescriptor, sampleSize: Int, samples: ByteArray) {
        val fileSize = assetFd.length
        val stream = assetFd.createInputStream()
        stream.use { input ->
            // Read from start
            input.read(samples, 0, minOf(sampleSize, fileSize.toInt()))

            // For middle and end, we need to skip and read
            if (fileSize > sampleSize) {
                val middlePos = (fileSize / 2) - (sampleSize / 2)
                input.skip(middlePos - sampleSize)
                input.read(samples, sampleSize, minOf(sampleSize, (fileSize - middlePos).toInt()))
            }

            if (fileSize > sampleSize * 2) {
                val endPos = fileSize - sampleSize
                val skipAmount = endPos - (fileSize / 2) - (sampleSize / 2)
                input.skip(maxOf(0L, skipAmount - sampleSize))
                input.read(samples, sampleSize * 2, minOf(sampleSize, sampleSize))
            }
        }
    }

    private fun readSamplesFromNetwork(url: String, headers: Map<String, String>, sampleSize: Int, samples: ByteArray): NetworkSampleResult {
        try {
            // First, get the file size with a HEAD request
            val headConnection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            headConnection.requestMethod = "HEAD"
            headers.forEach { (k, v) -> headConnection.setRequestProperty(k, v) }
            headConnection.connect()

            val fileSize = headConnection.contentLengthLong
            headConnection.disconnect()

            if (fileSize <= 0) {
                return NetworkSampleResult(null, "Cannot determine file size from network source")
            }

            // Read start sample
            readNetworkRange(url, headers, 0, sampleSize, samples, 0)

            // Read middle sample
            if (fileSize > sampleSize) {
                val middlePos = (fileSize / 2) - (sampleSize / 2)
                readNetworkRange(url, headers, middlePos, sampleSize, samples, sampleSize)
            }

            // Read end sample
            if (fileSize > sampleSize * 2) {
                val endPos = fileSize - sampleSize
                readNetworkRange(url, headers, endPos, sampleSize, samples, sampleSize * 2)
            }

            return NetworkSampleResult(fileSize, null)
        } catch (e: Exception) {
            return NetworkSampleResult(null, e.message ?: "Network error")
        }
    }

    private fun readNetworkRange(url: String, headers: Map<String, String>, start: Long, length: Int, buffer: ByteArray, offset: Int) {
        val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        connection.requestMethod = "GET"
        headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }
        connection.setRequestProperty("Range", "bytes=$start-${start + length - 1}")
        connection.connect()

        if (connection.responseCode == java.net.HttpURLConnection.HTTP_PARTIAL || connection.responseCode == java.net.HttpURLConnection.HTTP_OK) {
            connection.inputStream.use { input ->
                var totalRead = 0
                while (totalRead < length) {
                    val read = input.read(buffer, offset + totalRead, length - totalRead)
                    if (read == -1) break
                    totalRead += read
                }
            }
        }
        connection.disconnect()
    }

    // MARK: - Casting Methods

    override fun isCastingSupported(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(true))
    }

    override fun getAvailableCastDevices(playerId: Long, callback: (Result<List<CastDeviceMessage?>>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val devices = player.getAvailableCastDevices()
            val messages = devices.map { convertMapToCastDevice(it) }
            callback(Result.success(messages))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CAST_ERROR", e.message, null)))
        }
    }

    override fun startCasting(playerId: Long, device: CastDeviceMessage?, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val deviceMap = device?.let { convertCastDeviceToMap(it) } ?: emptyMap()
            val success = player.startCasting(deviceMap)
            callback(Result.success(success))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CAST_ERROR", e.message, null)))
        }
    }

    override fun stopCasting(playerId: Long, callback: (Result<Boolean>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            player.stopCasting()
            callback(Result.success(true))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CAST_ERROR", e.message, null)))
        }
    }

    override fun getCastState(playerId: Long, callback: (Result<CastStateEnum>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val stateString = player.getCastState()
            val state = when (stateString) {
                "notConnected" -> CastStateEnum.NOT_CONNECTED
                "connecting" -> CastStateEnum.CONNECTING
                "connected" -> CastStateEnum.CONNECTED
                "disconnecting" -> CastStateEnum.DISCONNECTING
                else -> CastStateEnum.NOT_CONNECTED
            }
            callback(Result.success(state))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CAST_ERROR", e.message, null)))
        }
    }

    override fun getCurrentCastDevice(playerId: Long, callback: (Result<CastDeviceMessage?>) -> Unit) {
        try {
            val player = getPlayerOrFail(playerId)
            val deviceMap = player.getCurrentCastDevice()
            val message = deviceMap?.let { convertMapToCastDevice(it) }
            callback(Result.success(message))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("CAST_ERROR", e.message, null)))
        }
    }

    // MARK: - Helper Methods

    private fun getPlayerOrFail(playerId: Long): VideoPlayer {
        val player = getPlayer(playerId.toInt())
        if (player == null) {
            throw FlutterError("INVALID_PLAYER", "Player not found: $playerId", null)
        }
        return player
    }

    private fun delegatePlayerMethod(
        playerId: Long,
        action: (VideoPlayer) -> Unit,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            val player = getPlayerOrFail(playerId)
            action(player)
            callback(Result.success(Unit))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("OPERATION_ERROR", e.message, null)))
        }
    }

    // MARK: - Conversion Methods (Pigeon Messages ↔ Maps)

    private fun convertVideoSourceToMap(source: VideoSourceMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "type" to when (source.type) {
                VideoSourceType.NETWORK -> "network"
                VideoSourceType.FILE -> "file"
                VideoSourceType.ASSET -> "asset"
            }
        )

        source.url?.let { map["url"] = it }
        source.path?.let { map["path"] = it }
        source.assetPath?.let { map["assetPath"] = it }
        source.headers?.let { map["headers"] = it }

        return map
    }

    private fun convertPlayerOptionsToMap(options: VideoPlayerOptionsMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>()

        options.autoPlay?.let { map["autoPlay"] = it }
        options.looping?.let { map["looping"] = it }
        options.volume?.let { map["volume"] = it }
        options.playbackSpeed?.let { map["playbackSpeed"] = it }
        options.startPosition?.let { map["startPosition"] = it.toInt() }
        options.enablePip?.let { map["enablePip"] = it }
        options.enableBackgroundPlayback?.let { map["enableBackgroundPlayback"] = it }
        options.preferredAudioLanguage?.let { map["preferredAudioLanguage"] = it }
        options.preferredSubtitleLanguage?.let { map["preferredSubtitleLanguage"] = it }
        options.maxBitrate?.let { map["maxBitrate"] = it.toInt() }
        options.minBitrate?.let { map["minBitrate"] = it.toInt() }
        options.preferredAudioRendition?.let { map["preferredAudioRendition"] = it }
        // Subtitle options
        options.subtitleRenderMode?.let { map["subtitleRenderMode"] = convertSubtitleRenderModeToString(it) }
        options.subtitlesEnabled?.let { map["subtitlesEnabled"] = it }
        options.showSubtitlesByDefault?.let { map["showSubtitlesByDefault"] = it }

        return map
    }

    private fun convertSubtitleRenderModeToString(mode: SubtitleRenderModeEnum): String {
        return when (mode) {
            SubtitleRenderModeEnum.AUTO -> "auto"
            SubtitleRenderModeEnum.NATIVE -> "native"
            SubtitleRenderModeEnum.FLUTTER -> "flutter"
        }
    }

    private fun convertSubtitleTrackToMap(track: SubtitleTrackMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>("id" to track.id)
        track.label?.let { map["label"] = it }
        track.language?.let { map["language"] = it }
        track.format?.let { map["format"] = convertSubtitleFormatToString(it) }
        track.isDefault?.let { map["isDefault"] = it }
        return map
    }

    private fun convertSubtitleFormatToString(format: SubtitleFormatEnum): String {
        return when (format) {
            SubtitleFormatEnum.SRT -> "srt"
            SubtitleFormatEnum.VTT -> "vtt"
            SubtitleFormatEnum.SSA -> "ssa"
            SubtitleFormatEnum.ASS -> "ass"
            SubtitleFormatEnum.TTML -> "ttml"
        }
    }

    private fun convertMapToExternalSubtitleTrack(map: Map<String, Any?>): ExternalSubtitleTrackMessage {
        return ExternalSubtitleTrackMessage(
            id = map["id"] as String,
            label = (map["label"] as? String) ?: "",
            language = map["language"] as? String,
            isDefault = map["isDefault"] as? Boolean ?: false,
            path = (map["path"] as? String) ?: "",
            sourceType = (map["sourceType"] as? String) ?: "file",
            format = (map["format"] as? String)?.let { convertStringToSubtitleFormat(it) } ?: SubtitleFormatEnum.SRT
        )
    }

    private fun convertStringToSubtitleFormat(format: String): SubtitleFormatEnum {
        return when (format.lowercase()) {
            "srt" -> SubtitleFormatEnum.SRT
            "vtt", "webvtt" -> SubtitleFormatEnum.VTT
            "ssa" -> SubtitleFormatEnum.SSA
            "ass" -> SubtitleFormatEnum.ASS
            "ttml" -> SubtitleFormatEnum.TTML
            else -> SubtitleFormatEnum.VTT
        }
    }

    private fun convertAudioTrackToMap(track: AudioTrackMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>("id" to track.id)
        track.label?.let { map["label"] = it }
        track.language?.let { map["language"] = it }
        track.channelCount?.let { map["channelCount"] = it.toInt() }
        track.isDefault?.let { map["isDefault"] = it }
        return map
    }

    private fun convertPipActionToMap(action: PipActionMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "type" to when (action.type) {
                PipActionTypeEnum.PLAY_PAUSE -> "playPause"
                PipActionTypeEnum.SKIP_PREVIOUS -> "skipPrevious"
                PipActionTypeEnum.SKIP_NEXT -> "skipNext"
                PipActionTypeEnum.SKIP_BACKWARD -> "skipBackward"
                PipActionTypeEnum.SKIP_FORWARD -> "skipForward"
            }
        )
        action.title?.let { map["title"] = it }
        action.iconName?.let { map["iconName"] = it }
        return map
    }

    private fun convertMapToVideoQualityTrack(map: Map<String, Any?>): VideoQualityTrackMessage {
        return VideoQualityTrackMessage(
            id = map["id"] as String,
            label = map["label"] as? String,
            bitrate = (map["bitrate"] as? Number)?.toLong(),
            width = (map["width"] as? Number)?.toLong(),
            height = (map["height"] as? Number)?.toLong(),
            codec = map["codec"] as? String,
            isDefault = map["isDefault"] as? Boolean ?: false
        )
    }

    private fun convertVideoQualityTrackToMap(track: VideoQualityTrackMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>("id" to track.id)
        track.label?.let { map["label"] = it }
        track.bitrate?.let { map["bitrate"] = it.toInt() }
        track.width?.let { map["width"] = it.toInt() }
        track.height?.let { map["height"] = it.toInt() }
        track.codec?.let { map["codec"] = it }
        track.isDefault?.let { map["isDefault"] = it }
        return map
    }

    private fun convertMapToVideoMetadata(map: Map<String, Any?>): VideoMetadataMessage {
        return VideoMetadataMessage(
            duration = (map["duration"] as? Number)?.toLong(),
            width = (map["width"] as? Number)?.toLong(),
            height = (map["height"] as? Number)?.toLong(),
            videoCodec = map["videoCodec"] as? String,
            audioCodec = map["audioCodec"] as? String,
            bitrate = (map["bitrate"] as? Number)?.toLong(),
            frameRate = (map["frameRate"] as? Number)?.toDouble()
        )
    }

    private fun convertMediaMetadataToMap(metadata: MediaMetadataMessage): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        metadata.title?.let { map["title"] = it }
        metadata.artist?.let { map["artist"] = it }
        metadata.album?.let { map["album"] = it }
        metadata.artworkUrl?.let { map["artworkUrl"] = it }
        metadata.duration?.let { map["duration"] = it.toInt() }
        return map
    }

    private fun convertMapToCastDevice(map: Map<String, Any>): CastDeviceMessage {
        val typeString = map["type"] as? String ?: "unknown"
        val type = when (typeString.lowercase()) {
            "airplay" -> CastDeviceTypeEnum.AIR_PLAY
            "chromecast" -> CastDeviceTypeEnum.CHROMECAST
            "webremoteplayback" -> CastDeviceTypeEnum.WEB_REMOTE_PLAYBACK
            else -> CastDeviceTypeEnum.UNKNOWN
        }

        return CastDeviceMessage(
            id = map["id"] as String,
            name = map["name"] as String,
            type = type
        )
    }

    private fun convertCastDeviceToMap(device: CastDeviceMessage): Map<String, Any> {
        return mapOf(
            "id" to device.id,
            "name" to device.name,
            "type" to when (device.type) {
                CastDeviceTypeEnum.AIR_PLAY -> "airPlay"
                CastDeviceTypeEnum.CHROMECAST -> "chromecast"
                CastDeviceTypeEnum.WEB_REMOTE_PLAYBACK -> "webRemotePlayback"
                CastDeviceTypeEnum.UNKNOWN -> "unknown"
            }
        )
    }
}
