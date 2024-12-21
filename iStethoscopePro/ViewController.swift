import UIKit
import AudioKit
import AVFoundation

class ViewController: UIViewController {
    var audioEngine: AudioEngine!
    var microphone: AudioEngine.InputNode!
    var mixer: Mixer!
    var bandPassFilter: BandPassFilter!
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

        // Reset audio engine and components
        audioEngine = AudioEngine()
        
        do {
            // Reconfigure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.overrideOutputAudioPort(.speaker)
            try audioSession.setActive(true)

            // Ensure microphone input
            guard let input = audioEngine.input else {
                print("Microphone not available")
                return
            }
            microphone = input

            // Reinitialize bandpass filter
            bandPassFilter = BandPassFilter(microphone)
            bandPassFilter.centerFrequency = 80
            bandPassFilter.bandwidth = 50

            // Reinitialize mixer
            mixer = Mixer(bandPassFilter)
            mixer.volume = 2.0
            audioEngine.output = mixer

            // Reinitialize amplitude tap
            amplitudeTap = AmplitudeTap(bandPassFilter) { amplitude in
                DispatchQueue.main.async {
                    let decibelLevel = 20 * log10(max(amplitude, 0.0001))
                    print("Heartbeat Sound Level: \(decibelLevel) dB")
                }
            }
            amplitudeTap.start()

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

        // Clean up and stop components
        amplitudeTap?.stop()
        audioEngine.stop()
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        
        // Clear references
        amplitudeTap = nil
        mixer = nil
        bandPassFilter = nil
        microphone = nil
        
        isListening = false
        print("Stethoscope deactivated")
    }
}
