//
//  AudioModel.swift
//  Saxophone ML
//
//  Created by Rafe Forward on 11/19/23.
//

import Foundation
class AudioModel {
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var isRecording = false
    var recordedAudio: [Float] = []
    var playbackData: [Float] = []
    var playbackReadHead = 0
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
    }
    
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        isRecording = true
        if let manager = self.audioManager{
            self.audioManager?.outputBlock = nil
            manager.inputBlock = self.handleMicrophone
            
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                
            }
        }
        
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    func pause(){
        if let manager = self.audioManager{
            manager.pause()
        }
        isRecording = false
    }
    func startPlayback() {
        playbackReadHead = 0

        audioManager?.outputBlock = { [weak self] (outputData, numFrames, numChannels) in
            guard let self = self else { return }

            for frame in 0..<Int(numFrames) {
                for channel in 0..<Int(numChannels) {
                    let index = frame * Int(numChannels) + channel

                    if self.playbackReadHead < self.recordedAudio.count {
                        // Write the recorded data to the output
                        outputData?[index] = self.recordedAudio[self.playbackReadHead]
                        self.playbackReadHead += 1
                    } else {
                        // If we've reached the end of the recorded data, fill with zeros
                        outputData?[index] = 0
                    }
                }
            }
        }

        // Start playback
        audioManager?.play()
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        for i in 0..<Int(numFrames * numChannels) {
            recordedAudio.append(data![i])
        }
    }
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Model Callback Methods
}
