// SMU SERVER CHANGES. BE AWARE.
let SERVER_URL = "http://10.8.159.212:8000"

import UIKit
import Foundation

class ViewController: UIViewController, URLSessionDelegate {
    
    // MARK: URL Session
    /// Configure the URL session settings that will be used throughout, labeling timeout times for requests and
    /// ensuring that these operations are NOT occuring on the Main Queue
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
    
    // MARK: View Did Load and View Will Disappear
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.setupDropdownButton()
        
        // Fetch initial model resubstitution accuracies from the Server when app starts up
        self.getModelAccuracies()
        
        // Start audio processing
        self.audio.startMicrophoneProcessing(withFps: 10)
        self.audio.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Pause in the case that this view is exited
        self.audio.pause()
    }
    
    
    // MARK: Initial Machine Learning Model Accuracy GET Request
    
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
    
    // MARK: Class Properties
    
    /// Declare an instance of our audio model with a buffer size of 22,050
    let audio = AudioModel(buffer_size: 22050)
    /// Declare an operation queue instance in moments we want to specify not running on the main queue
    let operationQueue = OperationQueue()
    /// Create a segmented control instance that is used for retrieving the text inside of each selected mode when needed
    @IBOutlet weak var modelSegmentedSwitch: UISegmentedControl!
    /// Create an instance of the name dropdown button to indicate whose name we select when training
    @IBOutlet weak var nameDropdownButton: UIButton!
    /// Create a train button instance that will then guide through the logic of training our model with an additional data point
    /// on top of all the data already stored in MongoDB
    @IBOutlet weak var trainButton: UIButton!
    /// Create a test button instance that will then guide through the logic of testing our model on an additional data point
    /// that our model was not trained on
    @IBOutlet weak var testButton: UIButton!
    /// Showcase exactly who was predicted in this label
    @IBOutlet weak var predictionLabel: UILabel!
    /// Showcase the accuracy of the selected model using this label
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
    
    // MARK: Pop-Up Button
    /// Sets up available names that appear in the dropdown. The button will only work on phones that have at least
    /// iOS 14.0 or higher set up
    func setupDropdownButton() {
        let popUpButtonClosure = { (action: UIAction) in }
        // Set up Reece and Chris as dropdown menu children
        if #available(iOS 14.0, *) {
            self.nameDropdownButton.menu = UIMenu(children: [
                UIAction(title: "Reece", handler: popUpButtonClosure),
                UIAction(title: "Chris", handler: popUpButtonClosure)
            ])
        }
        // Set up dropdown as the primary action when the button is pressed
        if #available(iOS 14.0, *) {
            self.nameDropdownButton.showsMenuAsPrimaryAction = true
        }
    }
    
    // MARK: IBActions
    /// Function invoked when switching the selected name on the Segmented Control panel on the top of the View
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
    /// Function invoked when pressing the buttion that is intended to record incoming audio data for 0.5 seconds
    /// after a 3 second timer then training the selected associated machine learning model
    @IBAction func trainButtonPressed(_ sender: UIButton) {
        // Make sure that we are not able to press any of the other buttons when we are training our
        // machine learning model
        self.testButton.isEnabled = false
        self.trainButton.isEnabled = false
        self.modelSegmentedSwitch.isEnabled = false
        self.nameDropdownButton.isEnabled = false
        
        // Invoke the `updateTimer` function that will decrement to 0 for 3 seconds then record for
        // half of a second.
        self.trainTimer.setRemainingTime(withInterval: 300)
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateTimer(button:self.trainButton, stopwatch:self.trainTimer)
        }
        
    }
    
    /// Function invoked when pressing the button that is intended to record incoming audio data for 0.5 seconds
    /// after a 3 second timer then testing our machine learning model on audio data it was not trained on and has not
    /// seen yet
    @IBAction func testButtonPressed(_ sender: UIButton) {
        // Make sure that we are not able to press any of the other buttons when we are testing our
        // machine learning model
        self.testButton.isEnabled = false
        self.trainButton.isEnabled = false
        self.modelSegmentedSwitch.isEnabled = false
        self.nameDropdownButton.isEnabled = false
    
        // Invoke the `updateTimer` function that will decrement to 0 for 3 seconds then record for
        // half of a second
        self.testTimer.setRemainingTime(withInterval: 300)
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateTimer(button:self.testButton, stopwatch:self.testTimer)
        }
    }
    
    // MARK: Functions that Run on a Timer
    /// Decrement time in the case that the 3 second timer is still running and invoke the `stopTimer` function otherwise
    func updateTimer(button:UIButton, stopwatch:TimerModel){
        // Update stopwatch display with time left if the number has not yet hit 0
        if stopwatch.getRemainingTime() > 0 {
            stopwatch.decrementRemainingTime()
            stopwatch.changeDisplay()
            button.titleLabel?.text = stopwatch.timeDisplay
        // Otherwise, stop the timer
        } else {
            // Stop timer with finished set to TRUE, since it got to 0
            self.stopTimerAndPerformNecessaryLogic(button:button)
        }
    }
    
    /// Listen for incoming audio invoked by our Novocaine-based audio model, set the training and testing button text to Train
    /// and Test respectively, and send necessary POST request
    func stopTimerAndPerformNecessaryLogic(button: UIButton) {
        // Invalidate the timer and set it to `nil` once it hits 0
        self.timer?.invalidate()
        self.timer = nil
        
        // Set button text equal to Train and Test on the main queue, and set the background
        // equal to red on the button we pressed to indicate recording in progress
        DispatchQueue.main.async {
            self.trainButton.titleLabel?.text = "Train"
            self.testButton.titleLabel?.text = "TEST"  // We put it in Caps for emphasis
            button.backgroundColor = .red
        }
        
        // Record incoming audio for 0.5 seconds and send POST request to the FastAPI backend
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.sendNecessaryPostRequest(button: button)
        }
    }
    
    /// Send a POST request to the Python FastAPI back-end server indicating that either we will be testing a specific selected model,
    /// or we will be retraining our model on the currently stored MongoDB data based on the labelled audio data that we send up
    func sendNecessaryPostRequest(button:UIButton) {
        // Indicate the type of POST request and the name selected on the dropdown that is labelled for
        // sending the data up to the backend. We use the text from the button to perform this action.
        let postType = button.titleLabel?.text
        var currentName = "Reece"
        if let name = self.nameDropdownButton.titleLabel?.text {
            currentName = name
        } else {
            print("Button text is nil")
        }
        
        // Indicate the specific machine learning model that will be invoked in this POST request
        let currentModel = self.evaluationModel.getModel()
        
        // If the button pressed was the `TEST` button, send data to the ML model prediction post request route
        if postType == "TEST" {
            self.sendPredictionPostRequest(model:currentModel)
        // If the button pressed was the `Train` button, send data to the ML model post request route
        } else if postType == "Train" {
            self.sendTrainingPostRequest(model:currentModel, label: currentName)
        }
        
        // Invalidate the timer and set it equal to `nil` again
        self.timer?.invalidate()
        self.timer = nil
        
        // Re-enable the buttons that we previously disabled
        DispatchQueue.main.async {
            self.testButton.isEnabled = true
            self.trainButton.isEnabled = true
            self.modelSegmentedSwitch.isEnabled = true
            self.nameDropdownButton.isEnabled = true
            button.backgroundColor = nil
        }
    }
    
    // MARK: Prediction and Training POST Request Handling Structs and Functions
    /// Send up a prediction to the `/predict_one/` URL route using recorded audio
    /// and perform necessary logic for data that comes back from the server
    func sendPredictionPostRequest(model: String) {
        // Set data equal to the timeData attribute of our instance of the audio model
        let data = self.audio.timeData // Make sure this is [Float], not [Double]
        
        // Set base URL equal to the Server URL with the indicated `predict_one` URL route
        let baseURL = "\(SERVER_URL)/predict_one"
        
        // Set up capability to use our route to send up a POST request
        guard let postUrl = URL(string: baseURL) else { return }
        var request = URLRequest(url: postUrl)
        
        // Set up the architecture of what a Prediction request would look like using raw audio and the
        // machine learning model type.
        let predictionRequest = PredictionRequest(raw_audio: data, ml_model_type: model)
        
        // Try-catch block for attempting to send up a POST request
        do {
            // Update request body with our input parameters, indicate HTTP method, and set up JSON
            let requestBody = try JSONEncoder().encode(predictionRequest)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // Set content type
            
            // If the request is successful, run the logic to use the values sent back to
            // change up values we need to change up for the
            let postTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
                // If error occurs, don't execute rest of the code
                if let error = error {
                    print("Error:", error)
                    return
                }
                
                // If data is empty, don't execute rest of the code
                guard let data = data else {
                    print("No data")
                    return
                }
                
                // Try-catch block for unpacking the JSON dictionary that the server sends
                // back to Swift
                do {
                    if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // Indicate exactly whether it predicts that Reece or Chris made the noise, and
                        // update the label test on the main queue
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
            postTask.resume()
        } catch {
            print("Error encoding JSON:", error)
        }
    
    }

    /// Send up a prediction to the `/upload_labeled_datapoint_and_update_model/` URL route using recorded audio
    /// and perform necessary logic for data that comes back from the server
    func sendTrainingPostRequest(model: String, label: String) {
        // Set data equal to the timeData attribute of our instance of the audio model
        let data = self.audio.timeData // Use [Float] to match the expected Pydantic model
        
        // Set base URL equal to the Server URL with the indicated `predict_one` URL route
        let baseURL = "\(SERVER_URL)/upload_labeled_datapoint_and_update_model"
        
        // Set up capability to use our route to send up a POST request
        guard let postUrl = URL(string: baseURL) else { return }
        var request = URLRequest(url: postUrl)

        // Set up the architecture of what a Prediction request would look like using raw audio, the
        // machine learning model type, and the training label audio source.
        let trainingRequest = TrainingRequest(raw_audio: data, audio_label: label, ml_model_type: model)

        // Try-catch block for attempting to send up a POST request
        do {
            // Update request body with our input parameters, indicate HTTP method, and set up JSON
            let requestBody = try JSONEncoder().encode(trainingRequest)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            request.addValue("application/json", forHTTPHeaderField: "Content-Type") // Set content type

            // If the request is successful, run the logic to use the values sent back to
            // change up values we need to change up for the
            let postTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
                // If error occurs, don't execute rest of the code
                if let error = error {
                    print("Error:", error)
                    return
                }

                // If data is empty, don't execute rest of the code
                guard let data = data else {
                    print("No data")
                    return
                }

                // Try-catch block for unpacking the JSON dictionary that the server sends
                // back to Swift
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
            postTask.resume()
        } catch {
            print("Error encoding JSON:", error)
        }
    }
    
    //MARK: JSON Conversion Functions
    /// Convert the Dictionary to actual data given the architecture of the JSON upload
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
        do { // try to parse JSON and deal with errors using try/catch block
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

