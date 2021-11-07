import AVFoundation
import Combine
import os

public class VoicePlaybackModel: ObservableObject {
    private static let BUFFER_SIZE: UInt32 = 512

    enum PlaybackState {
        case started(StartedPlaybackState)
        case paused(PausedPlaybackState)
        case stopped(StoppedPlaybackState)
    }

    struct StartedPlaybackState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine
        let playerNode: AVAudioPlayerNode
        let file: AVAudioFile

        var playerFinishedCancellable: AnyCancellable?
        var fileStartTime: Float = 0
        var lastPlayerTime: Float = 0
    }

    struct PausedPlaybackState {
        let engine: AVAudioEngine
        let playerNode: AVAudioPlayerNode
        let file: AVAudioFile

        var seekTime: Float = 0
    }

    struct StoppedPlaybackState {
        var seekTime: Float = 0
    }

    @Published private var playbackState: PlaybackState = .stopped(StoppedPlaybackState())

    var currentTime: Float {
        get {
            switch playbackState {
            case .started(let state): return state.fileStartTime + state.lastPlayerTime
            case .paused(let state): return state.seekTime
            case .stopped(let state): return state.seekTime
            }
        }
        set(newTime) {
            seek(time: newTime)
        }
    }

    var isPlaying: Bool {
        get {
            switch playbackState {
            case .started(let state): return state.playerNode.isPlaying
            case .paused(_), .stopped(_): return false
            }
        }
    }

    public func togglePlayback(env: AppEnvironment, filename: String) throws {
        switch playbackState {
        case .started(_): pausePlayback(env: env)
        case .paused(_): try resumePlayback(env: env)
        case .stopped(_): try startPlayback(env: env, filename: filename)
        }
    }

    public func startPlayback(env: AppEnvironment, filename: String) throws {
        let state = stopPlaybackAndReturnState(env: env)

        os_log("starting playback for: \(filename)")

        let fileUrl = try AppFilesystem.appRecordingDirectory().appendingPathComponent(filename)
        let file = try AVAudioFile(forReading: fileUrl)

        let activity = AudioSession.Activity(category: .playback)
        env.audioSession.startActivity(activity)

        let playerNode = AVAudioPlayerNode()

        let engine = AVAudioEngine()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)

        playerNode.installTap(onBus: 0, bufferSize: Self.BUFFER_SIZE, format: nil) {
            [weak self] buffer, time in
            DispatchQueue.main.async {
                self?.updatePlayerTime(nodeTime: time)
            }
        }

        playbackState = .started(StartedPlaybackState(activity: activity, engine: engine, playerNode: playerNode, file: file))

        try engine.start()
        seek(time: state.seekTime)
    }

    public func pausePlayback(env: AppEnvironment) {
        guard case .started(let state) = playbackState else { return }

        os_log("pausing playback")

        state.playerNode.stop()
        state.engine.stop()
        env.audioSession.endActivity(state.activity)

        let pausedState = PausedPlaybackState(
            engine: state.engine,
            playerNode: state.playerNode,
            file: state.file,
            seekTime: state.fileStartTime + state.lastPlayerTime)
        playbackState = .paused(pausedState)
    }

    public func resumePlayback(env: AppEnvironment) throws {
        guard case .paused(let state) = playbackState else { return }

        os_log("resuming playback")

        let activity = AudioSession.Activity(category: .playback)
        env.audioSession.startActivity(activity)

        let startedState = StartedPlaybackState(activity: activity, engine: state.engine, playerNode: state.playerNode, file: state.file)
        playbackState = .started(startedState)

        try state.engine.start()
        seek(time: state.seekTime)
    }

    public func stopPlayback(env: AppEnvironment) {
        let _ = stopPlaybackAndReturnState(env: env)
    }

    private func stopPlaybackAndReturnState(env: AppEnvironment) -> StoppedPlaybackState {
        switch playbackState {
        case .started(let state):
            let stoppedState = StoppedPlaybackState()
            playbackState = .stopped(stoppedState)

            os_log("stopping playback from playing")

            state.playerNode.stop()
            state.engine.stop()
            env.audioSession.endActivity(state.activity)

            return stoppedState
        case .paused(_):
            let stoppedState = StoppedPlaybackState()
            playbackState = .stopped(stoppedState)

            os_log("stopping playback from paused")

            return stoppedState
        case .stopped(let stoppedState): return stoppedState
        }
    }

    private func finishPlayback() {
        guard case .started(let state) = playbackState else { return }

        playbackState = .stopped(StoppedPlaybackState())

        os_log("finishing playback")

        state.playerNode.stop()
        state.engine.stop()
    }

    private func updatePlayerTime(nodeTime: AVAudioTime) {
        guard case .started(let state) = playbackState else { return }

        let playerAVTime = state.playerNode.playerTime(forNodeTime: nodeTime)
        let playerTime = playerAVTime.flatMap { playerAVTime in
            Float(playerAVTime.sampleTime) / Float(playerAVTime.sampleRate)
        }
        if let playerTime = playerTime {
            var newState = state
            newState.lastPlayerTime = playerTime
            playbackState = .started(newState)
        }
    }

    private func seek(time: Float) {
        var state: StartedPlaybackState
        switch playbackState {
        case .started(let startedState): state = startedState
        case .paused(var state):
            state.seekTime = time
            playbackState = .paused(state)
            return
        case .stopped(var state):
            state.seekTime = time
            playbackState = .stopped(state)
            return
        }

        let startingFrame = AVAudioFramePosition(time * Float(state.file.processingFormat.sampleRate))
            .clamped(0...state.file.length)
        let frameCount = AVAudioFrameCount(state.file.length - startingFrame)

        if frameCount == 0 {
            playbackState = .stopped(StoppedPlaybackState())
            return
        }

        let playerFinishedSubject = PassthroughSubject<Void, Never>()
        state.playerFinishedCancellable = playerFinishedSubject
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] in
                self?.finishPlayback()
            }

        state.playerNode.stop()
        state.playerNode.scheduleSegment(
            state.file,
            startingFrame: startingFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataRendered
        ) { type in
            playerFinishedSubject.send()
        }
        state.playerNode.play()

        state.fileStartTime = time
        state.lastPlayerTime = 0
        playbackState = .started(state)
    }
}
