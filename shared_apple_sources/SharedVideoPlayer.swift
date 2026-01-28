import AVFoundation
import AVKit
import Foundation
import MediaPlayer
import Network

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

// MARK: - Event Sink Protocol

/// Protocol for sending events to Flutter.
protocol EventSink: AnyObject {
    func send(_ event: [String: Any])
}

// MARK: - Shared Video Player

/// Shared video player implementation using AVPlayer.
/// This class contains all the common logic between iOS and macOS implementations.
/// Platform-specific behavior is delegated to the `PlatformAdapter` protocol.
class SharedVideoPlayer: NSObject {
    // MARK: - Properties

    let playerId: Int
    weak var eventSink: EventSink?
    weak var flutterApi: ProVideoPlayerFlutterApi?
    let platformAdapter: PlatformAdapter

    private(set) var player: AVPlayer?
    private(set) var playerItem: AVPlayerItem?
    private(set) var playerLayer: AVPlayerLayer?
    private var isLooping: Bool = false
    private var timeObserver: Any?
    private var kvoObserversAdded: Bool = false
    private var pipController: AVPictureInPictureController?
    private var isPipControllerReady: Bool = false
    private var pipActionsConfig: [[String: Any]]?

    // Configuration options
    private var allowPip: Bool = true
    private var autoEnterPipOnBackground: Bool = false
    private var subtitlesEnabled: Bool = true
    private var showSubtitlesByDefault: Bool = false
    private var preferredSubtitleLanguage: String?
    private(set) var playbackSpeed: Float = 1.0
    private var preventScreenSleep: Bool = true

    // Screen sleep prevention state
    private var isPlaying: Bool = false
    private var isPipActive: Bool = false
    private var isInBackground: Bool = false
    private var userRequestedPip: Bool = false  // Tracks if PiP was explicitly requested by user
    #if os(macOS)
    private var wakeLockActivity: NSObjectProtocol?
    #endif

    // Network resilience state
    private var isBufferingDueToNetwork: Bool = false
    private var wasPlayingBeforeStall: Bool = false
    private var networkRetryCount: Int = 0
    private var maxNetworkRetries: Int = 3
    private var retryTimer: Timer?
    private var lastBufferingReason: String = "unknown"

    // Network reachability monitoring
    private var networkMonitor: NWPathMonitor?
    private var networkMonitorQueue: DispatchQueue?

    // Performance optimization: track last sent values to avoid redundant events
    private var lastSentPosition: Int = -1
    private var lastSentBufferedPosition: Int = -1
    private var isNetworkAvailable: Bool = true
    private var hadNetworkError: Bool = false

    // Media metadata for lock screen / control center
    private var mediaMetadata: [String: String] = [:]
    private var artworkImage: PlatformImage?
    private var allowBackgroundPlayback: Bool = false

    // Video quality selection state
    private var isAutoQuality: Bool = true
    private var currentQualityTrackId: String = "auto"
    private var availableQualityTracks: [[String: Any]] = []

    // Bandwidth estimation
    private var lastSentBandwidth: Int = -1
    private var lastBandwidthUpdateTime: TimeInterval = 0
    private let bandwidthUpdateIntervalSeconds: TimeInterval = 3.0  // Throttle updates to every 3 seconds

    // External subtitles
    private var externalSubtitles: [String: [String: Any]] = [:]
    private var nextExternalSubtitleId: Int = 0
    private var selectedExternalSubtitleId: String?

    // Subtitle render mode
    // When "flutter" mode is active, native subtitle rendering is disabled
    // but we remember the selected track so it can be restored when switching back to "native"
    private var subtitleRenderMode: String = "native"  // "native", "flutter", or "auto"

    /// Effective render mode - "auto" defaults to "flutter"
    private var effectiveSubtitleRenderMode: String {
        return (subtitleRenderMode == "auto") ? "flutter" : subtitleRenderMode
    }

    private var selectedEmbeddedSubtitleIndex: Int?  // Remember selection when switching to flutter mode

    // Casting (AirPlay)
    private var allowCasting: Bool = true
    private var castState: String = "notConnected"
    private var currentCastDevice: [String: Any]?
    #if os(iOS)
    private var availableCastRoutes: [AVAudioSessionPortDescription] = []
    #endif

    // MARK: - Initialization

    init(playerId: Int, platformAdapter: PlatformAdapter, source: [String: Any], options: [String: Any]) {
        self.playerId = playerId
        self.platformAdapter = platformAdapter

        super.init()

        setupNetworkMonitor()
        setupPlayer(source: source, options: options)
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitorQueue = DispatchQueue(
            label: "\(platformAdapter.channelPrefix).network_monitor.\(playerId)")
        networkMonitor = NWPathMonitor()

        networkMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let wasAvailable = self.isNetworkAvailable
            self.isNetworkAvailable = path.status == .satisfied

            DispatchQueue.main.async {
                self.sendEvent(["type": "networkStateChanged", "isConnected": self.isNetworkAvailable])

                if !wasAvailable && self.isNetworkAvailable && self.hadNetworkError {
                    self.attemptNetworkRecovery()
                }
            }
        }

        networkMonitor?.start(queue: networkMonitorQueue!)
    }

    // MARK: - Player Setup

    private func setupPlayer(source: [String: Any], options: [String: Any]) {
        guard let type = source["type"] as? String else { return }

        // Store configuration options
        allowPip = options["allowPip"] as? Bool ?? true
        autoEnterPipOnBackground = options["autoEnterPipOnBackground"] as? Bool ?? false
        subtitlesEnabled = options["subtitlesEnabled"] as? Bool ?? true
        showSubtitlesByDefault = options["showSubtitlesByDefault"] as? Bool ?? false
        allowCasting = options["allowCasting"] as? Bool ?? true
        preventScreenSleep = options["preventScreenSleep"] as? Bool ?? true
        preferredSubtitleLanguage = options["preferredSubtitleLanguage"] as? String
        subtitleRenderMode = options["subtitleRenderMode"] as? String ?? "native"
        verboseLog("Initialized with subtitleRenderMode: \(subtitleRenderMode)", tag: "Subtitles")

        var url: URL?

        switch type {
        case "network":
            if let urlString = source["url"] as? String {
                url = URL(string: urlString)
            }
        case "file":
            if let path = source["path"] as? String {
                url = URL(fileURLWithPath: path)
            }
        case "asset":
            if let assetPath = source["assetPath"] as? String,
               let path = platformAdapter.lookupAssetPath(assetPath)
            {
                url = URL(fileURLWithPath: path)
            }
        default:
            break
        }

        guard let videoUrl = url else {
            sendError(message: "Invalid video source", code: "INVALID_SOURCE")
            return
        }

        // Configure audio session (platform-specific)
        allowBackgroundPlayback = options["allowBackgroundPlayback"] as? Bool ?? false
        let mixWithOthers = options["mixWithOthers"] as? Bool ?? false
        platformAdapter.configureAudioSession(
            allowPip: allowPip,
            allowBackgroundPlayback: allowBackgroundPlayback,
            mixWithOthers: mixWithOthers
        )

        // Setup remote command center for Bluetooth/external controls
        // This works even when background playback is disabled
        setupRemoteCommandCenter()

        // Perform heavy initialization on background thread to avoid blocking UI
        // AVPlayer, AVPlayerItem, and AVURLAsset can all be created off the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Create player item with headers if needed
            var asset: AVURLAsset
            if let headers = source["headers"] as? [String: String], !headers.isEmpty {
                asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                asset = AVURLAsset(url: videoUrl)
            }

            let playerItem = AVPlayerItem(asset: asset)

            // Configure buffering based on tier
            if let bufferingTier = options["bufferingTier"] as? String {
                playerItem.preferredForwardBufferDuration = self.bufferDurationForTier(bufferingTier)
            }

            // Configure ABR (Adaptive Bitrate) max bitrate constraint
            if let maxBitrate = options["maxBitrate"] as? Int, maxBitrate > 0 {
                playerItem.preferredPeakBitRate = Double(maxBitrate)
            }

            // Create AVPlayer WITHOUT the item first, so we can configure it before loading content
            let player = AVPlayer()

            // Disable automatic media selection when using Flutter subtitle rendering.
            // This MUST be set BEFORE assigning the playerItem, otherwise AVPlayer may
            // auto-select subtitles based on HLS DEFAULT=YES tracks or accessibility settings.
            if effectiveSubtitleRenderMode == "flutter" {
                player.appliesMediaSelectionCriteriaAutomatically = false
                verboseLog("Disabled automatic media selection BEFORE loading item (Flutter subtitle mode)", tag: "Subtitles")
            }

            // Now assign the playerItem - this starts the loading process
            player.replaceCurrentItem(with: playerItem)

            // Create the layer synchronously to ensure it's available when buildView() is called
            DispatchQueue.main.sync {
                self.playerLayer = AVPlayerLayer(player: player)
                self.player = player
                self.playerItem = playerItem
                self.playerLayer?.videoGravity = .resizeAspect
            }

            // Phase 2: Configure remaining options (can be async)
            DispatchQueue.main.async {


                    // Apply scaling mode if specified
                    if let scalingMode = options["scalingMode"] as? String {
                        self.applyScalingMode(scalingMode)
                    }

                    if let volume = options["volume"] as? Double {
                        self.player?.volume = Float(volume)
                    }

                    if let speed = options["playbackSpeed"] as? Double {
                        self.playbackSpeed = Float(speed)
                    }

                    self.isLooping = options["looping"] as? Bool ?? false

                    // Start playback if autoPlay is enabled, otherwise set rate to 0
                    let shouldAutoPlay = options["autoPlay"] as? Bool ?? false
                    if shouldAutoPlay {
                        self.player?.rate = self.playbackSpeed
                        self.isPlaying = true
                    } else {
                        self.player?.rate = 0
                    }

                    // Setup observers (critical for playback)
                    self.setupObservers()

                    // Setup casting (lightweight part)
                    self.setupCastingWithoutRouteCheck()

                    // Send playback state event (playing if autoPlay, ready otherwise)
                    let playbackState = shouldAutoPlay ? "playing" : "ready"
                    self.sendEvent(["type": "playbackStateChanged", "state": playbackState])

                    // Update screen sleep and now playing info if autoplaying
                    if shouldAutoPlay {
                        self.updateScreenSleepPrevention()
                        self.updateNowPlayingInfo()
                    }

            }

            // Phase 3: Slow AVAudioSession access (deferred to very end)
            DispatchQueue.main.async {
                self.updateAvailableRoutes()
            }
        }
    }

    /// Extracts and sends metadata from the current player item. Internal for testability.
    func extractAndSendMetadata() {
        guard let asset = playerItem?.asset else { return }

        var eventData: [String: Any] = ["type": "metadataChanged"]
        let metadata = asset.commonMetadata

        // Extract common metadata
        for item in metadata {
            guard let key = item.commonKey else { continue }

            switch key {
            case .commonKeyTitle:
                if let title = item.stringValue {
                    eventData["title"] = title
                }
            case .commonKeyArtist, .commonKeyCreator, .commonKeyAuthor:
                if eventData["artist"] == nil, let artist = item.stringValue {
                    eventData["artist"] = artist
                }
            case .commonKeyAlbumName:
                if let album = item.stringValue {
                    eventData["album"] = album
                }
            case .commonKeyCreationDate:
                if let dateString = item.stringValue {
                    // Try to extract year from date string (format varies)
                    if let year = extractYear(from: dateString) {
                        eventData["year"] = year
                    }
                }
            case .commonKeyType:
                if let genre = item.stringValue {
                    eventData["genre"] = genre
                }
            default:
                break
            }
        }

        // Only send if we have at least one metadata field beyond type
        if eventData.count > 1 {
            sendEvent(eventData)
        }
    }

    /// Extracts a 4-digit year from a date string.
    private func extractYear(from dateString: String) -> Int? {
        // Try common date formats
        let patterns = [
            "^(\\d{4})",           // Year at start: "2023", "2023-01-15"
            "(\\d{4})$",           // Year at end
            "(\\d{4})-\\d{2}-\\d{2}", // ISO format: "2023-01-15"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)),
               let range = Range(match.range(at: 1), in: dateString) {
                return Int(dateString[range])
            }
        }
        return nil
    }

    /// Gets technical video metadata extracted from the current video.
    /// Returns a dictionary with codec, resolution, bitrate, frame rate, and other details.
    func getVideoMetadata() -> [String: Any]? {
        guard let item = playerItem else { return nil }
        let asset = item.asset

        var metadata: [String: Any] = [:]

        // Duration
        let duration = CMTimeGetSeconds(item.duration)
        if duration.isFinite && duration > 0 {
            metadata["durationMs"] = Int(duration * 1000)
        }

        // Video track info
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            metadata["width"] = Int(abs(size.width))
            metadata["height"] = Int(abs(size.height))

            // Frame rate - check if loaded first
            var error: NSError?
            let frameRateStatus = videoTrack.statusOfValue(forKey: "nominalFrameRate", error: &error)
            if frameRateStatus == .loaded && videoTrack.nominalFrameRate > 0 {
                metadata["frameRate"] = Double(videoTrack.nominalFrameRate)
            }

            // Video bitrate (estimated data rate) - check if loaded first
            let bitrateStatus = videoTrack.statusOfValue(forKey: "estimatedDataRate", error: &error)
            if bitrateStatus == .loaded && videoTrack.estimatedDataRate > 0 {
                metadata["videoBitrate"] = Int(videoTrack.estimatedDataRate)
            }

            // Video codec from format descriptions
            if let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription],
               let formatDesc = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                metadata["videoCodec"] = codecFourCCToString(codecType)
            }
        }

        // Audio track info
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            // Audio bitrate - check if loaded first
            var error: NSError?
            let bitrateStatus = audioTrack.statusOfValue(forKey: "estimatedDataRate", error: &error)
            if bitrateStatus == .loaded && audioTrack.estimatedDataRate > 0 {
                metadata["audioBitrate"] = Int(audioTrack.estimatedDataRate)
            }

            // Audio codec from format descriptions
            if let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription],
               let formatDesc = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDesc)
                metadata["audioCodec"] = codecFourCCToString(codecType)

                // Audio sample rate and channels from format description
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                    if asbd.mSampleRate > 0 {
                        metadata["audioSampleRate"] = Int(asbd.mSampleRate)
                    }
                    if asbd.mChannelsPerFrame > 0 {
                        metadata["audioChannels"] = Int(asbd.mChannelsPerFrame)
                    }
                }
            }
        }

        // Container format and file size from URL if available
        if let urlAsset = asset as? AVURLAsset {
            let url = urlAsset.url
            let pathExtension = url.pathExtension.lowercased()
            if !pathExtension.isEmpty {
                metadata["containerFormat"] = pathExtension
            }

            // File size for local files
            if url.isFileURL {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    metadata["fileSize"] = size
                }
            }
        }

        return metadata.isEmpty ? nil : metadata
    }

    /// Converts a FourCC codec type to a human-readable string.
    private func codecFourCCToString(_ fourCC: FourCharCode) -> String {
        // Common video codecs
        switch fourCC {
        case kCMVideoCodecType_H264:
            return "h264"
        case kCMVideoCodecType_HEVC:
            return "hevc"
        case kCMVideoCodecType_MPEG4Video:
            return "mpeg4"
        case kCMVideoCodecType_JPEG:
            return "jpeg"
        case kCMVideoCodecType_AppleProRes422:
            return "prores422"
        case kCMVideoCodecType_AppleProRes4444:
            return "prores4444"
        default:
            break
        }

        // Common audio codecs
        switch fourCC {
        case kAudioFormatMPEG4AAC:
            return "aac"
        case kAudioFormatMPEGLayer3:
            return "mp3"
        case kAudioFormatLinearPCM:
            return "pcm"
        case kAudioFormatAppleLossless:
            return "alac"
        case kAudioFormatFLAC:
            return "flac"
        case kAudioFormatOpus:
            return "opus"
        case kAudioFormatAC3:
            return "ac3"
        case kAudioFormatEnhancedAC3:
            return "eac3"
        default:
            // Return the FourCC as a string
            let bytes = [
                UInt8((fourCC >> 24) & 0xFF),
                UInt8((fourCC >> 16) & 0xFF),
                UInt8((fourCC >> 8) & 0xFF),
                UInt8(fourCC & 0xFF)
            ]
            if let str = String(bytes: bytes, encoding: .ascii) {
                return str.trimmingCharacters(in: .whitespaces).lowercased()
            }
            return String(format: "0x%08X", fourCC)
        }
    }

    /// Extracts and sends technical video metadata as an event.
    /// Can be called from background thread - will dispatch sendEvent to main thread.
    func extractAndSendVideoMetadata() {
        guard let metadata = getVideoMetadata() else { return }
        DispatchQueue.main.async {
            self.sendEvent(["type": "videoMetadataExtracted", "metadata": metadata])
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: [.new], context: nil)
        kvoObserversAdded = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerItemFailedToPlayToEnd),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )

        // Add time observer for position updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self = self else { return }
            let position = Int(CMTimeGetSeconds(time) * 1000)
            // Only send if position changed by at least 100ms to reduce event overhead
            if abs(position - self.lastSentPosition) >= 100 {
                self.lastSentPosition = position
                self.sendEvent(["type": "positionChanged", "position": position])
            }

            // Check and send bandwidth estimate
            self.checkBandwidthEstimate()
        }

        // Observe app background/foreground state for auto-PiP and wake lock management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: platformAdapter.backgroundNotificationName,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: platformAdapter.foregroundNotificationName,
            object: nil
        )
    }

    // MARK: - KVO

    // swiftlint:disable:next block_based_kvo cyclomatic_complexity
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        switch keyPath {
        case "status":
            handleStatusChanged()
        case "loadedTimeRanges":
            handleLoadedTimeRangesChanged()
        case "playbackBufferEmpty":
            handlePlaybackBufferEmpty()
        case "playbackLikelyToKeepUp":
            handlePlaybackLikelyToKeepUp()
        case "playbackBufferFull":
            handlePlaybackBufferFull()
        default:
            break
        }
    }

    /// Handles player item status changes. Internal for testability.
    func handleStatusChanged() {
        guard let item = playerItem else { return }

        switch item.status {
        case .readyToPlay:
            let duration = Int(CMTimeGetSeconds(item.duration) * 1000)
            sendEvent(["type": "durationChanged", "duration": duration])

            // Notify Flutter of the initial background playback state from options
            sendEvent(["type": "backgroundPlaybackChanged", "isEnabled": allowBackgroundPlayback])

            // Defer video size and metadata extraction to avoid blocking
            // Use AVFoundation's async loading to avoid warnings
            if let track = item.asset.tracks(withMediaType: .video).first {
                track.loadValuesAsynchronously(forKeys: ["naturalSize", "preferredTransform"]) { [weak self] in
                    guard let self = self else { return }
                    var error: NSError?
                    let status = track.statusOfValue(forKey: "naturalSize", error: &error)

                    if status == .loaded {
                        let size = track.naturalSize.applying(track.preferredTransform)
                        DispatchQueue.main.async {
                            self.sendEvent([
                                "type": "videoSizeChanged",
                                "width": Int(abs(size.width)),
                                "height": Int(abs(size.height)),
                            ])
                        }
                    }
                }
            }

            // Load metadata properties asynchronously
            let asset = item.asset
            let videoTrack = asset.tracks(withMediaType: .video).first
            let audioTrack = asset.tracks(withMediaType: .audio).first

            // Use dispatch group to wait for both video and audio properties to load
            let metadataGroup = DispatchGroup()

            if let videoTrack = videoTrack {
                metadataGroup.enter()
                videoTrack.loadValuesAsynchronously(forKeys: ["nominalFrameRate", "estimatedDataRate", "naturalSize", "preferredTransform"]) {
                    metadataGroup.leave()
                }
            }

            if let audioTrack = audioTrack {
                metadataGroup.enter()
                audioTrack.loadValuesAsynchronously(forKeys: ["estimatedDataRate"]) {
                    metadataGroup.leave()
                }
            }

            // Extract metadata after both tracks are loaded (or immediately if no tracks)
            metadataGroup.notify(queue: DispatchQueue.global(qos: .utility)) { [weak self] in
                self?.extractAndSendVideoMetadata()
            }

            // For HLS/DASH streams, media selection groups (audio/subtitle tracks) load asynchronously
            // We need to wait for availableMediaCharacteristicsWithMediaSelectionOptions to be ready
            let subtitlesEnabledCopy = subtitlesEnabled
            verboseLog("Loading media selection options asynchronously...", tag: "Tracks")
            asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self] in
                guard let self = self else { return }
                var error: NSError?
                let status = asset.statusOfValue(forKey: "availableMediaCharacteristicsWithMediaSelectionOptions", error: &error)
                let characteristics = asset.availableMediaCharacteristicsWithMediaSelectionOptions
                verboseLog("Media selection loaded: status=\(status.rawValue), characteristics=\(characteristics), error=\(error?.localizedDescription ?? "none")", tag: "Tracks")
                DispatchQueue.main.async {
                    if subtitlesEnabledCopy {
                        self.notifySubtitleTracks()
                    }
                    self.notifyAudioTracks()
                }
            }
        case .failed:
            let errorMsg = item.error?.localizedDescription ?? "Unknown error"

            // Check if this is a network-related error
            if let error = item.error as NSError? {
                let networkErrorDomains = [NSURLErrorDomain, "NSPOSIXErrorDomain"]
                let networkErrorCodes = [
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorTimedOut,
                    NSURLErrorCannotConnectToHost,
                    NSURLErrorCannotFindHost,
                ]
                if networkErrorDomains.contains(error.domain) || networkErrorCodes.contains(error.code) {
                    hadNetworkError = true
                }
            }

            sendError(message: errorMsg, code: "PLAYBACK_ERROR")
        default:
            break
        }
    }

    // MARK: - Network Resilience Handlers

    func handlePlaybackBufferEmpty() {
        guard let item = playerItem, item.isPlaybackBufferEmpty else { return }

        if player?.rate ?? 0 > 0 {
            wasPlayingBeforeStall = true
        }

        if !isBufferingDueToNetwork {
            isBufferingDueToNetwork = true
            lastBufferingReason = "networkUnstable"
            sendEvent(["type": "bufferingStarted", "reason": lastBufferingReason])
            sendEvent(["type": "playbackStateChanged", "state": "buffering"])
        }
    }

    func handlePlaybackLikelyToKeepUp() {
        guard let item = playerItem, item.isPlaybackLikelyToKeepUp else { return }

        if isBufferingDueToNetwork {
            handleBufferingEnded()
        }
    }

    func handlePlaybackBufferFull() {
        if isBufferingDueToNetwork {
            handleBufferingEnded()
        }
    }

    @objc func handlePlaybackStalled() {
        if player?.rate ?? 0 > 0 {
            wasPlayingBeforeStall = true
        }

        if !isBufferingDueToNetwork {
            isBufferingDueToNetwork = true
            lastBufferingReason = "insufficientBandwidth"
            sendEvent(["type": "bufferingStarted", "reason": lastBufferingReason])
            sendEvent(["type": "playbackStateChanged", "state": "buffering"])
        }
    }

    @objc func handlePlayerItemFailedToPlayToEnd(notification: Notification) {
        let userInfo = notification.userInfo
        let error = userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        let message = error?.localizedDescription ?? "Playback failed"

        hadNetworkError = true

        sendEvent([
            "type": "networkError",
            "message": message,
            "willRetry": false,
            "retryAttempt": 0,
            "maxRetries": maxNetworkRetries,
        ])
    }

    func handleBufferingEnded() {
        guard isBufferingDueToNetwork else { return }

        isBufferingDueToNetwork = false
        hadNetworkError = false
        sendEvent(["type": "bufferingEnded"])

        if networkRetryCount > 0 {
            sendEvent(["type": "playbackRecovered", "retriesUsed": networkRetryCount])
            networkRetryCount = 0
        }

        if wasPlayingBeforeStall {
            wasPlayingBeforeStall = false
            player?.rate = playbackSpeed
            sendEvent(["type": "playbackStateChanged", "state": "playing"])
        } else {
            sendEvent(["type": "playbackStateChanged", "state": "paused"])
        }
    }

    func scheduleNetworkRetry() {
        retryTimer?.invalidate()

        let delay = min(pow(2.0, Double(networkRetryCount)), 30.0)
        networkRetryCount += 1

        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptNetworkRecovery()
        }
    }

    func attemptNetworkRecovery() {
        guard let player = player, playerItem != nil else { return }

        hadNetworkError = false

        let currentTime = player.currentTime()
        player.seek(to: currentTime) { [weak self] finished in
            if finished {
                self?.player?.rate = self?.playbackSpeed ?? 1.0
            }
        }
    }

    /// Checks the current bandwidth estimate from AVPlayer's access log and sends an event if changed significantly.
    /// Bandwidth updates are throttled to reduce event frequency.
    private func checkBandwidthEstimate() {
        guard let item = playerItem, let accessLog = item.accessLog() else { return }

        let currentTime = ProcessInfo.processInfo.systemUptime

        // Throttle updates to avoid flooding events
        if currentTime - lastBandwidthUpdateTime < bandwidthUpdateIntervalSeconds {
            return
        }

        // Get the most recent access log event
        guard let lastEvent = accessLog.events.last else { return }

        // AVPlayerItemAccessLogEvent provides observedBitrate (bits per second)
        // This represents the actual throughput during segment downloads
        let bandwidth = Int(lastEvent.observedBitrate)
        if bandwidth <= 0 { return }

        // Only send if bandwidth changed by at least 10% (avoid noise)
        let threshold = Double(lastSentBandwidth) * 0.1
        if lastSentBandwidth > 0 && abs(Double(bandwidth - lastSentBandwidth)) < threshold {
            return
        }

        lastSentBandwidth = bandwidth
        lastBandwidthUpdateTime = currentTime
        sendEvent([
            "type": "bandwidthEstimateChanged",
            "bandwidth": bandwidth,
        ])
    }

    func handleLoadedTimeRangesChanged() {
        guard let item = playerItem,
              let timeRanges = item.loadedTimeRanges as? [CMTimeRange],
              !timeRanges.isEmpty
        else { return }

        let bufferedEnd = timeRanges.reduce(CMTime.zero) { maxTime, range in
            let rangeEnd = CMTimeAdd(range.start, range.duration)
            return CMTimeCompare(rangeEnd, maxTime) > 0 ? rangeEnd : maxTime
        }

        let bufferedPosition = Int(CMTimeGetSeconds(bufferedEnd) * 1000)
        // Only send if buffered position increased (deduplication)
        if bufferedPosition > lastSentBufferedPosition {
            lastSentBufferedPosition = bufferedPosition
            sendEvent(["type": "bufferedPositionChanged", "bufferedPosition": bufferedPosition])
        }
    }

    // MARK: - Track Handling

    func notifySubtitleTracks() {
        guard let asset = playerItem?.asset else {
            verboseLog("notifySubtitleTracks: no asset", tag: "Tracks")
            return
        }

        let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        verboseLog("notifySubtitleTracks: legible group = \(group != nil ? "found" : "nil"), options count = \(group?.options.count ?? 0)", tag: "Tracks")
        guard let options = group?.options else { return }

        var tracks: [[String: Any]] = []
        for (index, option) in options.enumerated() {
            let language = extractLanguageCode(from: option)
            let label = option.displayName.isEmpty ? (language ?? "Track \(index + 1)") : option.displayName
            let track: [String: Any] = [
                "id": "0:\(index)",
                "label": label,
                "language": language as Any,
                "isDefault": index == 0,
            ]
            tracks.append(track)
        }

        if !tracks.isEmpty, let group = group {
            verboseLog("Sending subtitleTracksChanged event with \(tracks.count) tracks", tag: "Tracks")
            sendEvent(["type": "subtitleTracksChanged", "tracks": tracks])

            // Check if we're in Flutter mode - need to ensure native subtitles are disabled
            if effectiveSubtitleRenderMode == "flutter" {
                // Always deselect native subtitles in Flutter mode
                // AVPlayer may auto-enable subtitles based on accessibility settings or HLS defaults
                playerItem?.select(nil, in: group)
                verboseLog("Deselected native subtitles (Flutter mode)", tag: "Subtitles")
            }

            if showSubtitlesByDefault {
                autoSelectSubtitle(options: options, group: group)
            }
        }
    }

    func notifyAudioTracks() {
        guard let asset = playerItem?.asset else {
            verboseLog("notifyAudioTracks: no asset", tag: "Tracks")
            return
        }

        let group = asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        verboseLog("notifyAudioTracks: audible group = \(group != nil ? "found" : "nil"), options count = \(group?.options.count ?? 0)", tag: "Tracks")
        guard let options = group?.options else { return }

        var tracks: [[String: Any]] = []
        for (index, option) in options.enumerated() {
            let language = extractLanguageCode(from: option)
            let label = option.displayName.isEmpty ? (language ?? "Track \(index + 1)") : option.displayName
            let track: [String: Any] = [
                "id": "0:\(index)",
                "label": label,
                "language": language as Any,
                "isDefault": index == 0,
            ]
            tracks.append(track)
        }

        if !tracks.isEmpty {
            verboseLog("Sending audioTracksChanged event with \(tracks.count) tracks", tag: "Tracks")
            sendEvent(["type": "audioTracksChanged", "tracks": tracks])
        }
    }

    private func extractLanguageCode(from option: AVMediaSelectionOption) -> String? {
        if let identifier = option.locale?.identifier, !identifier.isEmpty {
            return identifier.components(separatedBy: "_").first
        }
        return option.locale?.languageCode
    }

    func autoSelectSubtitle(options: [AVMediaSelectionOption], group: AVMediaSelectionGroup) {
        var selectedOption: AVMediaSelectionOption?

        if let preferredLanguage = preferredSubtitleLanguage {
            selectedOption = options.first { $0.locale?.languageCode == preferredLanguage }
        }

        selectedOption = selectedOption ?? options.first

        if let option = selectedOption, let index = options.firstIndex(of: option) {
            // Remember the selected index
            selectedEmbeddedSubtitleIndex = index

            // Build track data for the event
            let language = extractLanguageCode(from: option)
            let label = option.displayName.isEmpty ? (language ?? "Track \(index + 1)") : option.displayName
            let trackData: [String: Any] = [
                "id": "0:\(index)",
                "label": label,
                "language": language as Any,
                "isDefault": index == 0,
            ]

            // Check subtitle render mode - only enable native rendering if not in flutter mode
            if effectiveSubtitleRenderMode == "flutter" {
                // In flutter mode, actively deselect native subtitle rendering
                // Just not selecting isn't enough - AVPlayer may have default selection
                playerItem?.select(nil, in: group)
                verboseLog("Auto-selected subtitle in flutter mode (native rendering disabled): \(option.displayName)", tag: "Subtitles")
            } else {
                // In native mode, actually select the track for native rendering
                playerItem?.select(option, in: group)
                verboseLog("Auto-selected subtitle in native mode: \(option.displayName)", tag: "Subtitles")
            }

            // Always send the event so Dart knows which track is selected
            sendEvent(["type": "selectedSubtitleChanged", "track": trackData])
        }
    }

    // MARK: - Notification Handlers

    @objc func handlePlayerDidFinishPlaying() {
        if isLooping {
            player?.seek(to: .zero)
            player?.play()
        } else {
            sendEvent(["type": "playbackStateChanged", "state": "completed"])
            sendEvent(["type": "playbackCompleted"])
        }
    }

    @objc func handleAppDidEnterBackground() {
        isInBackground = true
        updateScreenSleepPrevention()

        // Determine what should happen when app goes to background:
        // 1. If autoEnterPipOnBackground is enabled -> enter PiP (video continues in floating window)
        // 2. If allowBackgroundPlayback is enabled but not auto-PiP -> audio continues (no PiP)
        // 3. If neither is enabled -> pause playback

        if autoEnterPipOnBackground && allowPip {
            // User wants PiP when backgrounding
            _ = enterPip()
        } else if allowBackgroundPlayback {
            // Background audio-only mode: disconnect video layer so AVPlayer only outputs audio.
            // On iOS, if the video layer is still connected when backgrounding, iOS may pause
            // the player because the video rendering surface is not visible.
            // By disconnecting the layer, audio continues in background.
            #if os(iOS)
            playerLayer?.player = nil
            #endif
        } else {
            // Background playback is disabled - pause the video
            // This prevents iOS from trying to preserve playback via PiP
            if isPlaying {
                player?.pause()
                // Note: We don't update isPlaying or send events here because
                // playback will resume automatically when app returns to foreground
            }
        }
    }

    @objc func handleAppWillEnterForeground() {
        isInBackground = false
        updateScreenSleepPrevention()

        // Reconnect video layer if it was disconnected for background audio-only mode
        #if os(iOS)
        if allowBackgroundPlayback && playerLayer?.player == nil {
            playerLayer?.player = player
        }
        #endif

        // If playback was paused due to backgrounding (not user-initiated pause),
        // and the video was playing before, resume playback.
        // We check isPlaying because we didn't update it when auto-pausing on background.
        if isPlaying && !allowBackgroundPlayback && (player?.rate ?? 0) == 0 {
            player?.rate = playbackSpeed
        }
    }

    // MARK: - Public Methods

    func getPlayerLayer() -> AVPlayerLayer? {
        return playerLayer
    }

    func getAVPlayer() -> AVPlayer? {
        return player
    }

    func onPlayerLayerAttachedToView() {
        platformAdapter.onPlayerLayerAttached(playerLayer: playerLayer)
        // Only create PiP controller automatically if user wants auto-PiP on background.
        // For manual-only PiP, the controller will be created lazily in enterPip().
        // This prevents iOS from auto-triggering PiP when we only want background audio.
        if autoEnterPipOnBackground {
            setupPipController()
        }
    }

    func onPlayerViewControllerAttached(_ controller: Any) {
        platformAdapter.onPlayerViewControllerAttached(controller, allowPip: allowPip)
    }

    func setupPipController() {
        guard allowPip,
              let playerLayer = playerLayer,
              !isPipControllerReady
        else { return }

        if platformAdapter.isPipSupported() {
            pipController = platformAdapter.createPipController(playerLayer: playerLayer)
            pipController?.delegate = self

            // Configure automatic PiP behavior when app goes to background.
            // This is the iOS system-level auto-PiP, distinct from our manual enterPip() call.
            // Must match autoEnterPipOnBackground to prevent iOS from starting PiP
            // when user only wants background audio playback.
            // Note: This property is iOS-only (not available on macOS).
            #if os(iOS)
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = autoEnterPipOnBackground
            }
            #endif

            isPipControllerReady = true
        }
    }

    func play() {
        player?.rate = playbackSpeed
        isPlaying = true
        sendEvent(["type": "playbackStateChanged", "state": "playing"])
        updateNowPlayingInfo()
        updateScreenSleepPrevention()
    }

    func pause() {
        player?.rate = 0
        isPlaying = false
        sendEvent(["type": "playbackStateChanged", "state": "paused"])
        updateNowPlayingInfo()
        updateScreenSleepPrevention()
    }

    func stop() {
        player?.rate = 0
        player?.seek(to: .zero)
        isPlaying = false
        sendEvent(["type": "playbackStateChanged", "state": "ready"])
        updateNowPlayingInfo()
        updateScreenSleepPrevention()
    }

    // MARK: - Screen Sleep Prevention

    /// Updates screen sleep prevention based on current playback state.
    ///
    /// Wake lock is enabled when:
    /// - Video is playing AND
    /// - (NOT in background OR in PiP mode)
    ///
    /// Wake lock is disabled when:
    /// - Video is paused OR
    /// - In background AND NOT in PiP
    private func updateScreenSleepPrevention() {
        guard preventScreenSleep else { return }

        // Keep wake lock if playing and (not in background OR in PiP)
        let shouldKeepAwake = isPlaying && (!isInBackground || isPipActive)

        if shouldKeepAwake {
            enableScreenSleepPrevention()
        } else {
            disableScreenSleepPrevention()
        }
    }

    private func enableScreenSleepPrevention() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #elseif os(macOS)
        if wakeLockActivity == nil {
            wakeLockActivity = ProcessInfo.processInfo.beginActivity(
                options: .idleDisplaySleepDisabled,
                reason: "Video playback in progress"
            )
        }
        #endif
    }

    private func disableScreenSleepPrevention() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #elseif os(macOS)
        if let activity = wakeLockActivity {
            ProcessInfo.processInfo.endActivity(activity)
            wakeLockActivity = nil
        }
        #endif
    }

    func seekTo(milliseconds: Int) {
        // Reset last sent position to ensure new position is sent after seek
        lastSentPosition = -1
        let time = CMTime(
            seconds: Double(milliseconds) / 1000.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
        sendEvent(["type": "playbackSpeedChanged", "speed": Double(speed)])
    }

    func setVolume(_ volume: Float) {
        player?.volume = volume
        sendEvent(["type": "volumeChanged", "volume": Double(volume)])
    }

    func setLooping(_ looping: Bool) {
        isLooping = looping
    }

    func setScalingMode(_ mode: String) {
        applyScalingMode(mode)
    }

    private func applyScalingMode(_ mode: String) {
        switch mode {
        case "fit":
            playerLayer?.videoGravity = .resizeAspect
        case "fill":
            playerLayer?.videoGravity = .resizeAspectFill
        case "stretch":
            playerLayer?.videoGravity = .resize
        default:
            playerLayer?.videoGravity = .resizeAspect
        }
    }

    func setSubtitleTrack(_ track: [String: Any]?) {
        guard subtitlesEnabled else { return }

        // Check if native rendering is enabled
        let nativeRenderingEnabled = (effectiveSubtitleRenderMode == "native")

        if let trackData = track, let idString = trackData["id"] as? String {
            // Check if this is an external subtitle track
            if idString.hasPrefix("ext-") {
                // Verify the external track exists
                guard externalSubtitles[idString] != nil else {
                    verboseLog("External subtitle track not found: \(idString)", tag: "Subtitles")
                    return
                }

                // Deselect any embedded subtitle (always, regardless of render mode)
                selectedEmbeddedSubtitleIndex = nil
                if let asset = playerItem?.asset,
                   let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
                {
                    playerItem?.select(nil, in: group)
                }

                // Select the external subtitle
                selectedExternalSubtitleId = idString
                sendEvent(["type": "selectedSubtitleChanged", "track": trackData])
                return
            }

            // Handle embedded subtitle track (format: "0:index")
            guard let asset = playerItem?.asset,
                  let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
            else {
                return
            }

            let parts = idString.split(separator: ":")
            guard parts.count == 2, let trackIndex = Int(parts[1]) else {
                return
            }

            let options = group.options
            if trackIndex < options.count {
                // Clear external subtitle selection when selecting embedded
                selectedExternalSubtitleId = nil
                // Remember the selected embedded subtitle index
                selectedEmbeddedSubtitleIndex = trackIndex

                // Only enable native rendering if not in Flutter mode
                if nativeRenderingEnabled {
                    playerItem?.select(options[trackIndex], in: group)
                } else {
                    // In Flutter mode, deselect native subtitle but remember the selection
                    playerItem?.select(nil, in: group)
                    verboseLog("Embedded subtitle \(trackIndex) selected but native rendering disabled (Flutter mode)", tag: "Subtitles")
                }
                sendEvent(["type": "selectedSubtitleChanged", "track": track as Any])
            }
        } else {
            // Disable all subtitles
            selectedExternalSubtitleId = nil
            selectedEmbeddedSubtitleIndex = nil
            if let asset = playerItem?.asset,
               let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
            {
                playerItem?.select(nil, in: group)
            }
            sendEvent(["type": "selectedSubtitleChanged", "track": NSNull()])
        }
    }

    /// Sets the subtitle render mode.
    ///
    /// - Parameter mode: "native", "flutter", or "auto"
    ///   - "native": Subtitles are rendered by the native player (AVPlayer)
    ///   - "flutter": Subtitles are rendered by Flutter's SubtitleOverlay widget
    ///   - "auto": Same as "flutter" (default)
    ///
    /// When switching to "flutter" mode, native subtitle rendering is disabled
    /// but the selected track is remembered. When switching back to "native",
    /// the previously selected track is restored.
    func setSubtitleRenderMode(_ mode: String) {
        let previousMode = subtitleRenderMode
        subtitleRenderMode = mode

        verboseLog("setSubtitleRenderMode: \(previousMode) -> \(mode)", tag: "Subtitles")

        guard let asset = playerItem?.asset,
              let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else {
            return
        }

        let effectiveMode = (mode == "auto") ? "flutter" : mode

        if effectiveMode == "flutter" {
            // Switching to Flutter mode: disable native subtitle rendering
            // Disable automatic media selection to prevent AVPlayer from re-enabling subtitles
            player?.appliesMediaSelectionCriteriaAutomatically = false

            // Remember the currently selected embedded subtitle so we can restore it later
            if let currentSelection = playerItem?.currentMediaSelection.selectedMediaOption(in: group),
               let index = group.options.firstIndex(of: currentSelection)
            {
                selectedEmbeddedSubtitleIndex = index
            }
            // Deselect native subtitles (but keep the track selection in Dart state)
            playerItem?.select(nil, in: group)
            verboseLog("Native subtitle rendering disabled for Flutter mode", tag: "Subtitles")
        } else {
            // Switching to Native mode: restore native subtitle rendering
            // Re-enable automatic media selection
            player?.appliesMediaSelectionCriteriaAutomatically = true

            if let savedIndex = selectedEmbeddedSubtitleIndex, savedIndex < group.options.count {
                playerItem?.select(group.options[savedIndex], in: group)
                verboseLog("Restored native subtitle: index \(savedIndex)", tag: "Subtitles")
            }
        }
    }

    func setAudioTrack(_ track: [String: Any]?) {
        guard let asset = playerItem?.asset,
              let group = asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else {
            return
        }

        if let trackData = track, let idString = trackData["id"] as? String {
            let parts = idString.split(separator: ":")
            guard parts.count == 2, let trackIndex = Int(parts[1]) else {
                return
            }

            let options = group.options
            if trackIndex < options.count {
                playerItem?.select(options[trackIndex], in: group)
                sendEvent(["type": "selectedAudioChanged", "track": track as Any])
            }
        } else {
            if let defaultOption = group.defaultOption {
                playerItem?.select(defaultOption, in: group)
            }
            sendEvent(["type": "selectedAudioChanged", "track": NSNull()])
        }
    }

    // MARK: - External Subtitles

    /// Adds an external subtitle track from a URL.
    ///
    /// The subtitle file is downloaded and validated. The track is stored and
    /// can be selected using `setSubtitleTrack()` with its ID.
    ///
    /// - Parameters:
    ///   - sourceType: The type of subtitle source ("network", "file", "asset").
    ///   - path: The path to the subtitle (URL, file path, or asset path).
    ///   - format: The subtitle format (srt, vtt, ssa, ass, ttml). Auto-detected if nil.
    ///   - label: Display label for the track.
    ///   - language: ISO 639-1 language code (e.g., "en", "es").
    ///   - isDefault: Whether this should be the default subtitle track.
    ///   - completion: Callback with the track dictionary if successful, nil otherwise.
    func addExternalSubtitle(
        sourceType: String,
        path: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard subtitlesEnabled else {
            completion(nil)
            return
        }

        switch sourceType {
        case "network":
            loadNetworkSubtitle(
                url: path,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        case "file":
            loadFileSubtitle(
                filePath: path,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        case "asset":
            loadAssetSubtitle(
                assetPath: path,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        default:
            verboseLog("Unknown subtitle source type: \(sourceType)", tag: "Subtitles")
            completion(nil)
        }
    }

    /// Loads a subtitle from a network URL.
    private func loadNetworkSubtitle(
        url: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard let subtitleUrl = URL(string: url) else {
            verboseLog("Invalid subtitle URL: \(url)", tag: "Subtitles")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: subtitleUrl) { [weak self] data, _, error in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            if let error = error {
                verboseLog("Failed to download subtitle: \(error.localizedDescription)", tag: "Subtitles")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data, !data.isEmpty else {
                verboseLog("Empty subtitle data from URL: \(url)", tag: "Subtitles")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard String(data: data, encoding: .utf8) != nil else {
                verboseLog("Invalid subtitle encoding from URL: \(url)", tag: "Subtitles")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.createSubtitleTrack(
                sourceType: "network",
                path: url,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        }.resume()
    }

    /// Loads a subtitle from a local file path.
    private func loadFileSubtitle(
        filePath: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            verboseLog("Subtitle file not found: \(filePath)", tag: "Subtitles")
            completion(nil)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)

            guard !data.isEmpty else {
                verboseLog("Empty subtitle file: \(filePath)", tag: "Subtitles")
                completion(nil)
                return
            }

            guard String(data: data, encoding: .utf8) != nil else {
                verboseLog("Invalid subtitle encoding in file: \(filePath)", tag: "Subtitles")
                completion(nil)
                return
            }

            createSubtitleTrack(
                sourceType: "file",
                path: filePath,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        } catch {
            verboseLog("Failed to read subtitle file: \(error.localizedDescription)", tag: "Subtitles")
            completion(nil)
        }
    }

    /// Loads a subtitle from a Flutter asset.
    private func loadAssetSubtitle(
        assetPath: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard let resolvedPath = platformAdapter.lookupAssetPath(assetPath) else {
            verboseLog("Asset not found: \(assetPath)", tag: "Subtitles")
            completion(nil)
            return
        }

        let fileURL = URL(fileURLWithPath: resolvedPath)

        do {
            let data = try Data(contentsOf: fileURL)

            guard !data.isEmpty else {
                verboseLog("Empty subtitle asset: \(assetPath)", tag: "Subtitles")
                completion(nil)
                return
            }

            guard String(data: data, encoding: .utf8) != nil else {
                verboseLog("Invalid subtitle encoding in asset: \(assetPath)", tag: "Subtitles")
                completion(nil)
                return
            }

            createSubtitleTrack(
                sourceType: "asset",
                path: assetPath,
                format: format,
                label: label,
                language: language,
                isDefault: isDefault,
                completion: completion
            )
        } catch {
            verboseLog("Failed to read subtitle asset: \(error.localizedDescription)", tag: "Subtitles")
            completion(nil)
        }
    }

    /// Creates and registers a subtitle track after validation.
    private func createSubtitleTrack(
        sourceType: String,
        path: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        let trackId = "ext-\(nextExternalSubtitleId)"
        nextExternalSubtitleId += 1

        let track: [String: Any] = [
            "id": trackId,
            "sourceType": sourceType,
            "path": path,
            "format": format ?? detectSubtitleFormat(from: path),
            "label": label ?? "External",
            "language": language as Any,
            "isDefault": isDefault,
        ]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            self.externalSubtitles[trackId] = track

            self.notifySubtitleTracksWithExternal()
            completion(track)
        }
    }

    /// Removes an external subtitle track.
    ///
    /// - Parameter trackId: The ID of the external subtitle track to remove.
    /// - Returns: `true` if the track was removed, `false` if not found.
    func removeExternalSubtitle(trackId: String) -> Bool {
        guard externalSubtitles.removeValue(forKey: trackId) != nil else {
            verboseLog("External subtitle track not found: \(trackId)", tag: "Subtitles")
            return false
        }


        // Notify about the change
        notifySubtitleTracksWithExternal()

        return true
    }

    /// Gets all external subtitle tracks.
    ///
    /// - Returns: Array of external subtitle track dictionaries.
    func getExternalSubtitles() -> [[String: Any]] {
        return Array(externalSubtitles.values)
    }

    /// Detects the subtitle format from the URL extension.
    private func detectSubtitleFormat(from url: String) -> String {
        let lowercased = url.lowercased()
        if lowercased.hasSuffix(".srt") { return "srt" }
        if lowercased.hasSuffix(".vtt") { return "vtt" }
        if lowercased.hasSuffix(".ssa") { return "ssa" }
        if lowercased.hasSuffix(".ass") { return "ass" }
        if lowercased.hasSuffix(".ttml") || lowercased.hasSuffix(".xml") { return "ttml" }
        return "srt"  // Default to SRT
    }

    /// Notifies about available subtitle tracks including external ones.
    private func notifySubtitleTracksWithExternal() {
        var allTracks: [[String: Any]] = []

        // Add embedded tracks from the asset
        if let asset = playerItem?.asset,
           let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        {
            let options = group.options
            for (index, option) in options.enumerated() {
                let language = option.locale?.languageCode
                let displayName = option.displayName
                let track: [String: Any] = [
                    "id": "0:\(index)",
                    "label": displayName,
                    "language": language as Any,
                    "isDefault": index == 0,
                ]
                allTracks.append(track)
            }
        }

        // Add external tracks
        for track in externalSubtitles.values {
            allTracks.append(track)
        }

        sendEvent([
            "type": "subtitleTracksChanged",
            "tracks": allTracks,
        ])
    }

    func getPosition() -> Int {
        guard let time = player?.currentTime() else { return 0 }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return 0 }
        return Int(seconds * 1000)
    }

    func getDuration() -> Int {
        guard let duration = playerItem?.duration else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite else { return 0 }
        return Int(seconds * 1000)
    }

    func enterPip() -> Bool {
        guard allowPip else { return false }

        if !isPipControllerReady {
            setupPipController()
        }

        guard let controller = pipController else { return false }

        // Mark that PiP was explicitly requested (by user or by autoEnterPipOnBackground)
        userRequestedPip = true
        controller.startPictureInPicture()
        return true
    }

    func exitPip() {
        pipController?.stopPictureInPicture()
    }

    /// Sets PiP action configuration.
    ///
    /// On iOS, PiP controls are system-managed. Starting with iOS 15,
    /// we can enable skip forward/backward buttons via the `canSkip*` delegates.
    /// Play/pause is always handled by the system.
    func setPipActions(_ actions: [[String: Any]]?) {
        // Store actions for potential delegate callbacks
        pipActionsConfig = actions

        // On iOS 15+/macOS 11.0+, we can configure skip button availability
        // by implementing the AVPictureInPictureControllerDelegate
        // methods `skipByInterval` and setting `requiresLinearPlayback`
        if #available(iOS 15.0, macOS 11.0, *) {
            guard let controller = pipController else { return }

            // Determine if skip actions are configured
            let hasSkipForward = actions?.contains { ($0["type"] as? String) == "skipForward" || ($0["type"] as? String) == "skipNext" } ?? false
            let hasSkipBackward = actions?.contains { ($0["type"] as? String) == "skipBackward" || ($0["type"] as? String) == "skipPrevious" } ?? false

            // When skip actions are present, enable the skip buttons
            // requiresLinearPlayback = false allows skip buttons to appear
            controller.requiresLinearPlayback = !(hasSkipForward || hasSkipBackward)
        }
    }

    func enterFullscreen() -> Bool {
        return platformAdapter.enterFullscreen(player: player, playerLayer: playerLayer)
    }

    func exitFullscreen() {
        platformAdapter.exitFullscreen()
    }

    func isPipAllowed() -> Bool {
        return allowPip
    }

    func areSubtitlesEnabled() -> Bool {
        return subtitlesEnabled
    }

    // MARK: - Test Helper Methods (for triggering delegate behavior in tests)

    /// Simulates PiP starting - triggers the same event as the delegate callback
    func handlePipDidStart() {
        sendEvent(["type": "pipStateChanged", "isActive": true])
    }

    /// Simulates PiP stopping - triggers the same event as the delegate callback
    func handlePipDidStop() {
        sendEvent(["type": "pipStateChanged", "isActive": false])
    }

    // MARK: - Video Quality Selection

    /// Gets available video quality tracks.
    /// For AVPlayer with HLS, quality options are determined by the stream's available variants.
    func getVideoQualities() -> [[String: Any]] {
        guard let item = playerItem else { return [] }

        // Check if we have cached quality tracks
        if !availableQualityTracks.isEmpty {
            return availableQualityTracks
        }

        // For HLS streams, try to get available variants from access log
        var qualityTracks: [[String: Any]] = []
        var trackIndex = 0

        if let accessLog = item.accessLog() {
            // Group unique qualities by bitrate
            // Note: AVPlayerItemAccessLogEvent doesn't expose video resolution directly,
            // so we use bitrate as the primary identifier for quality variants.
            var uniqueBitrates: Set<Int> = []

            for event in accessLog.events {
                let bitrate = Int(event.indicatedBitrate)

                // Only add if we have valid and unique bitrate
                if bitrate > 0 && !uniqueBitrates.contains(bitrate) {
                    uniqueBitrates.insert(bitrate)
                    let track: [String: Any] = [
                        "id": "0:\(trackIndex)",
                        "bitrate": bitrate,
                        "width": 0,  // Resolution not available from access log
                        "height": 0,
                        "label": "",
                        "isDefault": trackIndex == 0,
                    ]
                    qualityTracks.append(track)
                    trackIndex += 1
                }
            }
        }

        // If no quality information is available, return empty (auto only)
        // Note: AVPlayer doesn't expose HLS variant info directly - this is a limitation
        // For full quality selection, the app would need to parse the HLS manifest
        availableQualityTracks = qualityTracks
        return qualityTracks
    }

    /// Sets the video quality track.
    /// For AVPlayer, we use preferredMaximumResolution to limit quality.
    func setVideoQuality(_ track: [String: Any]?) -> Bool {
        guard player != nil, let item = playerItem else { return false }

        // Check if auto quality is requested
        let trackId = track?["id"] as? String
        if trackId == nil || trackId == "auto" {
            // Enable automatic quality selection by removing resolution limit
            isAutoQuality = true
            currentQualityTrackId = "auto"
            item.preferredMaximumResolution = .zero
            item.preferredPeakBitRate = 0

            sendEvent(["type": "selectedQualityChanged",
                       "track": [
                           "id": "auto",
                           "bitrate": 0,
                           "width": 0,
                           "height": 0,
                           "label": "Auto",
                       ] as [String: Any],
                       "isAutoSwitch": false])
            return true
        }

        // Get width/height/bitrate from track
        let width = track?["width"] as? Int ?? 0
        let height = track?["height"] as? Int ?? 0
        let bitrate = track?["bitrate"] as? Int ?? 0

        // Set preferred resolution and bitrate to force specific quality
        if width > 0 && height > 0 {
            item.preferredMaximumResolution = CGSize(width: width, height: height)
        }
        if bitrate > 0 {
            item.preferredPeakBitRate = Double(bitrate)
        }

        isAutoQuality = false
        currentQualityTrackId = trackId ?? "auto"

        sendEvent([
            "type": "selectedQualityChanged",
            "track": track as Any,
            "isAutoSwitch": false,
        ])
        return true
    }

    /// Gets the currently selected video quality track.
    func getCurrentVideoQuality() -> [String: Any] {
        if isAutoQuality {
            return [
                "id": "auto",
                "bitrate": 0,
                "width": 0,
                "height": 0,
                "label": "Auto",
            ]
        }

        // Return the last set track ID or find from available tracks
        for track in availableQualityTracks {
            if let id = track["id"] as? String, id == currentQualityTrackId {
                return track
            }
        }

        return [
            "id": "auto",
            "bitrate": 0,
            "width": 0,
            "height": 0,
            "label": "Auto",
        ]
    }

    /// Returns whether manual quality selection is supported for current content.
    /// Note: AVPlayer doesn't expose HLS variant info directly, so this is limited.
    func isQualitySelectionSupported() -> Bool {
        // For now, return false as AVPlayer doesn't expose quality options reliably
        // Quality selection works by limiting max resolution, but we can't enumerate options
        return false
    }

    // MARK: - Background Playback

    /// Sets whether background playback is enabled at runtime.
    ///
    /// When enabled, audio continues playing when the app is backgrounded.
    /// This requires proper platform configuration (UIBackgroundModes for iOS).
    ///
    /// Returns true if background playback was successfully enabled/disabled.
    func setBackgroundPlayback(_ enabled: Bool) -> Bool {
        // Check if platform supports background playback configuration
        let success = platformAdapter.setBackgroundPlayback(enabled)
        if success {
            allowBackgroundPlayback = enabled

            // Remote controls remain active regardless of background playback setting.
            // This allows Bluetooth controls to work during foreground playback.
            // Only the audio session category changes based on this setting.
            updateNowPlayingInfo()

            sendEvent(["type": "backgroundPlaybackChanged", "isEnabled": enabled])
        }
        return success
    }

    /// Returns the current background playback enabled state.
    func isBackgroundPlaybackEnabled() -> Bool {
        return allowBackgroundPlayback
    }

    func bufferDurationForTier(_ tier: String) -> TimeInterval {
        switch tier.lowercased() {
        case "min":
            return 2.0
        case "low":
            return 5.0
        case "medium":
            return 0.0
        case "high":
            return 30.0
        case "max":
            return 60.0
        default:
            return 0.0
        }
    }

    // MARK: - Media Metadata & Remote Commands

    /// Sets the media metadata for lock screen and control center display.
    func setMediaMetadata(_ metadata: [String: Any]) {
        guard allowBackgroundPlayback else { return }

        mediaMetadata = [:]
        if let title = metadata["title"] as? String {
            mediaMetadata["title"] = title
        }
        if let artist = metadata["artist"] as? String {
            mediaMetadata["artist"] = artist
        }
        if let album = metadata["album"] as? String {
            mediaMetadata["album"] = album
        }

        // Load artwork if URL is provided
        if let artworkUrl = metadata["artworkUrl"] as? String, let url = URL(string: artworkUrl) {
            loadArtwork(from: url)
        } else {
            artworkImage = nil
            updateNowPlayingInfo()
        }
    }

    private func loadArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else {
                DispatchQueue.main.async {
                    self?.artworkImage = nil
                    self?.updateNowPlayingInfo()
                }
                return
            }

            #if os(iOS)
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    self.artworkImage = nil
                    self.updateNowPlayingInfo()
                }
                return
            }
            #elseif os(macOS)
            guard let image = NSImage(data: data) else {
                DispatchQueue.main.async {
                    self.artworkImage = nil
                    self.updateNowPlayingInfo()
                }
                return
            }
            #endif

            DispatchQueue.main.async {
                self.artworkImage = image
                self.updateNowPlayingInfo()
            }
        }.resume()
    }

    /// Updates the Now Playing info center with current metadata and playback state.
    ///
    /// This works even when background playback is disabled, allowing Bluetooth
    /// controls to function during foreground playback.
    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        // Set metadata
        if let title = mediaMetadata["title"] {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        if let artist = mediaMetadata["artist"] {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        if let album = mediaMetadata["album"] {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }

        // Set artwork
        if let image = artworkImage {
            #if os(iOS)
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            #elseif os(macOS)
            // macOS uses NSImage for MPMediaItemArtwork
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            #endif
        }

        // Set playback info
        let duration = Double(getDuration()) / 1000.0
        let position = Double(getPosition()) / 1000.0

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.player?.rate ?? 0 > 0 {
                self.pause()
            } else {
                self.play()
            }
            return .success
        }

        // Skip forward command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent
            else { return .commandFailed }

            let currentPosition = self.getPosition()
            let newPosition = currentPosition + Int(skipEvent.interval * 1000)
            self.seekTo(milliseconds: min(newPosition, self.getDuration()))
            return .success
        }

        // Skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent
            else { return .commandFailed }

            let currentPosition = self.getPosition()
            let newPosition = currentPosition - Int(skipEvent.interval * 1000)
            self.seekTo(milliseconds: max(newPosition, 0))
            return .success
        }

        // Seek command (for scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }

            self.seekTo(milliseconds: Int(positionEvent.positionTime * 1000))
            return .success
        }

        // Stop command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
    }

    private func teardownRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Casting (AirPlay)

    /// Sets up casting without checking routes (to avoid blocking on AVAudioSession access)
    private func setupCastingWithoutRouteCheck() {
        guard allowCasting, let player = player else { return }

        // Enable external playback (AirPlay)
        player.allowsExternalPlayback = true

        #if os(iOS)
        player.usesExternalPlaybackWhileExternalScreenIsActive = false

        // Observe route changes (iOS only - AVAudioSession is not available on macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif

        // Don't call updateAvailableRoutes() here - it accesses AVAudioSession which blocks
        // Caller should defer that call
    }

    private func setupCasting() {
        setupCastingWithoutRouteCheck()
        updateAvailableRoutes()
    }

    #if os(iOS)
    @objc private func audioRouteChanged(notification: Notification) {
        updateAvailableRoutes()
        updateCastState()
    }
    #endif

    private func updateAvailableRoutes() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        availableCastRoutes = session.currentRoute.outputs.filter { output in
            output.portType == .airPlay || output.portType == .bluetoothA2DP
        }

        // Send devices changed event
        let devices = availableCastRoutes.map { route -> [String: Any] in
            return [
                "id": route.uid,
                "name": route.portName,
                "type": "airPlay"
            ]
        }
        sendEvent(["type": "castDevicesChanged", "devices": devices])
        #elseif os(macOS)
        // macOS: AirPlay routes are available through AVPlayer's externalPlaybackType
        // We'll report based on current playback state
        if let player = player, player.isExternalPlaybackActive {
            let devices: [[String: Any]] = [[
                "id": "airplay",
                "name": "AirPlay",
                "type": "airPlay"
            ]]
            sendEvent(["type": "castDevicesChanged", "devices": devices])
        } else {
            sendEvent(["type": "castDevicesChanged", "devices": []])
        }
        #endif
    }

    private func updateCastState() {
        guard let player = player else { return }

        let wasConnected = (castState == "connected")
        let isNowConnected = player.isExternalPlaybackActive

        if isNowConnected && !wasConnected {
            castState = "connected"
            #if os(iOS)
            if let route = AVAudioSession.sharedInstance().currentRoute.outputs.first(where: { $0.portType == .airPlay }) {
                currentCastDevice = [
                    "id": route.uid,
                    "name": route.portName,
                    "type": "airPlay"
                ]
            }
            #elseif os(macOS)
            currentCastDevice = [
                "id": "airplay",
                "name": "AirPlay",
                "type": "airPlay"
            ]
            #endif
            sendEvent([
                "type": "castStateChanged",
                "state": "connected",
                "device": currentCastDevice as Any
            ])
        } else if !isNowConnected && wasConnected {
            castState = "notConnected"
            currentCastDevice = nil
            sendEvent([
                "type": "castStateChanged",
                "state": "notConnected"
            ])
        }
    }

    func isCastingSupported() -> Bool {
        // AirPlay is always supported on iOS/macOS
        return true
    }

    func getAvailableCastDevices() -> [[String: Any]] {
        guard allowCasting else { return [] }

        #if os(iOS)
        return availableCastRoutes.map { route in
            return [
                "id": route.uid,
                "name": route.portName,
                "type": "airPlay"
            ]
        }
        #elseif os(macOS)
        // macOS: Report based on external playback availability
        if player?.isExternalPlaybackActive == true {
            return [[
                "id": "airplay",
                "name": "AirPlay",
                "type": "airPlay"
            ]]
        }
        return []
        #endif
    }

    func startCasting(device: [String: Any]) -> Bool {
        guard allowCasting, let player = player else { return false }

        // On iOS/macOS, AirPlay route selection is handled by the system UI (AVRoutePickerView)
        // We can't programmatically select a route, but we can enable external playback
        player.allowsExternalPlayback = true

        // The actual connection happens when user selects a device from the system picker
        // For now, we return true to indicate the feature is available
        return true
    }

    func stopCasting() {
        guard let player = player else { return }

        #if os(iOS)
        // Disable external playback to disconnect (iOS only)
        player.usesExternalPlaybackWhileExternalScreenIsActive = false

        // Re-enable for future use
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self != nil else { return }
            player.usesExternalPlaybackWhileExternalScreenIsActive = false
        }
        #elseif os(macOS)
        // On macOS, simply disable external playback
        player.allowsExternalPlayback = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self != nil else { return }
            player.allowsExternalPlayback = true
        }
        #endif

        updateCastState()
    }

    func getCastState() -> String {
        return castState
    }

    func getCurrentCastDevice() -> [String: Any]? {
        return currentCastDevice
    }

    // MARK: - Event Sending

    func sendEvent(_ event: [String: Any]) {
        guard let eventType = event["type"] as? String else {
            // No type - send to EventChannel as fallback
            sendToEventChannel(event)
            return
        }

        // Route events based on frequency
        switch eventType {
        // High-frequency events → EventChannel (proven, low overhead)
        case "positionChanged", "bufferedPositionChanged",
             "playbackStateChanged", "durationChanged",
             "videoSizeChanged", "bufferingStarted", "bufferingEnded",
             "volumeChanged", "playbackSpeedChanged", "selectedSubtitleChanged",
             "selectedAudioChanged", "bufferingReasonChanged", "bandwidthEstimate",
             "networkStateChanged", "metadataChanged", "backgroundPlaybackChanged",
             "playbackRecovered", "networkReconnected":
            sendToEventChannel(event)

        // Low-frequency events → FlutterApi (type safety)
        case "error":
            if let flutterApi = flutterApi {
                let code = event["code"] as? String ?? "UNKNOWN"
                let message = event["message"] as? String ?? ""
                flutterApi.onError(
                    playerId: Int64(playerId),
                    errorCode: code,
                    errorMessage: message
                ) { _ in }
            } else {
                // Fallback to EventChannel if FlutterApi not available
                sendToEventChannel(event)
            }

        case "videoMetadataExtracted":
            if let flutterApi = flutterApi, let metadataDict = event["metadata"] as? [String: Any] {
                let metadata = VideoMetadataMessage(
                    duration: metadataDict["duration"] as? Int64,
                    width: metadataDict["width"] as? Int64,
                    height: metadataDict["height"] as? Int64,
                    videoCodec: metadataDict["videoCodec"] as? String,
                    audioCodec: metadataDict["audioCodec"] as? String,
                    bitrate: metadataDict["bitrate"] as? Int64,
                    frameRate: metadataDict["frameRate"] as? Double
                )
                flutterApi.onMetadataExtracted(
                    playerId: Int64(playerId),
                    metadata: metadata
                ) { _ in }
            } else {
                sendToEventChannel(event)
            }

        case "playbackCompleted":
            if let flutterApi = flutterApi {
                flutterApi.onPlaybackCompleted(playerId: Int64(playerId)) { _ in }
            } else {
                sendToEventChannel(event)
            }

        case "pipActionTriggered":
            if let flutterApi = flutterApi, let action = event["action"] as? String {
                flutterApi.onPipActionTriggered(
                    playerId: Int64(playerId),
                    action: action
                ) { _ in }
            } else {
                sendToEventChannel(event)
            }

        case "castStateChanged":
            if let flutterApi = flutterApi {
                let stateString = event["state"] as? String ?? "notConnected"
                let state: CastStateEnum = {
                    switch stateString {
                    case "connecting": return .connecting
                    case "connected": return .connected
                    case "disconnecting": return .disconnecting
                    default: return .notConnected
                    }
                }()

                var device: CastDeviceMessage? = nil
                if let deviceDict = event["device"] as? [String: Any] {
                    let deviceType: CastDeviceTypeEnum = {
                        switch deviceDict["type"] as? String {
                        case "airPlay": return .airPlay
                        case "chromecast": return .chromecast
                        case "webRemotePlayback": return .webRemotePlayback
                        default: return .unknown
                        }
                    }()
                    device = CastDeviceMessage(
                        id: deviceDict["id"] as? String ?? "",
                        name: deviceDict["name"] as? String ?? "",
                        type: deviceType
                    )
                }

                flutterApi.onCastStateChanged(
                    playerId: Int64(playerId),
                    state: state,
                    device: device
                ) { _ in }
            } else {
                sendToEventChannel(event)
            }

        case "subtitleTracksChanged":
            verboseLog("subtitleTracksChanged: flutterApi=\(flutterApi != nil ? "set" : "nil")", tag: "Tracks")
            if let flutterApi = flutterApi, let tracksArray = event["tracks"] as? [[String: Any]] {
                let tracks: [SubtitleTrackMessage?] = tracksArray.map { trackDict in
                    guard let id = trackDict["id"] as? String else { return nil }
                    let format: SubtitleFormatEnum? = {
                        guard let formatStr = trackDict["format"] as? String else { return nil }
                        switch formatStr.lowercased() {
                        case "srt": return .srt
                        case "vtt", "webvtt": return .vtt
                        case "ssa": return .ssa
                        case "ass": return .ass
                        case "ttml": return .ttml
                        default: return nil
                        }
                    }()
                    return SubtitleTrackMessage(
                        id: id,
                        label: trackDict["label"] as? String,
                        language: trackDict["language"] as? String,
                        format: format,
                        isDefault: trackDict["isDefault"] as? Bool
                    )
                }
                flutterApi.onSubtitleTracksChanged(
                    playerId: Int64(playerId),
                    tracks: tracks
                ) { _ in }
            } else {
                sendToEventChannel(event)
            }

        case "audioTracksChanged":
            verboseLog("audioTracksChanged: flutterApi=\(flutterApi != nil ? "set" : "nil")", tag: "Tracks")
            if let flutterApi = flutterApi, let tracksArray = event["tracks"] as? [[String: Any]] {
                let tracks: [AudioTrackMessage?] = tracksArray.map { trackDict in
                    guard let id = trackDict["id"] as? String else { return nil }
                    return AudioTrackMessage(
                        id: id,
                        label: trackDict["label"] as? String,
                        language: trackDict["language"] as? String,
                        channelCount: trackDict["channelCount"] as? Int64,
                        isDefault: trackDict["isDefault"] as? Bool
                    )
                }
                flutterApi.onAudioTracksChanged(
                    playerId: Int64(playerId),
                    tracks: tracks
                ) { _ in }
            } else {
                sendToEventChannel(event)
            }

        default:
            // Unknown event type - send to EventChannel as fallback
            sendToEventChannel(event)
        }
    }

    private func sendToEventChannel(_ event: [String: Any]) {
        // Optimize: avoid async dispatch overhead when already on main thread
        if Thread.isMainThread {
            eventSink?.send(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.eventSink?.send(event)
            }
        }
    }

    func sendError(message: String, code: String) {
        sendEvent(["type": "error", "message": message, "code": code])
    }

    // MARK: - Cleanup

    func dispose() {
        retryTimer?.invalidate()
        retryTimer = nil

        networkMonitor?.cancel()
        networkMonitor = nil

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Safe KVO observer removal - only remove if we added them
        if kvoObserversAdded {
            playerItem?.removeObserver(self, forKeyPath: "status")
            playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
            playerItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem?.removeObserver(self, forKeyPath: "playbackBufferFull")
            kvoObserversAdded = false
        }
        NotificationCenter.default.removeObserver(self)

        // Cleanup remote command center
        if allowBackgroundPlayback {
            teardownRemoteCommandCenter()
        }

        // Cleanup screen sleep prevention
        disableScreenSleepPrevention()

        player?.pause()
        player = nil
        playerItem = nil
        playerLayer = nil

        pipController?.delegate = nil
        pipController = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension SharedVideoPlayer: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        // Check if PiP was explicitly requested or if it was auto-triggered by iOS
        // If auto-triggered and we don't want auto-PiP, exit immediately
        if !userRequestedPip && !autoEnterPipOnBackground {
            // Exit PiP immediately - we don't want auto-PiP
            exitPip()
            return
        }

        isPipActive = true
        sendEvent(["type": "pipStateChanged", "isActive": true])
        updateScreenSleepPrevention()
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        isPipActive = false
        userRequestedPip = false  // Reset the flag when PiP stops
        sendEvent(["type": "pipStateChanged", "isActive": false])
        updateScreenSleepPrevention()
    }

    /// Called when the user taps the "expand" button in PiP to return to the app.
    ///
    /// This method allows the app to restore its user interface before PiP stops.
    /// The Flutter layer should listen for `pipRestoreUserInterface` events and
    /// restore the video player view as needed.
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // Notify Flutter that user interface restoration is requested
        sendEvent(["type": "pipRestoreUserInterface"])

        // Allow a small delay for Flutter to process the event and restore UI
        // before completing the transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completionHandler(true)
        }
    }

    /// Called when the user taps skip forward in PiP (iOS 15+).
    @available(iOS 15.0, *)
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completionHandler: @escaping () -> Void
    ) {
        // Determine skip direction based on interval sign
        let seconds = CMTimeGetSeconds(skipInterval)
        if seconds > 0 {
            // Skip forward
            if let action = pipActionsConfig?.first(where: { ($0["type"] as? String) == "skipForward" }) {
                let intervalMs = (action["skipIntervalMs"] as? Int) ?? 10000
                let currentTime = player?.currentTime() ?? .zero
                let newTime = CMTimeAdd(currentTime, CMTimeMakeWithSeconds(Double(intervalMs) / 1000, preferredTimescale: currentTime.timescale))
                player?.seek(to: newTime)
                sendEvent(["type": "pipActionTriggered", "action": "skipForward"])
            } else {
                // Default: skipNext for playlist navigation
                sendEvent(["type": "pipActionTriggered", "action": "skipNext"])
            }
        } else {
            // Skip backward
            if let action = pipActionsConfig?.first(where: { ($0["type"] as? String) == "skipBackward" }) {
                let intervalMs = (action["skipIntervalMs"] as? Int) ?? 10000
                let currentTime = player?.currentTime() ?? .zero
                let newTime = CMTimeSubtract(currentTime, CMTimeMakeWithSeconds(Double(intervalMs) / 1000, preferredTimescale: currentTime.timescale))
                let clampedTime = CMTimeMaximum(newTime, .zero)
                player?.seek(to: clampedTime)
                sendEvent(["type": "pipActionTriggered", "action": "skipBackward"])
            } else {
                // Default: skipPrevious for playlist navigation
                sendEvent(["type": "pipActionTriggered", "action": "skipPrevious"])
            }
        }

        completionHandler()
    }
}
