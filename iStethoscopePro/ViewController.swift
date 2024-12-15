import UIKit
import AudioKit
import AVFoundation

class ViewController: UIViewController {

    var audioEngine: AudioEngine!
    var microphone: AudioEngine.InputNode!
    var bandPassFilter: BandPassFilter!
    var dynamicsProcessor: DynamicsProcessor!
    var amplitudeTap: AmplitudeTap!
    var mixer: Mixer!
    var isEngineRunning = false // Track the audio engine state

    override func viewDidLoad() {
        super.viewDidLoad()
        audioEngine = AudioEngine()
        configureAudioSession()
        requestMicrophonePermission()
        
//        Settings.audioInputEnabled = true
//        Settings.channelCount = 1 // Mono
//        Settings.bufferLength = .medium // Adjust buffer length if needed

    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setMode(.default)
            try audioSession.setActive(true)
            print("Audio session configured successfully.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                self.handleMicrophonePermission(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                self.handleMicrophonePermission(granted)
            }
        }
    }

    func handleMicrophonePermission(_ granted: Bool) {
        DispatchQueue.main.async {
            if granted {
                print("Microphone access granted.")
            } else {
                let alert = UIAlertController(
                    title: "Microphone Access Denied",
                    message: "Please enable microphone access in Settings to use this feature.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @IBAction func listenTapped(_ sender: UIButton) {
        startListening()
    }

    func startListening() {
        guard !isEngineRunning else {
            print("Audio engine is already running.")
            return
        }

        do {
            guard let input = audioEngine.input else {
                print("Microphone not available.")
                return
            }
            microphone = input

            print("Microphone node active: \(microphone != nil)")

            // Setup the signal chain
            bandPassFilter = BandPassFilter(microphone)
            bandPassFilter.centerFrequency = 70
            bandPassFilter.bandwidth = 40

            dynamicsProcessor = DynamicsProcessor(bandPassFilter)
            dynamicsProcessor.threshold = -30
            dynamicsProcessor.headRoom = 5.0
            dynamicsProcessor.attackTime = 0.01
            dynamicsProcessor.releaseTime = 0.2

            // Attach amplitude tap AFTER the node is properly connected to the engine
            mixer = Mixer(dynamicsProcessor)
            audioEngine.output = mixer

            // Now add amplitude tap
            amplitudeTap = AmplitudeTap(dynamicsProcessor) { amplitude in
                DispatchQueue.main.async {
                    print("Debug - Amplitude value: \(amplitude)")
                    self.handleAmplitude(amplitude)
                }
            }
            amplitudeTap.start() // Start tap only after attaching

            // Start the audio engine
            try audioEngine.start()
            isEngineRunning = true
            print("Listening to heart sounds with output and amplitude tracking...")
        } catch {
            print("Failed to start AudioKit: \(error.localizedDescription)")
            isEngineRunning = false
        }
    }

    
    func handleAmplitude(_ amplitude: AUValue) {
        print("Amplitude: \(amplitude)")
    }

    @IBAction func stopTapped(_ sender: UIButton) {
        stopListening()
    }

    func stopListening() {
        guard isEngineRunning else {
            print("Audio engine is not running.")
            return
        }

        // Stop the amplitude tap if it exists
        if let tap = amplitudeTap {
            tap.stop()
            amplitudeTap = nil // Set to nil to avoid stopping it again
        }

        audioEngine.stop()
        isEngineRunning = false
        print("Stopped listening.")
    }
}
