import UIKit
import AudioKit
import AVFoundation

class ViewController: UIViewController {
    var audioEngine: AudioEngine!
    var microphone: AudioEngine.InputNode!
    var mixer: Mixer!
    var lowPassFilter: LowPassFilter!
    var amplitudeTap: AmplitudeTap!
    var isListening = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioEngine()
        configureAudioSession()
        requestMicrophonePermission()
    }

    func setupAudioEngine() {
        audioEngine = AudioEngine()
    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Explicitly set for playback and recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.overrideOutputAudioPort(.speaker)
            try audioSession.setActive(true)
            print("Audio session configured for stethoscope mode")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone permission granted")
                } else {
                    self.showMicrophonePermissionAlert()
                }
            }
        }
    }

    func showMicrophonePermissionAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Needed",
            message: "Please enable microphone access in Settings to use the stethoscope feature.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func listenTapped(_ sender: UIButton) {
        startStethoscope()
    }

    func startStethoscope() {
        guard !isListening else {
            print("Stethoscope already active")
            return
        }

        do {
            // Ensure microphone input
            guard let input = audioEngine.input else {
                print("Microphone not available")
                return
            }
            microphone = input

            // Simplified audio processing chain
            // High-pass filter to remove very low frequencies
            let highPassFilter = HighPassFilter(microphone)
            highPassFilter.cutoffFrequency = 20

            // Low-pass filter to remove high-frequency noise
            lowPassFilter = LowPassFilter(highPassFilter)
            lowPassFilter.cutoffFrequency = 250

            // Create mixer with increased volume
            mixer = Mixer(lowPassFilter)
            mixer.volume = 10.0  // Significantly increased volume
            audioEngine.output = mixer

            // Amplitude tap for monitoring
            amplitudeTap = AmplitudeTap(lowPassFilter) { amplitude in
                DispatchQueue.main.async {
                    let decibelLevel = 20 * log10(max(amplitude, 0.0001))
                    print("Heartbeat Sound Level: \(decibelLevel) dB")
                }
            }
            amplitudeTap.start()

            // Ensure speaker output
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.overrideOutputAudioPort(.speaker)

            // Start audio engine
            try audioEngine.start()
            isListening = true
            print("Stethoscope activated - listening and outputting sound")

        } catch {
            print("Failed to start stethoscope: \(error.localizedDescription)")
            isListening = false
        }
    }

    @IBAction func stopTapped(_ sender: UIButton) {
        stopStethoscope()
    }

    func stopStethoscope() {
        guard isListening else {
            print("Stethoscope already stopped")
            return
        }

        amplitudeTap?.stop()
        audioEngine.stop()
        isListening = false
        print("Stethoscope deactivated")
    }
}
