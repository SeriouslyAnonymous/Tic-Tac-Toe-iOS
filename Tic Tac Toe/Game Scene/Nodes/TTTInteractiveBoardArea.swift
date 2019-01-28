import Foundation
import SpriteKit
import UIKit

enum TTTAreaValue {
    case x
    case o
    case empty
}

class TTTInteractiveBoardArea: SKSpriteNode {
    var value: TTTAreaValue = .empty
}
