import Foundation
import SwiftData

@Model
final class Chat {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
