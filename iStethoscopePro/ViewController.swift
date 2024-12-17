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
            try audioSession.overrideOutputAudioPort(.speaker) // Ensure speaker output
            try audioSession.setActive(true)
            print("Audio session configured for speaker output.")
        } catch {
            print("Failed to configure audio session for speaker: \(error.localizedDescription)")
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

            // High-pass filter to remove low-frequency noise
            let highPassFilter = HighPassFilter(microphone)
            highPassFilter.cutoffFrequency = 20  // Remove low-frequency noise

            // Band-pass filter to isolate heartbeat frequencies
            bandPassFilter = BandPassFilter(highPassFilter)
            bandPassFilter.centerFrequency = 80
            bandPassFilter.bandwidth = 50

            // Low-pass filter to remove higher frequencies
            let lowPassFilter = LowPassFilter(bandPassFilter)
            lowPassFilter.cutoffFrequency = 150

            // Dynamics processor to enhance the signal
            dynamicsProcessor = DynamicsProcessor(lowPassFilter)
            dynamicsProcessor.threshold = -15
            dynamicsProcessor.headRoom = 10.0
            dynamicsProcessor.attackTime = 0.05
            dynamicsProcessor.releaseTime = 0.3
            
            mixer = Mixer(dynamicsProcessor)
            audioEngine.output = mixer

            // Set up the mixer and output the processed sound
//            mixer = Mixer(dynamicsProcessor)
            mixer.volume = 3.0  // Amplify output
//            audioEngine.output = mixer  // Route the processed signal to the speaker


            // Attach amplitude tap for real-time visualization
            amplitudeTap = AmplitudeTap(dynamicsProcessor) { amplitude in
                DispatchQueue.main.async {
                    print("Debug - Amplitude value: \(amplitude)")
                    self.handleAmplitude(amplitude)
                }
            }
            amplitudeTap.start()

            // Ensure audio is routed to the speaker
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)

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
