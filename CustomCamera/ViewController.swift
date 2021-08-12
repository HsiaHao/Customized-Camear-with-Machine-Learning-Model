//
//  ViewController.swift
//  CustomCamera
//
//  Created by Alex Barbulescu on 2020-05-21.
//  Copyright © 2020 ca.alexs. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Vision

class ViewController: UIViewController {
    
    //MARKL- Vars
    var captureSession : AVCaptureSession!
    
    var backCamera : AVCaptureDevice!
    var frontCamera : AVCaptureDevice!
    var backInput : AVCaptureInput!
    var frontInput : AVCaptureInput!
    var videoOutput: AVCaptureVideoDataOutput!
    
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    var takePicture = false
    
    //MARK:- View Components
    let switchCameraButton : UIButton = {
        let button = UIButton()
        let image = UIImage(named: "switchcamera")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let captureImageButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let capturedImageView = CapturedImageView()
    
    //MARK:- Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupAndStartCaptureSession()
        
    }
    
    func setupAndStartCaptureSession(){
        print("set and start session...")
        DispatchQueue.global(qos: .userInitiated).async{
            //init session
            print("set and start session in back ground...")
            self.captureSession = AVCaptureSession()
            //start configuration
            self.captureSession.beginConfiguration()
            
            //do some configuration?
            
            if self.captureSession.canSetSessionPreset(.photo){
                // .photo: use the highest quality images
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            self.setupInputs()
            print("finish input set up...")
            DispatchQueue.main.async {
                print("set preview layer...")
                self.setupPreviewLayer()
                print("finish set up preview layer...")
            }
            self.setupOutput()
            
            //commit configuration
            self.captureSession.commitConfiguration()
            //start running it
            self.captureSession.startRunning()
        }
    }
    
    func setupInputs(){
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        } else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }
        
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            fatalError("no front camera")
        }
        
        //now we need to create an input objects from our devices
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            fatalError("could not create input device from back camera")
        }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            fatalError("could not add back camera input to capture session")
        }
        
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            fatalError("could not add front camera input to capture session")
        }
        
        //connect back camera input to session
        captureSession.addInput(backInput)
    }
    
    func setupPreviewLayer(){
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            view.layer.insertSublayer(previewLayer, below: switchCameraButton.layer)
            previewLayer.frame = self.view.layer.frame
    }
    
    func setupOutput(){
       videoOutput = AVCaptureVideoDataOutput()
       let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
       videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
       
       if captureSession.canAddOutput(videoOutput) {
           captureSession.addOutput(videoOutput)
       } else {
           fatalError("could not add video output")
       }
   }

    
    //MARK:- Actions
    @objc func captureImage(_ sender: UIButton?){
        print("capture button pressed.")
        takePicture = true
    }
    
    @objc func switchCamera(_ sender: UIButton?){
        
    }
    

}

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !takePicture{
            return
        }
        print("active capture output.")
        //try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("did not get an image from buffer")
            return
        }
        
        guard let model = try? VNCoreMLModel(for: MobileNetV2().model) else {return}
        
        let request = VNCoreMLRequest(model: model) { finishedReq, err in
            
            guard let results = finishedReq.results as? [VNClassificationObservation] else {return}
            
            guard let firstObservation = results.first else {return}
            
            print(firstObservation.identifier, firstObservation.confidence)
        }
        try? VNImageRequestHandler(cvPixelBuffer: cvBuffer, options: [:]).perform([request])
        
        
        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        
        //get UIImage out of CIImage
        let uiImage = UIImage(ciImage: ciImage)


        DispatchQueue.main.async {
            self.capturedImageView.image = uiImage
            self.takePicture = false
        }
    }
}

