import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!

    var faceDetectionRequest: VNRequest!
    var textDetectionRequest: VNRequest!
    var currentLandmarks: [VNFaceObservation]?
    var idLandmarks: [VNFaceObservation]?
    var didSeeId = false

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private var devicePosition: AVCaptureDevice.Position = .front
    private var session = AVCaptureSession()
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "SessionQueue", attributes: [], target: nil)
    private var setupResult: SessionSetupResult = .success
    private var videoDeviceInput:   AVCaptureDeviceInput!
    private var videoDataOutput:    AVCaptureVideoDataOutput!
    private var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    private var requests = [VNRequest]()

    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.session = session
        faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleFaceLandmarks)
        textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: self.handleTexts)
        setupCardVision()
        
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video){
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
             setupResult = .notAuthorized
        }
        sessionQueue.async { [unowned self] in
            self.configureSession(.back)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = deviceOrientation.videoOrientation, deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                return
            }
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }

    func startRunning() {
        sessionQueue.async { [unowned self] in
            switch self.setupResult {
            case .success:
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("SeeSomeId doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "SeeSomeId", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                        UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    self.present(alertController, animated: true, completion: nil)
                }
            case .configurationFailed:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "SeeSomeId", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }


    @IBAction func moveOn(_ sender: Any) {

        idLandmarks = currentLandmarks
        if let landmarks = idLandmarks {
            for landmark in landmarks {
                print(landmark)
            }
        }
        nextButton.titleLabel?.text = "Done"
        // switch the camera to selfie mode
        didSeeId = true
        nextButton.isHidden = true

        // start all over with a fresh session
        self.previewView.removeMask()
        session = AVCaptureSession()
        previewView.session = session
        sessionQueue.async { [unowned self] in
            self.configureSession(.front)
            self.setupFaceVision()
            self.startRunning()
        }
    }

    private func configureSession(_ preferredPosition: AVCaptureDevice.Position) {

        devicePosition = preferredPosition

        if self.setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if preferredPosition == .back {
                if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) {
                    defaultVideoDevice = dualCameraDevice
                } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
                    defaultVideoDevice = backCameraDevice
                } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                    defaultVideoDevice = frontCameraDevice
                }
            } else if preferredPosition == .front {
                if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                    defaultVideoDevice = frontCameraDevice
                }
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                DispatchQueue.main.async {
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    self.previewView.videoPreviewLayer.connection!.videoOrientation = initialVideoOrientation
                }
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("\(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)]
        
        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            session.addOutput(videoDataOutput)
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
    
    private func availableSessionPresets() -> [String] {
        let allSessionPresets = [AVCaptureSession.Preset.photo,
                                 AVCaptureSession.Preset.low,
                                 AVCaptureSession.Preset.medium,
                                 AVCaptureSession.Preset.high,
                                 AVCaptureSession.Preset.cif352x288,
                                 AVCaptureSession.Preset.vga640x480,
                                 AVCaptureSession.Preset.hd1280x720,
                                 AVCaptureSession.Preset.iFrame960x540,
                                 AVCaptureSession.Preset.iFrame1280x720,
                                 AVCaptureSession.Preset.hd1920x1080,
                                 AVCaptureSession.Preset.hd4K3840x2160]
        
        var availableSessionPresets = [String]()
        for sessionPreset in allSessionPresets {
            if session.canSetSessionPreset(sessionPreset) {
                availableSessionPresets.append(sessionPreset.rawValue)
            }
        }
        return availableSessionPresets
    }
    
    func exifOrientationFromDeviceOrientation() -> UInt32 {
        enum DeviceOrientation: UInt32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        var exifOrientation: DeviceOrientation

        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation =  devicePosition == .front ? .left0ColTop :  .left0ColBottom
        case .landscapeLeft:
            exifOrientation = devicePosition == .front ? .bottom0ColLeft : .top0ColRight
        case .landscapeRight:
            exifOrientation = devicePosition == .front ? .top0ColRight : .bottom0ColLeft
        default:
            exifOrientation =  devicePosition == .front ? .left0ColTop : .right0ColTop
        }
        return exifOrientation.rawValue
    }
}

extension ViewController {
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"), object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: Notification.Name("AVCaptureSessionWasInterruptedNotification"), object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: Notification.Name("AVCaptureSessionInterruptionEndedNotification"), object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func sessionRuntimeError(_ notification: Notification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else { return }
        let error = AVError(_nsError: errorValue)
        print("\(error)")
        if error.code == .mediaServicesWereReset {
            sessionQueue.async { [unowned self] in
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    @objc func sessionWasInterrupted(_ notification: Notification) {
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
                print("\(reason)")
        }
    }
    @objc func sessionInterruptionEnded(_ notification: Notification) {
        print("\(notification)")
    }
}

extension ViewController {

    func setupCardVision() {
        self.requests = [faceDetectionRequest, textDetectionRequest]
    }

    func setupFaceVision() {
        self.requests = [faceDetectionRequest]
    }

    func handleTexts(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //perform all the UI updates on the main queue
            guard let results = request.results as? [VNTextObservation] else { return }
            //self.previewView.removeMask()
 //           self.previewView.removeMask(index: 3)
            for text in results {
                self.previewView.drawTextboundingBox(text: text)
            }
        }
    }

    func handleFaceLandmarks(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //perform all the UI updates on the main queue
            guard let results = request.results as? [VNFaceObservation] else { return }
            self.currentLandmarks = results

            self.previewView.removeMask()
            //self.previewView.removeMask(index: 4)
            if self.didSeeId {
                self.previewView.drawFaceOval()
            } else {
                self.previewView.drawCardBox()
            }

            for face in results {
                self.previewView.drawFaceWithLandmarks(face: face)
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
        let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }
        var requestOptions: [VNImageOption : Any] = [:]
        
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics : cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(requests)
        }
            
        catch {
            print(error)
        }
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

