/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The sample app's main view controller that manages the scanning process.
 */

import UIKit
import RoomPlan
import AVFoundation
import Speech
import MLImage
import MLKit


private enum Constants {
    static let detectionNoResultsMessage = "No results returned."
    static let failedToDetectObjectsMessage = "Failed to detect objects in image."
    static let localModelFile = (name: "bird", type: "tflite")
    static let labelConfidenceThreshold = 0.75
    static let smallDotRadius: CGFloat = 5.0
    static let largeDotRadius: CGFloat = 10.0
    static let lineColor = UIColor.yellow.cgColor
    static let lineWidth: CGFloat = 3.0
    static let fillColor = UIColor.clear.cgColor
    static let segmentationMaskAlpha: CGFloat = 0.5
}

extension SceneDelegate {
    static weak var shared: SceneDelegate?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Self.shared = self
        
        guard let scene = scene as? UIWindowScene else {
            return
        }
        // Save the reference when the scene is born.
        currentScene = scene
    }
}

extension UIViewController {
    var sceneDelegate: RoomCaptureViewController? {
        for scene in UIApplication.shared.connectedScenes {
            if scene == currentScene,
               let delegate = scene.delegate as? RoomCaptureViewController {
                return delegate
            }
        }
        return nil
    }
}

var currentScene: UIScene?

class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    
    
    @IBOutlet var exportButton: UIButton?
    
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?
    
    private var isScanning: Bool = false
    
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    
    private var finalResults: CapturedRoom?
    
    public var listObjects: [SelectedObject] = []
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var task : SFSpeechRecognitionTask!
    let synthesizer = AVSpeechSynthesizer()
    
    let cancelScan = ["cancelar", "cancel"]
    let doneScan = ["done", "finalizar", "finalize", "finaliza"]
    let export = ["export", "esportar", "esporte", "esportação"]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up after loading the view.
        setupRoomCaptureView()
        
        sendTextToSpeech(texto: "Para começar mova o celular para cima e para baixo.")
        sendTextToSpeech(texto: "Caso deseje cancelar a busca fale Cancel ou Cancelar e para finalizar fale Finalizar")
        
        listenSpeechToText(texto: cancelScan + doneScan + export)
        
    }
    
    
    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        
        verifyIfAlreadyHasObject(listObjects: room.doors, legend: "porta")
        verifyIfAlreadyHasObject(listObjects: room.walls, legend: "parede")
        verifyIfAlreadyHasObject(listObjects: room.openings, legend: "passagem")
        verifyIfAlreadyHasObject(listObjects: room.windows, legend: "janela")
        
        if room.objects.count > 0 {
            DispatchQueue.main.async {
                self.verifyObjectInMLKit(listObjects: room.objects)
            }
        }
    }
    
    func verifyObjectInMLKit(listObjects: [CapturedRoom.Object]) {
        var alreadyHasObj = false
        
        for obj in listObjects
        {
            for verifyObj in self.listObjects {
                if obj.identifier == verifyObj.id {
                    alreadyHasObj = true
                }
            }
            
            if !alreadyHasObj {
                let legend = self.identifyObjectAndReturnLabel()
                let find = "Tem um \(legend) na sua frente."
                self.sendTextToSpeech(texto: find)
                self.listObjects.append(SelectedObject(id: obj.identifier, type: nil, legend: legend))
            }
            alreadyHasObj = false
        }
    }
    
    var imagePicker = UIImagePickerController()
    
    func openCameraAndGetSnapshot() -> UIImage? {
        var screenshotImage: UIImage?
        // necessita estar na main thread, porém quando está na mainthread o snapshot capturado vem
        // todo preto, ou seja, sem informacoes e ele deixa o aplicativo muito mais travado
        
        
        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        screenshotImage = img
        UIGraphicsEndImageContext()
        
        /*if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
         let snap = sceneDelegate.window?.snapshotView(afterScreenUpdates: false)
         
         view.addSubview(snap!)
         UIGraphicsBeginImageContextWithOptions(view!.frame.size, true, 0.0)
         
         if let context = UIGraphicsGetCurrentContext() { view!.layer.render(in: context) }
         screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
         UIGraphicsEndImageContext()
         }*/
        
        return screenshotImage
    }
    
    
    func identifyObjectAndReturnLabel() -> String {
        var screenshot: UIImage? = self.openCameraAndGetSnapshot()
        
        if screenshot == nil {
            print("nulo")
            return "objeto"
        } else {
            UIImageWriteToSavedPhotosAlbum(screenshot!, nil, nil, nil)
        }
        
        
        return verifyObject(image: screenshot!)
    }
    
    
    func verifyObject(image: UIImage) -> String {
        var imageLabel = "objeto"
        
        let options: CommonImageLabelerOptions! = ImageLabelerOptions()
        options.confidenceThreshold = NSNumber(floatLiteral: Constants.labelConfidenceThreshold)
        
        let onDeviceLabeler = ImageLabeler.imageLabeler(options: options)
        let visionImage = VisionImage(image: image)
        
        visionImage.orientation = image.imageOrientation
        onDeviceLabeler.process(visionImage) { labels, error in
            guard error == nil, let labels = labels, !labels.isEmpty else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                print("Erro durante a detecção da legenda: \(errorString)")
                return
            }
            
            let labelsInImage = labels.map { label -> String in
                return "Label: \(label.text), Confidence: \(label.confidence)"
            }.joined(separator: "\n")
            
            if !labelsInImage.isEmpty {
                imageLabel = labels.first?.text ?? "objeto"
            }
        }
        return imageLabel
    }
    
    func verifyIfAlreadyHasObject(listObjects: [CapturedRoom.Surface], legend: String) {
        var alreadyHasObj = false
        
        for obj in listObjects
        {
            for verifyObj in self.listObjects {
                if obj.identifier == verifyObj.id {
                    alreadyHasObj = true
                }
            }
            
            if !alreadyHasObj {
                let find = "Tem uma \(legend) na sua frente."
                sendTextToSpeech(texto: find)
                self.listObjects.append(SelectedObject(id: obj.identifier, type: obj.category, legend: legend))
            }
            
            alreadyHasObj = false
            
        }
    }
    
    
    func sendTextToSpeech(texto text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
    
    var haveDone = false
    
    func listenSpeechToText(texto text: [String]) {
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
        
        let locale = NSLocale.autoupdatingCurrent
        
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
            
            
            
            for selectedMessage in text {
                if message.contains(selectedMessage) {
                    // se existe palavra chave, cancela ou conclui
                    
                    if self.cancelScan.contains(selectedMessage) {
                        self.navigationController?.dismiss(animated: true)
                        
                        self.stopListen()
                        self.listenSpeechToText(texto: self.cancelScan + self.doneScan + self.export)
                    } else if self.export.contains(selectedMessage)
                                && self.haveDone {
                        self.exportResults(self.exportButton!)
                    } else if self.doneScan.contains(selectedMessage) {
                        self.haveDone = true
                        if self.isScanning {
                            self.stopSession()
                        } else {
                            self.navigationController?.dismiss(animated: true)
                        }
                        
                        
                        self.stopListen()
                        self.listenSpeechToText(texto: self.cancelScan + self.doneScan + self.export)
                    }
                    
                }
            }
        })
    }
    
    func stopListen() {
        self.task.finish()
        self.task.cancel()
        self.task = nil
        
        self.request.endAudio()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        
        view.insertSubview(roomCaptureView, at: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
    }
    
    private func startSession() {
        isScanning = true
        roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
        setActiveNavBar()
    }
    
    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        
        setCompleteNavBar()
    }
    
    
    // Access the final post-processed results.
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResults = processedResult
    }
    
    @IBAction func doneScanning(_ sender: UIBarButtonItem) {
        if isScanning { stopSession() } else { cancelScanning(sender) }
    }
    
    @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true)
    }
    
    // Export the USDZ output by specifying the `.parametric` export option.
    // Alternatively, `.mesh` exports a nonparametric file and `.all`
    // exports both in a single USDZ.
    @IBAction func exportResults(_ sender: UIButton) {
        let destinationURL = FileManager.default.temporaryDirectory.appending(path: "Room.usdz")
        do {
            try finalResults?.export(to: destinationURL, exportOptions: .parametric)
            
            let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            activityVC.modalPresentationStyle = .popover
            
            present(activityVC, animated: true, completion: nil)
            if let popOver = activityVC.popoverPresentationController {
                popOver.sourceView = self.exportButton
            }
        } catch {
            print("Error = \(error)")
        }
    }
    
    // Decide to post-process and show the final results.
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }
    
    
    private func setActiveNavBar() {
        UIView.animate(withDuration: 1.0, animations: {
            self.cancelButton?.tintColor = .white
            self.doneButton?.tintColor = .white
            self.exportButton?.alpha = 0.0
        }, completion: { complete in
            self.exportButton?.isHidden = true
        })
    }
    
    private func setCompleteNavBar() {
        self.exportButton?.isHidden = false
        UIView.animate(withDuration: 1.0) {
            self.cancelButton?.tintColor = .systemBlue
            self.doneButton?.tintColor = .systemBlue
            self.exportButton?.alpha = 1.0
        }
    }
}

extension UIImage {
    
    convenience init?(view: UIView?) {
        guard let view: UIView = view else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        guard let context: CGContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        view.layer.render(in: context)
        let contextImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard
            let image: UIImage = contextImage,
            let pngData: Data = image.pngData()
        else { return nil }
        
        self.init(data: pngData)
    }
}

