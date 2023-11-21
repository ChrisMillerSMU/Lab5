//
//  RequestModels.swift
//  AudioLabSwift
//
//  Created by Reece Iriye on 11/21/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit

// This struct contains both the Python return types representing Spectrogram CNN and Logistic
// Regression accuracy
struct ModelAccuraciesResponse: Codable {
    var spectrogram_cnn_accuracy: String
    var logistic_regression_accuracy: String
}

// Architecture of the data sent up for a prediction POST request
struct PredictionRequest: Codable {
    let raw_audio: [Float]
    let ml_model_type: String
}

// Architecture of the data sent up for a training POST request
/// The only difference here is that the dropdown label is included.
struct TrainingRequest: Codable {
    let raw_audio: [Float]
    let audio_label: String
    let ml_model_type: String
}




