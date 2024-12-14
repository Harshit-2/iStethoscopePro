import UIKit
import AudioKit
import AVFoundation

class ViewController: UIViewController {

    var audioEngine: AudioEngine!
    var microphone: AudioEngine.InputNode!
    var amplitudeTracker: AmplitudeTap!
    var waveformLayer: CAShapeLayer!
    var timer: Timer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize AudioEngine
        audioEngine = AudioEngine()

        // Set up audio session and request permissions
        configureAudioSession()
        requestMicrophonePermission()

        // Set up waveform visualization
        setupWaveformLayer()
    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setMode(.default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
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
    }

    func setupWaveformLayer() {
        waveformLayer = CAShapeLayer()
        waveformLayer.frame = CGRect(x: 0, y: 200, width: view.bounds.width, height: 100)
        waveformLayer.backgroundColor = UIColor.black.cgColor
        waveformLayer.strokeColor = UIColor.green.cgColor
        waveformLayer.lineWidth = 2.0
        waveformLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(waveformLayer)
    }

    @IBAction func listenTapped(_ sender: UIButton) {
        startListening()
    }

    func startListening() {
        do {
            guard let input = audioEngine.input else { return }
            microphone = input

            // Set up amplitude tracking
            amplitudeTracker = AmplitudeTap(microphone) { amplitude in
                self.updateWaveform(amplitude: amplitude)
            }
            amplitudeTracker.start()

            // Start audio engine
            try audioEngine.start()

            // Start visualization update timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.updateWaveform()
            }
        } catch {
            print("Failed to start AudioKit: \(error)")
        }
    }

    func updateWaveform(amplitude: Float = 0.0) {
        // Generate waveform path
        let path = UIBezierPath()
        let midY = waveformLayer.bounds.midY
        let width = waveformLayer.bounds.width
        let height = waveformLayer.bounds.height
        let amplitudeScale = CGFloat(amplitude) * height

        for x in stride(from: 0, to: width, by: 1) {
            let normalizedX = x / width
            let y = midY + amplitudeScale * sin(normalizedX * 2 * .pi)
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Update layer path
        waveformLayer.path = path.cgPath
    }

    @IBAction func stopTapped(_ sender: UIButton) {
        stopListening()
    }

    func stopListening() {
        audioEngine.stop()
        amplitudeTracker.stop()
        timer.invalidate()
        waveformLayer.path = nil
    }
}
