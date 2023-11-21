import UIKit

class EvaluationModel: NSObject {
    private var modelString: String = "Spectrogram CNN"
    private var spectogramAccuracy: String = "--.-"
    private var logisticAccuracy: String = "--.-"
    private var labelString: String = "Training accuracy for\nSpectogram CNN is:\n--.-%"
    
    func setModel(modelType: String) {
        self.modelString = modelType
    }
    
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
    
    func getModel() -> String{
        return self.modelString
    }
    
    func getLabelString() -> String {
        return self.labelString
    }
}
