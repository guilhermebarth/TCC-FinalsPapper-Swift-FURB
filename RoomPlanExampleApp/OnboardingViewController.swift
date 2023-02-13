/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A view controller for the app's first screen that explains what to do.
 */

import UIKit
import AVFoundation
import Speech



class OnboardingViewController: UIViewController, SFSpeechRecognizerDelegate {
    @IBOutlet var existingScanView: UIView!
    @IBOutlet weak var label: UILabel!
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var task : SFSpeechRecognitionTask!
    var isStart: Bool = false
    
    @IBAction func startScan(_ sender: UIButton) {
        startingScan()
    }
    
    func startingScan() {
        if let viewController = self.storyboard?.instantiateViewController(
            withIdentifier: "RoomCaptureViewNavigationController") {
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true)
        }
    }
    
    let synthesizer = AVSpeechSynthesizer()
    
    override func viewDidLoad() {
        
        let utterance = AVSpeechUtterance(string: "Para começar fale INICIAR BUSCA ou Start Scanning")
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
        
        requestPermission()
        startRecognition()
        
    }
    
    
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { (authState) in
            OperationQueue.main.addOperation {
                if authState == .authorized {
                    print("ACCEPTED")
                } else if authState == .denied {
                    print("User denied permission")
                } else if authState == .notDetermined {
                    print("In User phone there is no SpeechRecognizer")
                } else if authState == .restricted {
                    print("User has been restricted for using the speech recognization")
                }
            }
        }
    }
    
    func startRecognition() {
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch let error {
            print("Error comes here for starting the audio listener.")
        }
        
        guard let myRecognition = SFSpeechRecognizer() else {
            print("Recognizition is not allowed in your location")
            return
        }
        
        if !myRecognition.isAvailable {
            print("Recognization is free right now, please try again after some time.")
        }
        
        
        task = speechRecognizer?.recognitionTask(with: request, resultHandler: { (response, error) in
            guard let response = response else {
                if error != nil {
                    print("erro: \(error.debugDescription)")
                } else {
                    print("Problem in giving the response")
                }
                
                return
            }
            
            let message = response.bestTranscription.formattedString.lowercased()
            print(message)
            
            
            if message.contains("start scanning")
                || message.contains("iniciar Busca")
                || message.contains("initial Busca")
                || message.contains("initial Booska")
                || message.contains("initialize Busca")
                || message.contains("initialize Booska")
                
            {
                self.stopAudio()
                self.startingScan()
            }
        })
    }
    
    func stopAudio() {
        self.task.finish()
        self.task.cancel()
        self.task = nil
        
        self.request.endAudio()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
}
