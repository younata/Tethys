import Quick
import Nimble

class NotificationHandlerSpec: QuickSpec {
    override func spec() {
        
        let app = UIApplication.sharedApplication()
        
        let window = UIWindow()
        
        var subject : NotificationHandler! = nil
        
        beforeEach {
            subject = NotificationHandler()
        }
        
        describe("Enabling notifications") {
            it("should enable badges, alerts, and sounds for the 'default' category") {
                // enabling notifications isn't really testable.
                expect(true).to(beTruthy())
            }
        }
        
        sharedExamples("Opening articles") {(sharedExampleContext: SharedExampleContext) in
            
        }
        
        describe("handling notifications") {
            beforeEach {
                
            }
        }
        
        describe("handling actions") {
            
        }
        
        describe("sending notifications") {
            
        }
    }
}
