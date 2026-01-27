import AVFoundation
import AVKit
import Foundation

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif

/// Shared video player wrapper that handles all common Flutter bridging logic.
/// This eliminates duplication between iOS and macOS VideoPlayer classes.
open class SharedVideoPlayerWrapper: NSObject {
    let playerId: Int
    let registrar: Any
    let eventChannel: FlutterEventChannel
    var eventSink: FlutterEventSink?
    
    let sharedPlayer: SharedVideoPlayer
    let platformAdapter: PlatformAdapter
    
    public init(
        playerId: Int,
        registrar: Any,
        eventChannelName: String,
        binaryMessenger: Any,
        platformAdapter: PlatformAdapter,
        source: [String: Any],
        options: [String: Any]
    ) {
        self.playerId = playerId
        self.registrar = registrar

        #if os(iOS)
        self.eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: binaryMessenger as! FlutterBinaryMessenger
        )
        #elseif os(macOS)
        self.eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: binaryMessenger as! FlutterBinaryMessenger
        )
        #endif

        self.platformAdapter = platformAdapter
        self.sharedPlayer = SharedVideoPlayer(
            playerId: playerId,
            platformAdapter: platformAdapter,
            source: source,
            options: options
        )

        super.init()

        eventChannel.setStreamHandler(self)
        sharedPlayer.eventSink = self
    }
    
    // MARK: - Public API (delegates to SharedVideoPlayer)
    
    public func getPlayerLayer() -> AVPlayerLayer? {
        return sharedPlayer.getPlayerLayer()
    }
    
    public func getAVPlayer() -> AVPlayer? {
        return sharedPlayer.getAVPlayer()
    }
    
    public func onPlayerLayerAttachedToView() {
        sharedPlayer.onPlayerLayerAttachedToView()
    }
    
    #if os(iOS)
    public func onPlayerViewControllerAttached(_ playerVC: AVPlayerViewController) {
        sharedPlayer.onPlayerViewControllerAttached(playerVC)
    }
    #elseif os(macOS)
    public func onPlayerViewControllerAttached(_ playerView: AVPlayerView) {
        sharedPlayer.onPlayerViewControllerAttached(playerView)
    }
    #endif
    
    public func play() {
        sharedPlayer.play()
    }
    
    public func pause() {
        sharedPlayer.pause()
    }
    
    public func stop() {
        sharedPlayer.stop()
    }
    
    public func seekTo(milliseconds: Int) {
        sharedPlayer.seekTo(milliseconds: milliseconds)
    }
    
    public func setPlaybackSpeed(_ speed: Float) {
        sharedPlayer.setPlaybackSpeed(speed)
    }
    
    public func setVolume(_ volume: Float) {
        sharedPlayer.setVolume(volume)
    }
    
    public func setLooping(_ looping: Bool) {
        sharedPlayer.setLooping(looping)
    }
    
    public func setScalingMode(_ mode: String) {
        sharedPlayer.setScalingMode(mode)
    }
    
    public func setSubtitleTrack(_ track: [String: Any]?) {
        sharedPlayer.setSubtitleTrack(track)
    }
    
    public func setAudioTrack(_ track: [String: Any]?) {
        sharedPlayer.setAudioTrack(track)
    }

    public func setSubtitleRenderMode(_ mode: String) {
        sharedPlayer.setSubtitleRenderMode(mode)
    }

    // MARK: - External Subtitles

    public func addExternalSubtitle(
        sourceType: String,
        path: String,
        format: String?,
        label: String?,
        language: String?,
        isDefault: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        sharedPlayer.addExternalSubtitle(
            sourceType: sourceType,
            path: path,
            format: format,
            label: label,
            language: language,
            isDefault: isDefault,
            completion: completion
        )
    }

    public func removeExternalSubtitle(trackId: String) -> Bool {
        return sharedPlayer.removeExternalSubtitle(trackId: trackId)
    }

    public func getExternalSubtitles() -> [[String: Any]] {
        return sharedPlayer.getExternalSubtitles()
    }

    public func getPosition() -> Int {
        return sharedPlayer.getPosition()
    }
    
    public func getDuration() -> Int {
        return sharedPlayer.getDuration()
    }
    
    public func enterPip() -> Bool {
        return sharedPlayer.enterPip()
    }
    
    public func exitPip() {
        sharedPlayer.exitPip()
    }
    
    #if os(iOS)
    public func setPipActions(_ actions: [[String: Any]]?) {
        sharedPlayer.setPipActions(actions)
    }
    #endif
    
    public func enterFullscreen() -> Bool {
        return sharedPlayer.enterFullscreen()
    }
    
    public func exitFullscreen() {
        sharedPlayer.exitFullscreen()
    }
    
    public func setMediaMetadata(_ metadata: [String: Any]) {
        sharedPlayer.setMediaMetadata(metadata)
    }
    
    public func getVideoQualities() -> [[String: Any]] {
        return sharedPlayer.getVideoQualities()
    }
    
    public func setVideoQuality(_ quality: [String: Any]?) -> Bool {
        return sharedPlayer.setVideoQuality(quality)
    }
    
    public func getCurrentVideoQuality() -> [String: Any]? {
        return sharedPlayer.getCurrentVideoQuality()
    }
    
    public func isQualitySelectionSupported() -> Bool {
        return sharedPlayer.isQualitySelectionSupported()
    }
    
    public func setBackgroundPlayback(_ enabled: Bool) -> Bool {
        return sharedPlayer.setBackgroundPlayback(enabled)
    }

    public func getVideoMetadata() -> [String: Any]? {
        return sharedPlayer.getVideoMetadata()
    }

    // MARK: - State Query Methods

    public func isPipAllowed() -> Bool {
        return sharedPlayer.isPipAllowed()
    }

    public func areSubtitlesEnabled() -> Bool {
        return sharedPlayer.areSubtitlesEnabled()
    }

    public func isBackgroundPlaybackEnabled() -> Bool {
        return sharedPlayer.isBackgroundPlaybackEnabled()
    }

    // MARK: - Internal Methods (exposed for testing)

    public func handlePlayerDidFinishPlaying() {
        sharedPlayer.handlePlayerDidFinishPlaying()
    }

    public func handleAppDidEnterBackground() {
        sharedPlayer.handleAppDidEnterBackground()
    }

    public func handleAppWillEnterForeground() {
        sharedPlayer.handleAppWillEnterForeground()
    }

    public func handlePipDidStart() {
        sharedPlayer.handlePipDidStart()
    }

    public func handlePipDidStop() {
        sharedPlayer.handlePipDidStop()
    }

    public func notifySubtitleTracks() {
        sharedPlayer.notifySubtitleTracks()
    }

    public func notifyAudioTracks() {
        sharedPlayer.notifyAudioTracks()
    }

    public func sendEvent(_ event: [String: Any]) {
        sharedPlayer.sendEvent(event)
    }

    public func sendError(code: String, message: String) {
        sharedPlayer.sendError(message: message, code: code)
    }

    public func setupPipController() {
        sharedPlayer.setupPipController()
    }

    public func handlePlaybackBufferEmpty() {
        sharedPlayer.handlePlaybackBufferEmpty()
    }

    public func handlePlaybackLikelyToKeepUp() {
        sharedPlayer.handlePlaybackLikelyToKeepUp()
    }

    public func handlePlaybackBufferFull() {
        sharedPlayer.handlePlaybackBufferFull()
    }

    public func handlePlaybackStalled() {
        sharedPlayer.handlePlaybackStalled()
    }

    public func handleBufferingEnded() {
        sharedPlayer.handleBufferingEnded()
    }

    public func scheduleNetworkRetry() {
        sharedPlayer.scheduleNetworkRetry()
    }

    public func attemptNetworkRecovery() {
        sharedPlayer.attemptNetworkRecovery()
    }

    // MARK: - Casting

    public func isCastingSupported() -> Bool {
        return sharedPlayer.isCastingSupported()
    }

    public func getAvailableCastDevices() -> [[String: Any]] {
        return sharedPlayer.getAvailableCastDevices()
    }

    public func startCasting(device: [String: Any]) -> Bool {
        return sharedPlayer.startCasting(device: device)
    }

    public func stopCasting() {
        sharedPlayer.stopCasting()
    }

    public func getCastState() -> String {
        return sharedPlayer.getCastState()
    }

    public func getCurrentCastDevice() -> [String: Any]? {
        return sharedPlayer.getCurrentCastDevice()
    }

    public func dispose() {
        sharedPlayer.dispose()
        eventChannel.setStreamHandler(nil)
        eventSink = nil
    }
}

// MARK: - FlutterStreamHandler
extension SharedVideoPlayerWrapper: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - EventSink
extension SharedVideoPlayerWrapper: EventSink {
    public func send(_ event: [String: Any]) {
        eventSink?(event)
    }
}
