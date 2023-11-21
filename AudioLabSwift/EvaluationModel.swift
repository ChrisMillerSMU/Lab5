import UIKit

class EvaluationModel: NSObject {
    // These are all of the variables used for handling accuracy values and models that
    // are being actiely evaluated
    private var modelString: String = "Spectrogram CNN"
    private var spectogramAccuracy: String = "--.-"
    private var logisticAccuracy: String = "--.-"
    private var labelString: String = "Training accuracy for\nSpectogram CNN is:\n--.-%"
    
    // Set the machine learning model version to the specific one that we are evaluating
    // and making changes to the metrics to as we train.
    func setModel(modelType: String) {
        self.modelString = modelType
    }
    
    // Update the accuracy of the specific model that we are currently evaluating
    func setAccuracy(accuracy:String, myCase:String) {
        switch(myCase){
        case "Spectrogram CNN":
            self.spectogramAccuracy = accuracy
            break
        case "Logistic Regression":
            self.logisticAccuracy = accuracy
            break
        default:
            break
        }
    }
    
    // Update the label based on the model of interest and the new accuracy retireved for our ML
    // model we are retraining and checking evaluation metrics for
    func updateLabelString() {
        switch (self.modelString) {
        case "Spectrogram CNN":
            self.labelString = "Training accuracy for\n\(self.modelString) is:\n\(self.spectogramAccuracy)%"
        case "Logistic Regression":
            self.labelString = "Training accuracy for\n\(self.modelString) is:\n\(self.logisticAccuracy)%"
        default:
            self.labelString = "Training accuracy unavailable"
        }
    }
    
    // Get the specific model that we have as our version right now
    func getModel() -> String{
        return self.modelString
    }
    
    // Get the specific label string for insertion into the value of a label
    func getLabelString() -> String {
        return self.labelString
    }
}
