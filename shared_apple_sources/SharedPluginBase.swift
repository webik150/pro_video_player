import AVFoundation
import AVKit
import CommonCrypto
import Foundation

#if os(iOS)
    import Flutter
    import MediaPlayer
    import UIKit
#elseif os(macOS)
    import FlutterMacOS
    import IOKit.ps
#endif

/// Configuration for platform-specific plugin behavior
public struct PlatformConfig {
    let channelName: String
    let viewTypeId: String
    let supportsPipActions: Bool

    public init(
        channelName: String,
        viewTypeId: String,
        supportsPipActions: Bool
    ) {
        self.channelName = channelName
        self.viewTypeId = viewTypeId
        self.supportsPipActions = supportsPipActions
    }

    public static let ios = PlatformConfig(
        channelName: "dev.pro_video_player.ios/methods",
        viewTypeId: "dev.pro_video_player.ios/video_view",
        supportsPipActions: true
    )

    public static let macOS = PlatformConfig(
        channelName: "dev.pro_video_player.macos/methods",
        viewTypeId: "dev.pro_video_player.macos/video_view",
        supportsPipActions: false
    )
}

/// Protocol for platform-specific differences in plugin behavior
public protocol PlatformPluginBehavior {
    /// Returns whether PiP is supported on this platform
    func isPipSupported() -> Bool

    /// Returns whether background playback is supported on this platform
    func isBackgroundPlaybackSupported() -> Bool

    /// Handles platform-specific PiP actions (iOS only)
    func handleSetPipActions(
        call: FlutterMethodCall, player: SharedVideoPlayerWrapper, result: @escaping FlutterResult)

    /// Creates a platform-specific video player instance
    func createVideoPlayer(playerId: Int, source: [String: Any], options: [String: Any])
        -> SharedVideoPlayerWrapper
}

/// Shared base implementation for iOS and macOS video player plugins.
///
/// This class implements the Pigeon-generated ProVideoPlayerHostApi protocol,
/// providing type-safe platform communication without the bridge layer.
open class SharedPluginBase: NSObject, ProVideoPlayerHostApi {
    private var players: [Int: SharedVideoPlayerWrapper] = [:]
    private var nextPlayerId: Int = 0
    private let registrar: Any
    private let platformBehavior: PlatformPluginBehavior
    private let config: PlatformConfig
    private let flutterApi: ProVideoPlayerFlutterApi

    #if os(iOS)
        /// Cached MPVolumeView for setting system volume without showing system HUD.
        /// The view must be added to the view hierarchy to work correctly.
        private lazy var volumeView: MPVolumeView = {
            let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            view.alpha = 0.01  // Nearly invisible but still functional
            return view
        }()
    #endif

    public init(registrar: Any, platformBehavior: PlatformPluginBehavior, config: PlatformConfig) {
        self.registrar = registrar
        self.platformBehavior = platformBehavior
        self.config = config

        // Initialize FlutterApi for native → Dart callbacks
        #if os(iOS)
            let messenger = (registrar as! FlutterPluginRegistrar).messenger()
            self.flutterApi = ProVideoPlayerFlutterApi(binaryMessenger: messenger)
        #elseif os(macOS)
            let messenger = (registrar as! FlutterPluginRegistrar).messenger
            self.flutterApi = ProVideoPlayerFlutterApi(binaryMessenger: messenger)
        #endif

        super.init()

        // Set up battery monitoring
        setupBatteryMonitoring()
    }

    public func getPlayer(for playerId: Int) -> SharedVideoPlayerWrapper? {
        return players[playerId]
    }

    // MARK: - ProVideoPlayerHostApi Implementation

    /// Creates a platform-specific video player by delegating to platformBehavior
    private func createVideoPlayer(playerId: Int, source: [String: Any], options: [String: Any])
        -> SharedVideoPlayerWrapper
    {
        let player = platformBehavior.createVideoPlayer(
            playerId: playerId, source: source, options: options)
        // Wire up FlutterApi for native → Dart callbacks
        player.sharedPlayer.flutterApi = flutterApi
        return player
    }

    func create(
        source: VideoSourceMessage,
        options: VideoPlayerOptionsMessage,
        completion: @escaping (Result<Int64, Error>) -> Void
    ) {

        let playerId = nextPlayerId
        nextPlayerId += 1

        // Convert Pigeon messages to dictionary format expected by createVideoPlayer
        let sourceData = convertVideoSourceToDict(source)
        let optionsData = convertPlayerOptionsToDict(options)

        let player = createVideoPlayer(playerId: playerId, source: sourceData, options: optionsData)

        players[playerId] = player
        completion(.success(Int64(playerId)))
    }

    func dispose(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        let playerIdInt = Int(playerId)
        players[playerIdInt]?.dispose()
        players.removeValue(forKey: playerIdInt)
        completion(.success(()))
    }

    func play(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.play()
        completion(.success(()))
    }

    func pause(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.pause()
        completion(.success(()))
    }

    func stop(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.stop()
        completion(.success(()))
    }

    func seekTo(playerId: Int64, positionMs: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard positionMs >= 0 else {
            completion(.failure(PigeonError(code: "INVALID_ARGS", message: "Position must be non-negative", details: nil)))
            return
        }

        player.seekTo(milliseconds: Int(positionMs))
        completion(.success(()))
    }

    func setPlaybackSpeed(playerId: Int64, speed: Double, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard speed > 0.0 && speed <= 10.0 else {
            completion(.failure(PigeonError(code: "INVALID_ARGS", message: "Playback speed must be between 0.0 (exclusive) and 10.0", details: nil)))
            return
        }

        player.setPlaybackSpeed(Float(speed))
        completion(.success(()))
    }

    func setVolume(playerId: Int64, volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard volume >= 0.0 && volume <= 1.0 else {
            completion(.failure(PigeonError(code: "INVALID_ARGS", message: "Volume must be between 0.0 and 1.0", details: nil)))
            return
        }

        player.setVolume(Float(volume))
        completion(.success(()))
    }

    func getDeviceVolume(completion: @escaping (Result<Double, Error>) -> Void) {

        #if os(iOS)
            let volume = AVAudioSession.sharedInstance().outputVolume
            completion(.success(Double(volume)))
        #elseif os(macOS)
            // macOS doesn't have a simple API to get system volume
            // Return 1.0 as a fallback (full volume)
            completion(.success(1.0))
        #endif
    }

    func setDeviceVolume(volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {

        guard volume >= 0.0 && volume <= 1.0 else {
            completion(.failure(PigeonError(code: "INVALID_ARGS", message: "Volume must be between 0.0 and 1.0", details: nil)))
            return
        }

        #if os(iOS)
            // iOS: Use MPVolumeView to set system volume without showing system HUD
            // The volumeView must be in the view hierarchy for this to work
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    completion(.success(()))
                    return
                }

                // Ensure the volume view is in the view hierarchy
                if self.volumeView.superview == nil {
                    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                        window.addSubview(self.volumeView)
                    }
                }

                // Find and use the slider to set volume
                if let slider = self.volumeView.subviews.first(where: { $0 is UISlider })
                    as? UISlider
                {
                    slider.value = Float(volume)
                }
                completion(.success(()))
            }
            return
        #elseif os(macOS)
            // macOS: Use AppleScript to set system volume (0-100 scale)
            let volumePercent = Int(volume * 100)
            let script = "set volume output volume \(volumePercent)"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    completion(.failure(PigeonError(code: "VOLUME_ERROR", message: "Failed to set volume: \(error)", details: nil)))
                } else {
                    completion(.success(()))
                }
            } else {
                completion(.failure(PigeonError(code: "VOLUME_ERROR", message: "Failed to create AppleScript", details: nil)))
            }
        #endif
    }

    func getScreenBrightness(completion: @escaping (Result<Double, Error>) -> Void) {

        #if os(iOS)
            let brightness = UIScreen.main.brightness
            completion(.success(Double(brightness)))
        #elseif os(macOS)
            // macOS doesn't have a simple API to get screen brightness
            completion(.success(1.0))
        #endif
    }

    func setScreenBrightness(brightness: Double, completion: @escaping (Result<Void, Error>) -> Void) {

        guard brightness >= 0.0 && brightness <= 1.0 else {
            completion(.failure(PigeonError(code: "INVALID_ARGS", message: "Brightness must be between 0.0 and 1.0", details: nil)))
            return
        }

        #if os(iOS)
            UIScreen.main.brightness = CGFloat(brightness)
            completion(.success(()))
        #elseif os(macOS)
            // macOS brightness control requires private APIs or external tools
            // For now, just return success as a no-op
            _ = brightness  // Suppress unused variable warning
            completion(.success(()))
        #endif
    }

    func getBatteryInfo(completion: @escaping (Result<BatteryInfoMessage?, Error>) -> Void) {

        #if os(iOS)
            // Enable battery monitoring
            UIDevice.current.isBatteryMonitoringEnabled = true

            let batteryLevel = UIDevice.current.batteryLevel
            // batteryLevel returns -1.0 if battery state is unknown
            if batteryLevel < 0 {
                completion(.success(nil))
                return
            }

            let batteryState = UIDevice.current.batteryState
            let isCharging = batteryState == .charging || batteryState == .full
            let percentage = Int(batteryLevel * 100)

            let batteryInfo = BatteryInfoMessage(percentage: Int64(percentage), isCharging: isCharging)
            completion(.success(batteryInfo))
        #elseif os(macOS)
            // Use IOKit to get battery info on macOS
            let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

            guard let source = sources.first else {
                // No battery (desktop Mac)
                completion(.success(nil))
                return
            }

            guard let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else {
                completion(.success(nil))
                return
            }

            // Get current capacity and max capacity to calculate percentage
            if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                let percentage = (currentCapacity * 100) / maxCapacity
                let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false

                let batteryInfo = BatteryInfoMessage(percentage: Int64(percentage), isCharging: isCharging)
                completion(.success(batteryInfo))
            } else {
                completion(.success(nil))
            }
        #endif
    }

    func setLooping(playerId: Int64, looping: Bool, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.setLooping(looping)
        completion(.success(()))
    }

    func setScalingMode(playerId: Int64, mode: VideoScalingModeEnum, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let scalingMode = convertScalingModeToString(mode)
        player.setScalingMode(scalingMode)
        completion(.success(()))
    }

    func setControlsMode(playerId: Int64, mode: ControlsModeEnum, completion: @escaping (Result<Void, Error>) -> Void) {

        let controlsMode: ControlsMode =
            switch mode {
            case .nativeControls: .native
            case .flutterControls: .custom  // Flutter controls are handled as custom on native side
            case .videoOnly: .none
            case .customControls: .custom
            }

        VideoPlayerViewRegistry.shared.setControlsMode(for: Int(playerId), mode: controlsMode)
        completion(.success(()))
    }

    func setSubtitleTrack(playerId: Int64, track: SubtitleTrackMessage?, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let trackDict: [String: Any]? = track.map {
            [
                "id": $0.id,
                "label": $0.label as Any,
                "language": $0.language as Any,
                "isDefault": $0.isDefault as Any
            ]
        }

        player.setSubtitleTrack(trackDict)
        completion(.success(()))
    }

    func setSubtitleRenderMode(playerId: Int64, mode: SubtitleRenderModeEnum, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let modeString: String = switch mode {
        case .native: "native"
        case .flutter: "flutter"
        case .auto: "auto"
        }

        player.setSubtitleRenderMode(modeString)
        completion(.success(()))
    }

    func setAudioTrack(playerId: Int64, track: AudioTrackMessage?, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let trackDict: [String: Any]? = track.map {
            [
                "id": $0.id,
                "label": $0.label as Any,
                "language": $0.language as Any,
                "isDefault": $0.isDefault as Any
            ]
        }

        player.setAudioTrack(trackDict)
        completion(.success(()))
    }

    // MARK: - External Subtitles

    func addExternalSubtitle(playerId: Int64, source: SubtitleSourceMessage, completion: @escaping (Result<ExternalSubtitleTrackMessage?, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        // Convert VideoSourceType enum to string
        let sourceTypeString: String
        switch source.type {
        case .network:
            sourceTypeString = "network"
        case .file:
            sourceTypeString = "file"
        case .asset:
            sourceTypeString = "asset"
        }

        // Convert optional format to string
        let formatString: String? = source.format.map { convertSubtitleFormatToString($0) }

        player.addExternalSubtitle(
            sourceType: sourceTypeString,
            path: source.path,
            format: formatString,
            label: source.label,
            language: source.language,
            isDefault: source.isDefault
        ) { trackDict in
            guard let trackDict = trackDict as? [String: Any] else {
                completion(.success(nil))
                return
            }

            let track = ExternalSubtitleTrackMessage(
                id: trackDict["id"] as? String ?? "",
                label: trackDict["label"] as? String ?? "",
                language: trackDict["language"] as? String,
                isDefault: trackDict["isDefault"] as? Bool ?? false,
                path: trackDict["path"] as? String ?? "",
                sourceType: trackDict["sourceType"] as? String ?? "",
                format: self.convertStringToSubtitleFormat(trackDict["format"] as? String ?? "vtt")
            )
            completion(.success(track))
        }
    }

    func removeExternalSubtitle(playerId: Int64, trackId: String, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let success = player.removeExternalSubtitle(trackId: trackId)
        completion(.success(success))
    }

    func getExternalSubtitles(playerId: Int64, completion: @escaping (Result<[ExternalSubtitleTrackMessage?], Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let tracksArray = player.getExternalSubtitles() as? [[String: Any]] else {
            completion(.success([]))
            return
        }

        let tracks = tracksArray.map { trackDict -> ExternalSubtitleTrackMessage in
            ExternalSubtitleTrackMessage(
                id: trackDict["id"] as? String ?? "",
                label: trackDict["label"] as? String ?? "",
                language: trackDict["language"] as? String,
                isDefault: trackDict["isDefault"] as? Bool ?? false,
                path: trackDict["path"] as? String ?? "",
                sourceType: trackDict["sourceType"] as? String ?? "",
                format: convertStringToSubtitleFormat(trackDict["format"] as? String ?? "vtt")
            )
        }
        completion(.success(tracks))
    }

    func getPosition(playerId: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let position = player.getPosition()
        completion(.success(Int64(position)))
    }

    func getDuration(playerId: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let duration = player.getDuration()
        completion(.success(Int64(duration)))
    }

    // MARK: - Picture-in-Picture

    func enterPip(playerId: Int64, options: PipOptionsMessage, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let success = player.enterPip()
        completion(.success(success))
    }

    func exitPip(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.exitPip()
        completion(.success(()))
    }

    func isPipSupported(completion: @escaping (Result<Bool, Error>) -> Void) {
        let supported = platformBehavior.isPipSupported()
        completion(.success(supported))
    }

    func setPipActions(playerId: Int64, actions: [PipActionMessage?], completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        // Convert Pigeon actions to dictionary format
        let actionsArray = actions.compactMap { action -> [String: Any]? in
            guard let action = action else { return nil }
            var dict: [String: Any] = ["type": convertPipActionTypeToString(action.type)]
            if let skipIntervalMs = action.skipIntervalMs {
                dict["skipIntervalMs"] = skipIntervalMs
            }
            return dict
        }

        // Create a fake FlutterMethodCall for platform behavior
        let args: [String: Any] = ["playerId": Int(playerId), "actions": actionsArray]
        let call = FlutterMethodCall(methodName: "setPipActions", arguments: args)

        platformBehavior.handleSetPipActions(call: call, player: player) { result in
            if let error = result as? FlutterError {
                completion(.failure(PigeonError(code: error.code, message: error.message, details: error.details)))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Fullscreen

    func enterFullscreen(playerId: Int64, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let success = player.enterFullscreen()
        completion(.success(success))
    }

    func exitFullscreen(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.exitFullscreen()
        completion(.success(()))
    }

    func setWindowFullscreen(fullscreen: Bool, completion: @escaping (Result<Void, Error>) -> Void) {

        // Return immediately to avoid blocking Flutter
        completion(.success(()))

        #if os(macOS)
            // Perform window fullscreen toggle asynchronously after a brief delay
            // This prevents conflicts with Flutter's navigation animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let window = NSApplication.shared.mainWindow else {
                    return
                }

                let isCurrentlyFullscreen = window.styleMask.contains(.fullScreen)

                // Only toggle if the desired state differs from current state
                if fullscreen != isCurrentlyFullscreen {
                    window.toggleFullScreen(nil)
                }
            }
        #endif
    }

    // MARK: - Media Metadata and Quality

    func setMediaMetadata(playerId: Int64, metadata: MediaMetadataMessage, completion: @escaping (Result<Void, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        var metadataDict: [String: Any] = [:]
        if let title = metadata.title {
            metadataDict["title"] = title
        }
        if let artist = metadata.artist {
            metadataDict["artist"] = artist
        }
        if let album = metadata.album {
            metadataDict["album"] = album
        }
        if let artworkUrl = metadata.artworkUrl {
            metadataDict["artworkUrl"] = artworkUrl
        }

        player.setMediaMetadata(metadataDict)
        completion(.success(()))
    }

    func getVideoMetadata(playerId: Int64, completion: @escaping (Result<VideoMetadataMessage?, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let metadataDict = player.getVideoMetadata() as? [String: Any] else {
            completion(.success(nil))
            return
        }

        let metadata = VideoMetadataMessage(
            duration: metadataDict["duration"] as? Int64,
            width: metadataDict["width"] as? Int64,
            height: metadataDict["height"] as? Int64,
            videoCodec: metadataDict["videoCodec"] as? String,
            audioCodec: metadataDict["audioCodec"] as? String,
            bitrate: metadataDict["bitrate"] as? Int64,
            frameRate: metadataDict["frameRate"] as? Double
        )
        completion(.success(metadata))
    }

    func extractEmbeddedArtwork(source: VideoSourceMessage, completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void) {
        verboseLog("extractEmbeddedArtwork() called for source type: \(source.type)", tag: "Plugin")

        // Build URL from source
        let url: URL?
        switch source.type {
        case .network:
            if let urlString = source.url {
                url = URL(string: urlString)
            } else {
                url = nil
            }
        case .file:
            if let path = source.path {
                url = URL(fileURLWithPath: path)
            } else {
                url = nil
            }
        case .asset:
            if let assetPath = source.assetPath {
                #if os(iOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #elseif os(macOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #endif
            } else {
                url = nil
            }
        }

        guard let assetUrl = url else {
            completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Could not create URL from source", details: nil)))
            return
        }

        // Create AVURLAsset with headers if needed
        var options: [String: Any] = [:]
        if source.type == .network, let headers = source.headers {
            let cleanHeaders = headers.compactMapValues { $0 }
            options["AVURLAssetHTTPHeaderFieldsKey"] = cleanHeaders
        }

        let asset = AVURLAsset(url: assetUrl, options: options.isEmpty ? nil : options)

        // Load metadata asynchronously
        if #available(iOS 15.0, macOS 12.0, *) {
            Task {
                do {
                    let metadata = try await asset.load(.metadata)
                    let artworkData = self.extractArtworkFromMetadata(metadata)
                    await MainActor.run {
                        if let data = artworkData {
                            verboseLog("extractEmbeddedArtwork() found artwork: \(data.count) bytes", tag: "Plugin")
                            completion(.success(FlutterStandardTypedData(bytes: data)))
                        } else {
                            verboseLog("extractEmbeddedArtwork() no artwork found", tag: "Plugin")
                            completion(.success(nil))
                        }
                    }
                } catch {
                    await MainActor.run {
                        verboseLog("extractEmbeddedArtwork() failed: \(error)", tag: "Plugin")
                        // Return nil instead of error for unsupported sources
                        completion(.success(nil))
                    }
                }
            }
        } else {
            // iOS 14 / macOS 11 fallback
            asset.loadValuesAsynchronously(forKeys: ["metadata"]) {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "metadata", error: &error)

                DispatchQueue.main.async {
                    if status == .loaded {
                        let artworkData = self.extractArtworkFromMetadata(asset.metadata)
                        if let data = artworkData {
                            verboseLog("extractEmbeddedArtwork() found artwork: \(data.count) bytes", tag: "Plugin")
                            completion(.success(FlutterStandardTypedData(bytes: data)))
                        } else {
                            verboseLog("extractEmbeddedArtwork() no artwork found", tag: "Plugin")
                            completion(.success(nil))
                        }
                    } else {
                        verboseLog("extractEmbeddedArtwork() failed to load metadata: \(error?.localizedDescription ?? "unknown")", tag: "Plugin")
                        // Return nil instead of error
                        completion(.success(nil))
                    }
                }
            }
        }
    }

    /// Extracts artwork data from AVMetadataItem array.
    private func extractArtworkFromMetadata(_ metadata: [AVMetadataItem]) -> Data? {
        // Look for artwork in common metadata
        let artworkItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtwork
        )

        for item in artworkItems {
            if let data = item.dataValue {
                return data
            }
            // Some items store artwork as an image
            if let value = item.value {
                if let data = value as? Data {
                    return data
                }
                #if os(iOS)
                    if let image = value as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                        return data
                    }
                #elseif os(macOS)
                    if let image = value as? NSImage {
                        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                            if let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                                return data
                            }
                        }
                    }
                #endif
            }
        }

        // Also check for iTunes-style artwork (for MP4/M4V files)
        let iTunesArtwork = metadata.first { item in
            item.identifier == .iTunesMetadataCoverArt
        }

        if let item = iTunesArtwork {
            if let data = item.dataValue {
                return data
            }
        }

        return nil
    }

    func extractVideoFrame(
        source: VideoSourceMessage,
        positionMs: Int64,
        maxWidth: Int64?,
        maxHeight: Int64?,
        quality: Int64?,
        completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
    ) {
        verboseLog("extractVideoFrame() called for position: \(positionMs)ms", tag: "Plugin")

        // Build URL from source (same logic as extractEmbeddedArtwork)
        let url: URL?
        switch source.type {
        case .network:
            if let urlString = source.url {
                url = URL(string: urlString)
            } else {
                url = nil
            }
        case .file:
            if let path = source.path {
                url = URL(fileURLWithPath: path)
            } else {
                url = nil
            }
        case .asset:
            if let assetPath = source.assetPath {
                #if os(iOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #elseif os(macOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #endif
            } else {
                url = nil
            }
        }

        guard let assetUrl = url else {
            completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Could not create URL from source", details: nil)))
            return
        }

        // Create AVURLAsset with headers if needed
        var options: [String: Any] = [:]
        if source.type == .network, let headers = source.headers {
            let cleanHeaders = headers.compactMapValues { $0 }
            options["AVURLAssetHTTPHeaderFieldsKey"] = cleanHeaders
        }

        let asset = AVURLAsset(url: assetUrl, options: options.isEmpty ? nil : options)

        // Create image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        // Set max size if specified
        if let maxW = maxWidth, let maxH = maxHeight {
            imageGenerator.maximumSize = CGSize(width: CGFloat(maxW), height: CGFloat(maxH))
        } else if let maxW = maxWidth {
            imageGenerator.maximumSize = CGSize(width: CGFloat(maxW), height: CGFloat.greatestFiniteMagnitude)
        } else if let maxH = maxHeight {
            imageGenerator.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat(maxH))
        }

        // Convert position to CMTime
        let time = CMTime(value: CMTimeValue(positionMs), timescale: 1000)

        // Generate image asynchronously
        if #available(iOS 16.0, macOS 13.0, *) {
            Task {
                do {
                    let (cgImage, _) = try await imageGenerator.image(at: time)
                    let jpegData = self.cgImageToJPEG(cgImage, quality: quality)
                    await MainActor.run {
                        if let data = jpegData {
                            verboseLog("extractVideoFrame() result: \(data.count) bytes", tag: "Plugin")
                            completion(.success(FlutterStandardTypedData(bytes: data)))
                        } else {
                            verboseLog("extractVideoFrame() failed to convert to JPEG", tag: "Plugin")
                            completion(.success(nil))
                        }
                    }
                } catch {
                    await MainActor.run {
                        verboseLog("extractVideoFrame() failed: \(error)", tag: "Plugin")
                        completion(.success(nil))
                    }
                }
            }
        } else {
            // Fallback for older OS versions
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                DispatchQueue.main.async {
                    if result == .succeeded, let cgImage = cgImage {
                        let jpegData = self.cgImageToJPEG(cgImage, quality: quality)
                        if let data = jpegData {
                            verboseLog("extractVideoFrame() result: \(data.count) bytes", tag: "Plugin")
                            completion(.success(FlutterStandardTypedData(bytes: data)))
                        } else {
                            verboseLog("extractVideoFrame() failed to convert to JPEG", tag: "Plugin")
                            completion(.success(nil))
                        }
                    } else {
                        verboseLog("extractVideoFrame() failed: \(error?.localizedDescription ?? "unknown")", tag: "Plugin")
                        completion(.success(nil))
                    }
                }
            }
        }
    }

    /// Converts a CGImage to JPEG data.
    private func cgImageToJPEG(_ cgImage: CGImage, quality: Int64?) -> Data? {
        let compressionQuality = CGFloat(quality ?? 80) / 100.0

        #if os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: compressionQuality)
        #elseif os(macOS)
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #endif
    }

    func extractContentFingerprint(
        source: VideoSourceMessage,
        completion: @escaping (Result<ContentFingerprintMessage, Error>) -> Void
    ) {
        verboseLog("extractContentFingerprint() called for source type: \(source.type)", tag: "Plugin")

        let sampleSize = 8 * 1024 // 8KB per sample

        // Build URL from source
        let url: URL?
        switch source.type {
        case .network:
            if let urlString = source.url {
                url = URL(string: urlString)
            } else {
                url = nil
            }
        case .file:
            if let path = source.path {
                url = URL(fileURLWithPath: path)
            } else {
                url = nil
            }
        case .asset:
            if let assetPath = source.assetPath {
                #if os(iOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #elseif os(macOS)
                    let registrar = self.registrar as! FlutterPluginRegistrar
                    let key = registrar.lookupKey(forAsset: assetPath)
                    if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
                        url = URL(fileURLWithPath: bundlePath)
                    } else {
                        url = nil
                    }
                #endif
            } else {
                url = nil
            }
        }

        guard let sourceUrl = url else {
            completion(.success(ContentFingerprintMessage(error: "Could not create URL from source")))
            return
        }

        // Handle local files directly
        if sourceUrl.isFileURL {
            extractLocalFileFingerprint(url: sourceUrl, sampleSize: sampleSize, completion: completion)
        } else {
            extractNetworkFileFingerprint(
                url: sourceUrl, headers: source.headers, sampleSize: sampleSize, completion: completion
            )
        }
    }

    private func extractLocalFileFingerprint(
        url: URL, sampleSize: Int, completion: @escaping (Result<ContentFingerprintMessage, Error>) -> Void
    ) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

            var samples = Data()

            // Read from start
            try fileHandle.seek(toOffset: 0)
            let startSample = fileHandle.readData(ofLength: min(sampleSize, Int(fileSize)))
            samples.append(startSample)

            // Read from middle
            if fileSize > sampleSize {
                let middlePos = (fileSize / 2) - Int64(sampleSize / 2)
                try fileHandle.seek(toOffset: UInt64(max(0, middlePos)))
                let middleSample = fileHandle.readData(ofLength: min(sampleSize, Int(fileSize - middlePos)))
                samples.append(middleSample)
            }

            // Read from end
            if fileSize > sampleSize * 2 {
                let endPos = fileSize - Int64(sampleSize)
                try fileHandle.seek(toOffset: UInt64(max(0, endPos)))
                let endSample = fileHandle.readData(ofLength: sampleSize)
                samples.append(endSample)
            }

            // Compute SHA-256 hash
            let fingerprint = sha256Hex(data: samples)

            verboseLog(
                "extractContentFingerprint() result: fingerprint=\(fingerprint), fileSize=\(fileSize)", tag: "Plugin"
            )
            completion(.success(ContentFingerprintMessage(fingerprint: fingerprint, fileSize: fileSize)))
        } catch {
            verboseLog("extractContentFingerprint() failed: \(error)", tag: "Plugin")
            completion(.success(ContentFingerprintMessage(error: error.localizedDescription)))
        }
    }

    private func extractNetworkFileFingerprint(
        url: URL, headers: [String?: String?]?, sampleSize: Int,
        completion: @escaping (Result<ContentFingerprintMessage, Error>) -> Void
    ) {
        // First, get file size with HEAD request
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        if let headers = headers {
            for (key, value) in headers {
                if let k = key, let v = value {
                    headRequest.setValue(v, forHTTPHeaderField: k)
                }
            }
        }

        URLSession.shared.dataTask(with: headRequest) { [weak self] _, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(.success(ContentFingerprintMessage(error: error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String,
                let fileSize = Int64(contentLength)
            else {
                DispatchQueue.main.async {
                    completion(.success(ContentFingerprintMessage(error: "Cannot determine file size from network source")))
                }
                return
            }

            // Now read samples using Range requests
            self.readNetworkSamples(
                url: url, headers: headers, fileSize: fileSize, sampleSize: sampleSize, completion: completion
            )
        }.resume()
    }

    private func readNetworkSamples(
        url: URL, headers: [String?: String?]?, fileSize: Int64, sampleSize: Int,
        completion: @escaping (Result<ContentFingerprintMessage, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var samples = [Int: Data]()  // Position -> Data
        var error: String?

        // Helper to create a range request
        func createRangeRequest(start: Int64, length: Int) -> URLRequest {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let headers = headers {
                for (key, value) in headers {
                    if let k = key, let v = value {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                }
            }
            request.setValue("bytes=\(start)-\(start + Int64(length) - 1)", forHTTPHeaderField: "Range")
            return request
        }

        // Read start sample
        group.enter()
        let startRequest = createRangeRequest(start: 0, length: sampleSize)
        URLSession.shared.dataTask(with: startRequest) { data, _, err in
            if let err = err {
                error = err.localizedDescription
            } else if let data = data {
                samples[0] = data
            }
            group.leave()
        }.resume()

        // Read middle sample
        if fileSize > sampleSize {
            group.enter()
            let middlePos = (fileSize / 2) - Int64(sampleSize / 2)
            let middleRequest = createRangeRequest(start: middlePos, length: sampleSize)
            URLSession.shared.dataTask(with: middleRequest) { data, _, err in
                if let err = err {
                    error = err.localizedDescription
                } else if let data = data {
                    samples[1] = data
                }
                group.leave()
            }.resume()
        }

        // Read end sample
        if fileSize > sampleSize * 2 {
            group.enter()
            let endPos = fileSize - Int64(sampleSize)
            let endRequest = createRangeRequest(start: endPos, length: sampleSize)
            URLSession.shared.dataTask(with: endRequest) { data, _, err in
                if let err = err {
                    error = err.localizedDescription
                } else if let data = data {
                    samples[2] = data
                }
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            if let error = error {
                completion(.success(ContentFingerprintMessage(error: error)))
                return
            }

            // Combine samples in order
            var combinedData = Data()
            for i in 0..<3 {
                if let data = samples[i] {
                    combinedData.append(data)
                }
            }

            // Compute SHA-256 hash
            let fingerprint = self?.sha256Hex(data: combinedData) ?? ""

            verboseLog("extractContentFingerprint() result: fingerprint=\(fingerprint), fileSize=\(fileSize)", tag: "Plugin")
            completion(.success(ContentFingerprintMessage(fingerprint: fingerprint, fileSize: fileSize)))
        }
    }

    private func sha256Hex(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func getVideoQualities(playerId: Int64, completion: @escaping (Result<[VideoQualityTrackMessage?], Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let qualitiesArray = player.getVideoQualities() as? [[String: Any]] else {
            completion(.success([]))
            return
        }

        let qualities = qualitiesArray.map { qualityDict -> VideoQualityTrackMessage in
            VideoQualityTrackMessage(
                id: qualityDict["id"] as? String ?? "",
                label: qualityDict["label"] as? String,
                bitrate: qualityDict["bitrate"] as? Int64,
                width: qualityDict["width"] as? Int64,
                height: qualityDict["height"] as? Int64,
                codec: qualityDict["codec"] as? String,
                isDefault: qualityDict["isDefault"] as? Bool
            )
        }
        completion(.success(qualities))
    }

    func setVideoQuality(playerId: Int64, track: VideoQualityTrackMessage, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        var trackDict: [String: Any] = ["id": track.id]
        if let bitrate = track.bitrate {
            trackDict["bitrate"] = Int(bitrate)
        }
        if let width = track.width {
            trackDict["width"] = Int(width)
        }
        if let height = track.height {
            trackDict["height"] = Int(height)
        }
        if let label = track.label {
            trackDict["label"] = label
        }
        if let codec = track.codec {
            trackDict["codec"] = codec
        }
        if let isDefault = track.isDefault {
            trackDict["isDefault"] = isDefault
        }

        let success = player.setVideoQuality(trackDict)
        completion(.success(success))
    }

    func getCurrentVideoQuality(playerId: Int64, completion: @escaping (Result<VideoQualityTrackMessage, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let qualityDict = player.getCurrentVideoQuality() as? [String: Any] else {
            completion(.failure(PigeonError(code: "NOT_FOUND", message: "Current quality not found", details: nil)))
            return
        }

        let quality = VideoQualityTrackMessage(
            id: qualityDict["id"] as? String ?? "",
            label: qualityDict["label"] as? String,
            bitrate: qualityDict["bitrate"] as? Int64,
            width: qualityDict["width"] as? Int64,
            height: qualityDict["height"] as? Int64,
            codec: qualityDict["codec"] as? String,
            isDefault: qualityDict["isDefault"] as? Bool
        )
        completion(.success(quality))
    }

    func isQualitySelectionSupported(playerId: Int64, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let supported = player.isQualitySelectionSupported()
        completion(.success(supported))
    }

    // MARK: - Background Playback

    func setBackgroundPlayback(playerId: Int64, enabled: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        let success = player.setBackgroundPlayback(enabled)
        completion(.success(success))
    }

    func isBackgroundPlaybackSupported(completion: @escaping (Result<Bool, Error>) -> Void) {
        let supported = platformBehavior.isBackgroundPlaybackSupported()
        completion(.success(supported))
    }

    // MARK: - Casting

    func isCastingSupported(completion: @escaping (Result<Bool, Error>) -> Void) {
        // AirPlay is always supported on iOS/macOS
        completion(.success(true))
    }

    func getAvailableCastDevices(playerId: Int64, completion: @escaping (Result<[CastDeviceMessage?], Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        // AirPlay device discovery is handled by the system, not exposed programmatically
        completion(.success([]))
    }

    func startCasting(playerId: Int64, device: CastDeviceMessage?, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        // Device is optional - on iOS/macOS AirPlay selection is done via system UI
        let deviceDict: [String: Any] = device.map {
            ["id": $0.id, "name": $0.name, "type": convertCastDeviceTypeToString($0.type)]
        } ?? [:]

        let success = player.startCasting(device: deviceDict)
        completion(.success(success))
    }

    func stopCasting(playerId: Int64, completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        player.stopCasting()
        completion(.success(true))
    }

    func getCastState(playerId: Int64, completion: @escaping (Result<CastStateEnum, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let stateString = player.getCastState() as? String else {
            completion(.success(.notConnected))
            return
        }

        let state = convertStringToCastState(stateString)
        completion(.success(state))
    }

    func getCurrentCastDevice(playerId: Int64, completion: @escaping (Result<CastDeviceMessage?, Error>) -> Void) {

        guard let player = players[Int(playerId)] else {
            completion(.failure(PigeonError(code: "INVALID_PLAYER", message: "Player \(playerId) not found", details: nil)))
            return
        }

        guard let deviceDict = player.getCurrentCastDevice() as? [String: Any] else {
            completion(.success(nil))
            return
        }

        let device = CastDeviceMessage(
            id: deviceDict["id"] as? String ?? "",
            name: deviceDict["name"] as? String ?? "",
            type: convertStringToCastDeviceType(deviceDict["type"] as? String ?? "unknown")
        )
        completion(.success(device))
    }

    // MARK: - Platform Capabilities

    func getPlatformInfo(completion: @escaping (Result<PlatformInfoMessage, Error>) -> Void) {

        #if os(iOS)
        let platformName = "iOS"
        #elseif os(macOS)
        let platformName = "macOS"
        #else
        let platformName = "Unknown"
        #endif

        let info = PlatformInfoMessage(
            platformName: platformName,
            nativePlayerType: "AVPlayer",
            additionalInfo: nil
        )
        completion(.success(info))
    }

    func setVerboseLogging(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        VerboseLogger.shared.setEnabled(enabled)
        completion(.success(()))
    }

    func supportsPictureInPicture(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(platformBehavior.isPipSupported()))
    }

    func supportsFullscreen(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsBackgroundPlayback(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(platformBehavior.isBackgroundPlaybackSupported()))
    }

    func supportsCasting(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsAirPlay(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsChromecast(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func supportsRemotePlayback(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func supportsQualitySelection(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsPlaybackSpeedControl(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsSubtitles(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsExternalSubtitles(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsAudioTrackSelection(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsChapters(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsVideoMetadataExtraction(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsNetworkMonitoring(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsBandwidthEstimation(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsAdaptiveBitrate(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsHLS(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsDASH(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    func supportsDeviceVolumeControl(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func supportsScreenBrightnessControl(completion: @escaping (Result<Bool, Error>) -> Void) {
        #if os(iOS)
        completion(.success(true))
        #else
        completion(.success(false))
        #endif
    }

    // MARK: - Codec Compatibility

    func checkCodecSupport(codec: CodecInfoMessage, completion: @escaping (Result<CodecCompatibilityMessage, Error>) -> Void) {
        verboseLog("checkCodecSupport() called for codec: \(codec.name) (\(codec.fourcc))", tag: "Plugin")

        // Build MIME type for checking
        guard let mimeType = buildMimeType(from: codec) else {
            let result = CodecCompatibilityMessage(
                codec: codec,
                supportLevel: .unknown,
                message: "Unable to determine MIME type for codec \(codec.fourcc)",
                minimumOsVersion: nil,
                alternativeCodecs: nil
            )
            completion(.success(result))
            return
        }

        // Check using AVURLAsset.isPlayableExtendedMIMEType
        let isPlayable = AVURLAsset.isPlayableExtendedMIMEType(mimeType)

        let supportLevel: CodecSupportLevelEnum
        var message: String?
        var alternativeCodecs: [String?]?

        if isPlayable {
            supportLevel = .supported
            message = "AVURLAsset.isPlayableExtendedMIMEType returned true"
        } else {
            supportLevel = .notSupported
            message = "Codec not supported on this device"
            alternativeCodecs = suggestAlternatives(for: codec)
        }

        // Check minimum OS version requirements for specific codecs
        let minimumOsVersion = getMinimumOsVersion(for: codec)

        let result = CodecCompatibilityMessage(
            codec: CodecInfoMessage(
                fourcc: codec.fourcc,
                name: codec.name,
                codecString: codec.codecString,
                mimeType: mimeType
            ),
            supportLevel: supportLevel,
            message: message,
            minimumOsVersion: minimumOsVersion,
            alternativeCodecs: alternativeCodecs
        )
        completion(.success(result))
    }

    func checkCodecsSupport(codecs: [CodecInfoMessage?], completion: @escaping (Result<[CodecCompatibilityMessage?], Error>) -> Void) {
        verboseLog("checkCodecsSupport() called for \(codecs.count) codecs", tag: "Plugin")

        var results: [CodecCompatibilityMessage?] = []
        let dispatchGroup = DispatchGroup()

        for codec in codecs {
            guard let codec = codec else {
                results.append(nil)
                continue
            }

            dispatchGroup.enter()
            checkCodecSupport(codec: codec) { result in
                switch result {
                case .success(let compatibility):
                    results.append(compatibility)
                case .failure:
                    results.append(nil)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(.success(results))
        }
    }

    func getSupportedCodecs(completion: @escaping (Result<[String?], Error>) -> Void) {
        verboseLog("getSupportedCodecs() called", tag: "Plugin")

        // List of common codecs to check
        let codecsToCheck: [(name: String, mimeType: String)] = [
            // Video codecs
            ("H.264", "video/mp4; codecs=\"avc1.42E01E\""),
            ("H.264 High", "video/mp4; codecs=\"avc1.640028\""),
            ("HEVC", "video/mp4; codecs=\"hvc1.1.6.L93.B0\""),
            ("VP9", "video/webm; codecs=\"vp09.00.10.08\""),
            ("AV1", "video/mp4; codecs=\"av01.0.05M.08\""),
            // Audio codecs
            ("AAC", "audio/mp4; codecs=\"mp4a.40.2\""),
            ("MP3", "audio/mpeg"),
            ("AC-3", "audio/mp4; codecs=\"ac-3\""),
            ("E-AC-3", "audio/mp4; codecs=\"ec-3\""),
            ("ALAC", "audio/mp4; codecs=\"alac\""),
            ("FLAC", "audio/flac")
        ]

        var supportedCodecs: [String?] = []

        for (name, mimeType) in codecsToCheck {
            if AVURLAsset.isPlayableExtendedMIMEType(mimeType) {
                supportedCodecs.append(name)
            }
        }

        verboseLog("Supported codecs: \(supportedCodecs.compactMap { $0 }.joined(separator: ", "))", tag: "Plugin")
        completion(.success(supportedCodecs))
    }

    /// Builds a MIME type string for codec compatibility checking.
    private func buildMimeType(from codec: CodecInfoMessage) -> String? {
        // If codec already has a mimeType, use it
        if let mimeType = codec.mimeType, !mimeType.isEmpty {
            return mimeType
        }

        let fourcc = codec.fourcc.lowercased()
        let codecString = codec.codecString ?? fourcc

        // Video codecs
        switch fourcc {
        case "avc1", "avc3":
            return "video/mp4; codecs=\"\(codecString)\""
        case "hvc1", "hev1":
            return "video/mp4; codecs=\"\(codecString)\""
        case "vp08":
            return "video/webm; codecs=\"vp8\""
        case "vp09":
            let cs = codec.codecString ?? "vp09.00.10.08"
            return "video/webm; codecs=\"\(cs)\""
        case "av01":
            let cs = codec.codecString ?? "av01.0.05M.08"
            return "video/mp4; codecs=\"\(cs)\""
        case "mp4v":
            return "video/mp4; codecs=\"mp4v.20.3\""
        default:
            break
        }

        // Audio codecs
        switch fourcc {
        case "mp4a":
            let cs = codec.codecString ?? "mp4a.40.2"
            return "audio/mp4; codecs=\"\(cs)\""
        case "ac-3":
            return "audio/mp4; codecs=\"ac-3\""
        case "ec-3":
            return "audio/mp4; codecs=\"ec-3\""
        case "opus":
            return "audio/webm; codecs=\"opus\""
        case "flac":
            return "audio/flac"
        case "alac":
            return "audio/mp4; codecs=\"alac\""
        case "mp3 ", ".mp3":
            return "audio/mpeg"
        default:
            break
        }

        // For unknown codecs, try to build a generic MIME type
        return nil
    }

    /// Suggests alternative codecs when a codec is not supported.
    private func suggestAlternatives(for codec: CodecInfoMessage) -> [String?] {
        let fourcc = codec.fourcc.lowercased()

        // Video codec alternatives
        switch fourcc {
        case "hvc1", "hev1":
            return ["H.264", "VP9"]
        case "av01":
            return ["H.264", "VP9", "HEVC"]
        case "vp09":
            return ["H.264", "VP8"]
        case "vp08":
            return ["H.264"]
        default:
            break
        }

        // Audio codec alternatives
        switch fourcc {
        case "ac-3", "ec-3":
            return ["AAC", "MP3"]
        case "alac":
            return ["AAC", "FLAC"]
        case "opus":
            return ["AAC", "MP3"]
        default:
            break
        }

        return []
    }

    /// Returns the minimum OS version required for a specific codec.
    private func getMinimumOsVersion(for codec: CodecInfoMessage) -> String? {
        let fourcc = codec.fourcc.lowercased()

        #if os(iOS)
        switch fourcc {
        case "av01":
            return "16.0" // AV1 requires iOS 16+
        case "hvc1", "hev1":
            return "11.0" // HEVC requires iOS 11+
        default:
            return nil
        }
        #elseif os(macOS)
        switch fourcc {
        case "av01":
            return "13.0" // AV1 requires macOS 13+
        case "hvc1", "hev1":
            return "10.13" // HEVC requires macOS 10.13+
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        #if os(iOS)
            // Enable battery monitoring
            UIDevice.current.isBatteryMonitoringEnabled = true

            // Register for battery notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(batteryLevelDidChange),
                name: UIDevice.batteryLevelDidChangeNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(batteryStateDidChange),
                name: UIDevice.batteryStateDidChangeNotification,
                object: nil
            )

            // Send initial battery state
            sendBatteryUpdate()
        #elseif os(macOS)
            // macOS: Send initial state only (no continuous monitoring)
            // Platform implementations can call getBatteryInfo() for updates
            sendBatteryUpdate()
        #endif
    }

    #if os(iOS)
        @objc private func batteryLevelDidChange() {
            sendBatteryUpdate()
        }

        @objc private func batteryStateDidChange() {
            sendBatteryUpdate()
        }
    #endif

    private func sendBatteryUpdate() {
        #if os(iOS)
            let batteryLevel = UIDevice.current.batteryLevel
            if batteryLevel < 0 {
                // Battery state unknown - don't send update
                return
            }

            let batteryState = UIDevice.current.batteryState
            let isCharging = batteryState == .charging || batteryState == .full
            let percentage = Int64(batteryLevel * 100)

            let batteryInfo = BatteryInfoMessage(percentage: percentage, isCharging: isCharging)
            flutterApi.onBatteryInfoChanged(batteryInfo: batteryInfo) { _ in }
        #elseif os(macOS)
            let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

            guard let source = sources.first,
                  let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
                  let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                  maxCapacity > 0 else {
                // No battery or invalid data
                return
            }

            let percentage = Int64((currentCapacity * 100) / maxCapacity)
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false

            let batteryInfo = BatteryInfoMessage(percentage: percentage, isCharging: isCharging)
            flutterApi.onBatteryInfoChanged(batteryInfo: batteryInfo) { _ in }
        #endif
    }

    // MARK: - Conversion Helper Methods

    private func convertVideoSourceToDict(_ source: VideoSourceMessage) -> [String: Any] {
        var dict: [String: Any] = [:]

        switch source.type {
        case .network:
            dict["type"] = "network"
            if let url = source.url {
                dict["url"] = url
            }
            if let headers = source.headers {
                dict["headers"] = headers.compactMapValues { $0 }
            }
        case .file:
            dict["type"] = "file"
            if let path = source.path {
                dict["path"] = path
            }
        case .asset:
            dict["type"] = "asset"
            if let assetPath = source.assetPath {
                dict["assetPath"] = assetPath
            }
        }

        return dict
    }

    private func convertPlayerOptionsToDict(_ options: VideoPlayerOptionsMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "autoPlay": options.autoPlay,
            "looping": options.looping,
            "volume": options.volume,
            "playbackSpeed": options.playbackSpeed,
            "allowBackgroundPlayback": options.allowBackgroundPlayback,
            "mixWithOthers": options.mixWithOthers,
            "allowPip": options.allowPip,
            "autoEnterPipOnBackground": options.autoEnterPipOnBackground
        ]
        // Add subtitle options if present
        if let mode = options.subtitleRenderMode {
            dict["subtitleRenderMode"] = convertSubtitleRenderModeToString(mode)
        }
        if let enabled = options.subtitlesEnabled {
            dict["subtitlesEnabled"] = enabled
        }
        if let showByDefault = options.showSubtitlesByDefault {
            dict["showSubtitlesByDefault"] = showByDefault
        }
        if let language = options.preferredSubtitleLanguage {
            dict["preferredSubtitleLanguage"] = language
        }
        return dict
    }

    private func convertSubtitleRenderModeToString(_ mode: SubtitleRenderModeEnum) -> String {
        switch mode {
        case .auto:
            return "auto"
        case .native:
            return "native"
        case .flutter:
            return "flutter"
        }
    }

    private func convertScalingModeToString(_ mode: VideoScalingModeEnum) -> String {
        switch mode {
        case .fit:
            return "fit"
        case .fill:
            return "fill"
        case .stretch:
            return "stretch"
        }
    }

    private func convertSubtitleFormatToString(_ format: SubtitleFormatEnum) -> String {
        switch format {
        case .srt:
            return "srt"
        case .vtt:
            return "vtt"
        case .ssa:
            return "ssa"
        case .ass:
            return "ass"
        case .ttml:
            return "ttml"
        }
    }

    private func convertStringToSubtitleFormat(_ string: String) -> SubtitleFormatEnum {
        switch string.lowercased() {
        case "srt":
            return .srt
        case "vtt":
            return .vtt
        case "ssa":
            return .ssa
        case "ass":
            return .ass
        case "ttml":
            return .ttml
        default:
            return .vtt
        }
    }

    private func convertPipActionTypeToString(_ type: PipActionTypeEnum) -> String {
        switch type {
        case .playPause:
            return "playPause"
        case .skipPrevious:
            return "skipPrevious"
        case .skipNext:
            return "skipNext"
        case .skipBackward:
            return "skipBackward"
        case .skipForward:
            return "skipForward"
        }
    }

    private func convertStringToCastState(_ string: String) -> CastStateEnum {
        switch string.lowercased() {
        case "connected":
            return .connected
        case "connecting":
            return .connecting
        case "disconnecting":
            return .disconnecting
        default:
            return .notConnected
        }
    }

    private func convertCastDeviceTypeToString(_ type: CastDeviceTypeEnum) -> String {
        switch type {
        case .airPlay:
            return "airplay"
        case .chromecast:
            return "chromecast"
        case .webRemotePlayback:
            return "webremoteplayback"
        case .unknown:
            return "unknown"
        }
    }

    private func convertStringToCastDeviceType(_ string: String) -> CastDeviceTypeEnum {
        switch string.lowercased() {
        case "airplay":
            return .airPlay
        case "chromecast":
            return .chromecast
        case "webremoteplayback":
            return .webRemotePlayback
        default:
            return .unknown
        }
    }
}
