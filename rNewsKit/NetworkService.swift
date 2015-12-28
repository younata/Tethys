import Foundation

class NetworkService {
    let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
    }
}
