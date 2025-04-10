import Foundation
import AVFoundation

class AudioService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    
    @Published var isRecording = false {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var isPlaying = false {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var volumeLevel: Float = 0.0 {
        didSet {
            objectWillChange.send()
        }
    }
    
    private var meterTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [ .allowBluetooth])
            try audioSession?.setActive(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() throws {
        guard let audioSession = audioSession else { return }
        
        // Request permission if needed
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                do {
                    try audioSession.setActive(true)
                    
                    let audioFilename = self.getDocumentsDirectory().appendingPathComponent("recording.m4a")
                    let settings = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    
                    self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                    self.audioRecorder?.isMeteringEnabled = true
                    self.audioRecorder?.record()
                    
                    // Start volume metering
                    self.meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                        self?.audioRecorder?.updateMeters()
                        let averagePower = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
                        // Convert decibels to a 0-1 range
                        let normalizedPower = (averagePower + 160.0) / 160.0
                        self?.volumeLevel = max(0.0, min(1.0, normalizedPower))
                    }
                    
                    DispatchQueue.main.async {
                        self.isRecording = true
                    }
                } catch {
                    print("Error starting recording: \(error.localizedDescription)")
                }
            } else {
                print("Microphone permission denied")
            }
        }
    }
    
    func stopRecording() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        volumeLevel = 0.0
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.isRecording = false
        }
        do {
            try audioSession?.setActive(false)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
        return audioRecorder?.url
    }
    
    func playAudio(data: Data) throws {
        stopCurrentPlayback()
        
        // Create a temporary file to store the audio data
        let tempFileURL = getDocumentsDirectory().appendingPathComponent("temp_audio.m4a")
        try data.write(to: tempFileURL)
        
        // Initialize audio engine and player node
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let audioPlayerNode = audioPlayerNode else {
            throw AppError.audioError("Failed to initialize audio engine")
        }
        
        // Create audio file from the temporary file
        audioFile = try AVAudioFile(forReading: tempFileURL)
        
        // Attach and connect the player node
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile?.processingFormat)
        
        // Schedule the file for playback
        audioPlayerNode.scheduleFile(audioFile!, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }
        
        // Start the engine
        try audioEngine.start()
        audioPlayerNode.play()
        isPlaying = true
        
        // Clean up the temporary file
        try? FileManager.default.removeItem(at: tempFileURL)
    }
    
    func playAudioStream(data: Data) throws {
        stopCurrentPlayback()
        
        // Initialize audio engine and player node if not already done
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let audioEngine = audioEngine,
                  let audioPlayerNode = audioPlayerNode else {
                throw AppError.audioError("Failed to initialize audio engine")
            }
            
            audioEngine.attach(audioPlayerNode)
            audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: nil)
        }
        
        // Convert the data to PCM buffer
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: 44100,
                                      channels: 1,
                                      interleaved: false)!
        
        let frameCount = UInt32(data.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
        audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        
        // Copy the data into the buffer
        let channelData = audioBuffer!.floatChannelData![0]
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let samples = ptr.bindMemory(to: Float.self)
            for i in 0..<Int(frameCount) {
                channelData[i] = samples[i]
            }
        }
        audioBuffer!.frameLength = frameCount
        
        // Schedule the buffer for playback
        audioPlayerNode?.scheduleBuffer(audioBuffer!) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }
        
        // Start the engine if not already running
        if !audioEngine!.isRunning {
            try audioEngine!.start()
        }
        
        audioPlayerNode?.play()
        isPlaying = true
    }
    
    private func stopCurrentPlayback() {
        audioPlayer?.stop()
        audioPlayerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
    }
    
    public func stopPlayback() {
        stopCurrentPlayback()
        do {
            try audioSession?.setActive(false)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            print("Audio player error: \(error.localizedDescription)")
        }
    }
} 
