let SERVER_URL = "http://10.8.159.212:8000"

import UIKit
import Foundation

class ViewController: UIViewController, URLSessionDelegate {
    
    let audio = AudioModel(buffer_size: 22050)
    
    // MARK: Class Properties
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 6.0
        sessionConfig.timeoutIntervalForResource = 20.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(
            configuration: sessionConfig,
            delegate: self,
            delegateQueue: self.operationQueue
        )
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.setupPopUpButton()
        
        // Fetch model accuracies
        self.getModelAccuracies()
        
        // Start audio processing
        self.audio.startMicrophoneProcessing(withFps: 10)
        self.audio.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Pause in the case that this view is exited
        self.audio.pause()
    }
    
    
    // MARK: Model Accuracy Request
    
    /// This struct contains both the Python return types representing Spectrogram CNN and Logistic
    /// Regression accuracy
    struct ModelAccuraciesResponse: Codable {
        var spectrogram_cnn_accuracy: String
        var logistic_regression_accuracy: String
    }
    
    func getModelAccuracies() {
        // Indicate GET request route in FastAPI server for obtaining current model accuracies
        guard let url = URL(string: "\(SERVER_URL)/model_accuracies/") else { return }

        // Start up the URL Session task and run GET request code if session does not yield error
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Error handling for model accuracy fetching
            if let error = error {
                print("Error fetching model accuracies: \(error)")
                return
            }
            
            // If no data is retrieved, don't run the rest of the code
            guard let data = data else {
                print("No data received for model accuracies")
                return
            }
            
            // Try-catch block for fetching accuracies and updating the labels accordingly
            do {
                // Decode the JSON into Swift struct
                let accuracies = try JSONDecoder().decode(ModelAccuraciesResponse.self, from: data)
                
                // Update Spectrogram CNN and Logistic Regressiion accuracy
                let spectrogramCnnAccuracy: String = accuracies.spectrogram_cnn_accuracy
                let logisticAccuracy: String = accuracies.logistic_regression_accuracy
                
                // Get the accuracies set for each model
                self.evaluationModel.setAccuracy(
                    accuracy: spectrogramCnnAccuracy,
                    myCase: "Spectrogram CNN"
                )
                self.evaluationModel.setAccuracy(
                    accuracy: logisticAccuracy,
                    myCase: "Logistic Regression"
                )
                
                // Update the label to display the correct accuracy based on the selected model
                self.evaluationModel.updateLabelString()
                
                // Update the evaluation model and load up text on the main queue
                DispatchQueue.main.async {
                    self.accuracyLabel.text = self.evaluationModel.getLabelString()
                }
                
            } catch {
                print("Error decoding model accuracies: \(error)")
            }
        }
        task.resume()
    }
    
    let operationQueue = OperationQueue()
    
    @IBOutlet weak var modelSegmentedSwitch: UISegmentedControl!
    
    @IBOutlet weak var nameDropdownButton: UIButton!
    
    @IBOutlet weak var trainButton: UIButton!
    
    @IBOutlet weak var testButton: UIButton!
    
    @IBOutlet weak var predictionLabel: UILabel!
    
    @IBOutlet weak var accuracyLabel: UILabel!
    
    // Model to retain stopwatch time for train button
    lazy var trainTimer: TimerModel = {
        return TimerModel()
    }()
    
    // Model to retain stopwatch time for test button
    lazy var testTimer: TimerModel = {
        return TimerModel()
    }()
    
    // Model to retain stopwatch time for test button
    lazy var evaluationModel: EvaluationModel = {
        return EvaluationModel()
    }()
    
    var timer: Timer?
    
    @IBAction func switchNames(_ sender: UISegmentedControl) {
        // Each time the segmented control is invoked, updated the display label to showcase
        // the accuracy for the current machine learning model selected
        if let currentModel = self.modelSegmentedSwitch.titleForSegment(at: self.modelSegmentedSwitch.selectedSegmentIndex) {
            // Switch the mode of the model
            self.evaluationModel.setModel(modelType: currentModel)
            
            // Update the label string accordingly on the main queue
            self.evaluationModel.updateLabelString()
            DispatchQueue.main.async {
                self.accuracyLabel.text = self.evaluationModel.getLabelString()
            }
            
        } else {
            print("Button text is nil")
        }
    }
    
    @IBAction func trainButtonPressed(_ sender: UIButton) {
        self.testButton.isEnabled = false
        self.trainButton.isEnabled = false
        self.modelSegmentedSwitch.isEnabled = false
        self.nameDropdownButton.isEnabled = false
        
        //Use currentName and currentModel as params
        self.trainTimer.setRemainingTime(withInterval: 300)
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateTimer(button:self.trainButton, stopwatch:self.trainTimer)
        }
        
    }
    
    @IBAction func testButtonPressed(_ sender: UIButton) {
        //Straight to backend
        self.testButton.isEnabled = false
        self.trainButton.isEnabled = false
        self.modelSegmentedSwitch.isEnabled = false
        self.nameDropdownButton.isEnabled = false
        if let currentName = self.nameDropdownButton.titleLabel?.text {
            print(currentName)
        } else {
            print("Button text is nil")
        }
    
        if let currentModel = self.modelSegmentedSwitch.titleForSegment(at: self.modelSegmentedSwitch.selectedSegmentIndex) {
            print(currentModel)
        } else {
            print("Button text is nil")
        }
    
        //Use currentName and currentModel as params
        //Use currentName and currentModel as params
        self.testTimer.setRemainingTime(withInterval: 300)
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateTimer(button:self.testButton, stopwatch:self.testTimer)
        }
    }
    
    func updateTimer(button:UIButton, stopwatch:TimerModel){
        if stopwatch.getRemainingTime() > 0 {
            stopwatch.decrementRemainingTime()
            stopwatch.changeDisplay()
            button.titleLabel?.text = stopwatch.timeDisplay
        }
        else{
            // Stop timer with finished set to TRUE, since it got to 0
            self.stopTimer(button:button)
        }
    }
    
    func stopTimer(button:UIButton) {
        self.timer?.invalidate()
        self.timer = nil
        self.trainButton.titleLabel?.text = "Train"
        self.testButton.titleLabel?.text = "TEST"
        button.backgroundColor = .red
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.stopRecord(button:button)
        }
    }
    
    func stopRecord(button:UIButton) {
        //code to send off data
        let postType = button.titleLabel?.text
        var currentName = "Spectrogram CNN"
        //Straight to backend
        if let name = self.nameDropdownButton.titleLabel?.text {
            currentName = name
        } else {
            print("Button text is nil")
        }
        
        
        let currentModel = self.evaluationModel.getModel()
        
        // THIS IS WHERE WE SEND UP THE DATA
        
        if(postType == "TEST"){
            self.sendPredictionPostRequest(model:currentModel)
        }
        else{
            self.sendTrainingPostRequest(model:currentModel, label: currentName)
        }
        
        
        
        self.timer?.invalidate()
        self.timer = nil
        self.testButton.isEnabled = true
        self.trainButton.isEnabled = true
        self.modelSegmentedSwitch.isEnabled = true
        self.nameDropdownButton.isEnabled = true
        button.backgroundColor = nil
    }
    
    // MARK: Request Handling Structs and Functions
    
    struct PredictionRequest: Codable {
        let raw_audio: [Float]
        let ml_model_type: String
    }
    
    func sendPredictionPostRequest(model: String) {
        let data = audio.timeData // Make sure this is [Float], not [Double]
        
        let baseURL = "\(SERVER_URL)/predict_one"
        guard let postUrl = URL(string: baseURL) else { return }
        
        var request = URLRequest(url: postUrl)
        
        let predictionRequest = PredictionRequest(raw_audio: data, ml_model_type: model)
        
        do {
            let requestBody = try JSONEncoder().encode(predictionRequest)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // Set content type
            
            let postTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error:", error)
                    return
                }
                
                guard let data = data else {
                    print("No data")
                    return
                }
                
                do {
                    if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print(jsonDictionary)
                        if let labelResponse = jsonDictionary["audio_prediction"] as? String {
                            DispatchQueue.main.async {
                                self.predictionLabel.text = labelResponse
                            }
                        }
                    }
                } catch {
                    print("Error decoding JSON:", error)
                }
            }

            postTask.resume() // Start the task
            
        } catch {
            print("Error encoding JSON:", error)
        }
    
    }
    
    struct TrainingRequest: Codable {
        let raw_audio: [Float]
        let audio_label: String
        let ml_model_type: String
    }
    
    func sendTrainingPostRequest(model: String, label: String) {
        let data = audio.timeData // Use [Float] to match the expected Pydantic model

        let baseURL = "\(SERVER_URL)/upload_labeled_datapoint_and_update_model"
        guard let postUrl = URL(string: baseURL) else { return }

        var request = URLRequest(url: postUrl)

        let trainingRequest = TrainingRequest(raw_audio: data, audio_label: label, ml_model_type: model)

        do {
            let requestBody = try JSONEncoder().encode(trainingRequest)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // Set content type

            let postTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error:", error)
                    return
                }

                guard let data = data else {
                    print("No data")
                    return
                }

                do {
                    if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print(jsonDictionary)
                        // Update the visible label that we are able to see in the View each time we run a request
                        if let labelResponse = jsonDictionary["resub_accuracy"] as? String {
                            // Update the accuracy of the model of interest we are looking at
                            self.evaluationModel.setAccuracy(
                                accuracy: labelResponse,
                                myCase: model
                            )
                            
                            // Update string and update label with that string
                            self.evaluationModel.updateLabelString()
                            DispatchQueue.main.async {
                                self.accuracyLabel.text = self.evaluationModel.getLabelString()
                            }
                            
                            
                        }
                    }
                } catch {
                    print("Error decoding JSON:", error)
                }
            }

            postTask.resume() // Start the task

        } catch {
            print("Error encoding JSON:", error)
        }
    }
    
    func setupPopUpButton() {
        let popUpButtonClosure = { (action: UIAction) in
            print("Pop-Up Action")
        }
                
        if #available(iOS 14.0, *) {
            self.nameDropdownButton.menu = UIMenu(children: [
                UIAction(title: "Reece", handler: popUpButtonClosure),
                UIAction(title: "Chris", handler: popUpButtonClosure)
            ])
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 14.0, *) {
            self.nameDropdownButton.showsMenuAsPrimaryAction = true
        } else {
            // Fallback on earlier versions
        }
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                            print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    
}

