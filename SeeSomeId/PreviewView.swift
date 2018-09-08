import UIKit
import Vision
import AVFoundation

class PreviewView: UIView {
    
    private var maskLayer = [CALayer]()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    private func createLayer(in rect: CGRect, index: UInt32) -> CAShapeLayer{
        let mask = CAShapeLayer()
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = UIColor.yellow.cgColor
        mask.borderWidth = 2.0
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: index)
        return mask
    }

    var ovalBox: CGRect {
        let width = 0.9*self.frame.size.width
        let x = 0.05*self.frame.size.width
        let height = width
        let y = 0.5*self.frame.size.height - 0.5*height
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return rect
    }

    func drawFaceOval() {
        let mask = CAShapeLayer()
        mask.frame = ovalBox
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = UIColor.white.cgColor
        mask.borderWidth = 3.0
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 2)

        let label = CATextLayer()
        label.fontSize = 20.0
        label.string = "Make sure the yellow square is inside the white"
        label.foregroundColor = UIColor.white.cgColor
        let x = ovalBox.origin.x + 10.0
        let y = ovalBox.origin.y + ovalBox.size.height
        let width = ovalBox.size.width
        label.frame = CGRect(x: x , y: y , width: width, height: 25.0)
        maskLayer.append(label)
        layer.insertSublayer(label, at: 2)
    }

    var cardBox: CGRect {
        let width = 0.9*self.frame.size.width
        let x = 0.05*self.frame.size.width
        let height = width/1.586
        let y = 0.5*self.frame.size.height - 0.5*height
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return rect
    }

    func drawCardBox() {
        let mask = CAShapeLayer()
        mask.frame = cardBox
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = UIColor.white.cgColor
        mask.borderWidth = 3.0
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 1)
        let label = CATextLayer()
        label.fontSize = 20.0
        label.string = "Fit your identity card in the box"
        label.foregroundColor = UIColor.white.cgColor
        let x = cardBox.origin.x + 10.0
        let y = cardBox.origin.y + cardBox.size.height
        let width = cardBox.size.width
        label.frame = CGRect(x: x , y: y, width: width, height: 25.0)
        maskLayer.append(label)
        layer.insertSublayer(label, at: 1)

    }

    func drawTextboundingBox(text : VNTextObservation) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        let textbounds = text.boundingBox.applying(translate).applying(transform)
        if cardBox.contains(textbounds) {
            _ = createLayer(in: textbounds, index: 3)
        }
    }

    func drawFaceboundingBox(face : VNFaceObservation) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        let facebounds = face.boundingBox.applying(translate).applying(transform)
        _ = createLayer(in: facebounds, index: 4)
    }
    
    func drawFaceWithLandmarks(face: VNFaceObservation, reference: VNFaceObservation?) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        let facebounds = face.boundingBox.applying(translate).applying(transform)
        let faceLayer = createLayer(in: facebounds, index: 4)
        
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.nose)!, isClosed:false)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.noseCrest)!, isClosed:false)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.medianLine)!, isClosed:false)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.leftEye)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.leftPupil)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.leftEyebrow)!, isClosed:false)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.rightEye)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.rightPupil)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.rightEye)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.rightEyebrow)!, isClosed:false)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.innerLips)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.outerLips)!)
        drawLandmarks(on: faceLayer, isReference: false, faceLandmarkRegion: (face.landmarks?.faceContour)!, isClosed: false)

        if let reference = reference {
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.nose)!, isClosed:false)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.noseCrest)!, isClosed:false)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.medianLine)!, isClosed:false)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.leftEye)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.leftPupil)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.leftEyebrow)!, isClosed:false)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.rightEye)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.rightPupil)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.rightEye)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.rightEyebrow)!, isClosed:false)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.innerLips)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.outerLips)!)
            drawLandmarks(on: faceLayer, isReference: true , faceLandmarkRegion: (reference.landmarks?.faceContour)!, isClosed: false)
        }
    }

    func drawLandmarks(on targetLayer: CALayer, isReference: Bool, faceLandmarkRegion: VNFaceLandmarkRegion2D, isClosed: Bool = true) {
        let rect: CGRect = targetLayer.frame
        var points: [CGPoint] = []
        for i in 0..<faceLandmarkRegion.pointCount {
            let point = faceLandmarkRegion.normalizedPoints[i]
            points.append(point)
        }
        let landmarkLayer = drawPointsOnLayer(isReference: isReference, rect: rect, landmarkPoints: points, isClosed: isClosed)
        landmarkLayer.transform = CATransform3DMakeAffineTransform(
            CGAffineTransform.identity
                .scaledBy(x: rect.width, y: -rect.height)
                .translatedBy(x: 0, y: -1)
        )
        targetLayer.insertSublayer(landmarkLayer, at: 4)
    }
    
    func drawPointsOnLayer(isReference: Bool, rect:CGRect, landmarkPoints: [CGPoint], isClosed: Bool = true) -> CALayer {
        let linePath = UIBezierPath()
        linePath.move(to: landmarkPoints.first!)
        
        for point in landmarkPoints.dropFirst() {
            linePath.addLine(to: point)
        }
        if isClosed {
            linePath.addLine(to: landmarkPoints.first!)
        }
        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath.cgPath
        lineLayer.fillColor = nil
        lineLayer.opacity = 1.0
        if isReference {
            lineLayer.strokeColor = UIColor.red.cgColor
        } else {
            lineLayer.strokeColor = UIColor.green.cgColor
        }
        lineLayer.lineWidth = 0.02
        return lineLayer
    }

    func removeMask(index: UInt32) {
        let layerIndex = Int(index)
        if layerIndex < maskLayer.count {
            let mask = maskLayer[layerIndex]
            mask.removeFromSuperlayer()
            maskLayer.remove(at: layerIndex)
        }
    }

    func removeMask() {
        for mask in maskLayer {
            mask.removeFromSuperlayer()
        }
        maskLayer.removeAll()
    }
}
