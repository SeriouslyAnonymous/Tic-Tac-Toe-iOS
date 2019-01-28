import SpriteKit

enum TTTPlayer {
    case ai
    case user
}

enum TTTGameState {
    case progress
    case loss
    case win
    case draw
}

class GameScene: SKScene {
    
    // MARK: - Properties
    private var gameStateLabel: SKLabelNode?
    private var refreshButton: SKNode?
    private var boardNode: SKNode?
    private var emptyInteractiveAreas: [TTTInteractiveBoardArea] {
        var areas = [TTTInteractiveBoardArea]()
        guard let boardNode = boardNode else {
            return areas
        }
        
        for node in boardNode.children {
            guard let areaNode = node as? TTTInteractiveBoardArea,
               areaNode.value == .empty else {
                continue
            }
            areas.append(areaNode)
        }
        return areas
    }
    
    private var currentPlayer: TTTPlayer = .user {
        didSet {
            guard isGameInProgress else { return }
            updateTurnIndicator()
            if currentPlayer == .ai {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                    guard let self = self else { return }
                    self.processComputerTurn()
                }
            }
        }
    }
    private var gameState: TTTGameState = .progress {
        didSet {
            updateRefreshButton()
        }
    }
    
    private var isUserCurrentPlayer: Bool {
        return currentPlayer == .user
    }
    private var isGameInProgress: Bool {
        return gameState == .progress
    }
    
    // MARK: - SpriteKit Overrides
    override func didMove(to view: SKView) {
        
        guard let titleLabel = childNode(withName: .titleLabel) as? SKLabelNode else {
            return
        }
        
        // Define start animations
        let fadeIn = SKAction.fadeIn(withDuration: .short)
        let scale = SKAction.scale(to: 1, duration: .short)
        let firstTitleAnimation = SKAction.group([fadeIn, scale])
        
        let delay = SKAction.wait(forDuration: .short)
        let finalPosition = CGPoint(x: 0, y: height - titleLabel.height - 70)
        let move = SKAction.move(to: finalPosition, duration: .short)
        let titleWaitAction = SKAction.wait(forDuration: firstTitleAnimation.duration + delay.duration + move.duration)
        
        // Setup title label
        titleLabel.alpha = 0
        titleLabel.setScale(0.5)
        
        titleLabel.position = CGPoint(x: 0, y: (height - titleLabel.height)/2)
        titleLabel.run(SKAction.sequence([firstTitleAnimation, delay, move]))
        
        // Define board node
        boardNode = childNode(withName: .boardNode)
        
        // Setup turn indicator label
        if let gameStateLabel = childNode(withName: .gameStateLabel) as? SKLabelNode {
            self.gameStateLabel = gameStateLabel
            updateTurnIndicator()
            let fadeInAction = SKAction.fadeIn(withDuration: .short)
            
            gameStateLabel.alpha = 0
            gameStateLabel.run(SKAction.sequence([titleWaitAction, fadeInAction]))
        }
        
        // Setup board
        if let boardNode = childNode(withName: .boardNode) {
            boardNode.alpha = 0
            let fadeInAction = SKAction.fadeIn(withDuration: .short)
            boardNode.run(SKAction.sequence([titleWaitAction, fadeInAction]))
        }
        
        // Hide refresh button
        if let refreshButton = childNode(withName: .refreshButton) {
            self.refreshButton = refreshButton
            refreshButton.alpha = 0
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Get node below touched point
        let location = touch.location(in: self)
        let selectedNode = atPoint(location)
        
        // Detect tap on interactive areas
        if let selectedAreaNode = selectedNode as? TTTInteractiveBoardArea {
            guard isGameInProgress,
                isUserCurrentPlayer,
                selectedAreaNode.value == .empty else {
                    return
            }
            
            updateValue(for: selectedAreaNode)
            updateRefreshButton()
            togglePlayer()
        }
        
        // Detect touchdown on refresh button
        if selectedNode.name == .refreshButton {
            selectedNode.setScale(0.8)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Get node below touched point
        let location = touch.location(in: self)
        let selectedNode = atPoint(location)
        
        // Scale refresh button back to original size
        if selectedNode.name == .refreshButton {
            resetGame()
            selectedNode.run(SKAction.scale(to: 1, duration: .standard))
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    // MARK: - Updates
    func updateValue(for areaNode: TTTInteractiveBoardArea) {
        
        let nodeName = isUserCurrentPlayer ? "x_graphic" : "o_graphic"
        let node = SKSpriteNode(imageNamed: nodeName)
        areaNode.value = isUserCurrentPlayer ? .x : .o
        node.size = CGSize(width: 80, height: 80)
        areaNode.addChild(node)
        
        evaluateMatch()
    }
    
    func updateRefreshButton() {
        let alpha: CGFloat = isGameInProgress ? 0 : 1
        let wait = SKAction.wait(forDuration: .short)
        let fade = SKAction.fadeAlpha(to: alpha, duration: .short)
        refreshButton?.run(SKAction.sequence([wait, fade]))
    }
    
    func updateTurnIndicator() {
        if currentPlayer == .ai {
            gameStateLabel?.text = "Wait for your turn"
        } else {
            gameStateLabel?.text = "Your turn"
        }
    }
    
    // MARK: - Game lgic
    func processComputerTurn() {
        guard emptyInteractiveAreas.count > 0 else {
            return
        }
        
        let randomAreaIndex = Int.random(in: 0 ... emptyInteractiveAreas.count - 1)
        let randomArea = emptyInteractiveAreas[randomAreaIndex]
        
        updateValue(for: randomArea)
        updateRefreshButton()
        togglePlayer()
    }
    
    func togglePlayer() {
        if isUserCurrentPlayer {
            currentPlayer = .ai
        } else {
            currentPlayer = .user
        }
    }
    
    func evaluateMatch() {
        guard let boardNode = boardNode else { return }
        var winner: TTTPlayer?
        
        // Define winning combinations
        let rowWinIndexes = [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
        let columnWinIndexes = [[0, 3, 6], [1, 4, 7], [2, 5, 8]]
        let diagonalWinIndexes = [[0, 4, 8], [2, 4, 6]]
        let winningCombinationIndexes = rowWinIndexes + columnWinIndexes + diagonalWinIndexes
        
        // Get interactive areas
        var interactiveAreas = [TTTInteractiveBoardArea]()
        for node in boardNode.children {
            if let areaNode = node as? TTTInteractiveBoardArea {
                interactiveAreas.append(areaNode)
            }
        }
        
        // Check for winning combination
        for rowWinIndexCombination in winningCombinationIndexes {
            let firstIndex = rowWinIndexCombination[0]
            let secondIndex = rowWinIndexCombination[1]
            let lastIndex = rowWinIndexCombination[2]
            if interactiveAreas[firstIndex].value != .empty && interactiveAreas[secondIndex].value == interactiveAreas[firstIndex].value && interactiveAreas[lastIndex].value == interactiveAreas[firstIndex].value {
                winner = player(for: interactiveAreas[firstIndex].value)
                break
            }
        }
        
        // Update label with game result
        if let winner = winner {
            switch winner {
            case .ai:
                gameState = .loss
                gameStateLabel?.text = "You lose."
            case .user:
                gameState = .win
                gameStateLabel?.text = "Congratulations, you've won!"
            }
        } else if emptyInteractiveAreas.count == 0 {
            gameState = .draw
            gameStateLabel?.text = "Draw"
        }
    }
    
    func resetGame() {
        gameState = .progress
        currentPlayer = .user
        
        guard let boardNode = boardNode else { return }
        for boardNode in boardNode.children {
            if let areaNode = boardNode as? TTTInteractiveBoardArea {
                areaNode.value = .empty
                areaNode.removeAllChildren()
            }
        }
    }
    
    // MARK: - Helpers
    func player(for value: TTTAreaValue) -> TTTPlayer {
        switch value {
        case .x:
            return .user
        default:
            return .ai
        }
    }
}
