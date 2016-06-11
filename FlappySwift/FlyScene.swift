//
//  GameScene.swift
//  FlappySwift
//
//  Created by Nils Fischer on 06.06.16.
//  Copyright (c) 2016 iOS Dev Kurs Universität Heidelberg. All rights reserved.
//

import SpriteKit
import GameplayKit

struct CollisionCategory {
    typealias CategoryBitMask = UInt32
    
    static let world: CategoryBitMask = 1 << 0
    static let bird: CategoryBitMask = 1 << 1
    static let obstacle: CategoryBitMask = 1 << 2
    static let score: CategoryBitMask = 1 << 3
    
}

class FlyScene: SKScene {
    
    
    // MARK: Constants
    
    /// The bird's distance from the left side of the screen
    fileprivate static let birdPosition: CGFloat = 100
    /// The impulse the bird gains with each flap, i.e. each tap on the screen, in Newton-seconds
    fileprivate static let impulseOnFlap: CGFloat = 500
    /// The time between spawing obstacles, in seconds
    fileprivate static let obstacleSpawnDelay: TimeInterval = 1.5
    /// The gap between the upper and lower part of the obstacle where the bird may safely fly through, in points
    fileprivate static let obstacleGap: CGFloat = 200
    /// The amount the obstacle may be shifted upwards or downwards randomly, in points
    fileprivate static let obstaclePositionVariance: CGFloat = 150
    /// The movement speed of the obstacles, in points per second
    fileprivate static let obstacleSpeed: CGFloat = 100
    
    
    // MARK: Lifecycle
    
    private lazy var gameStateMachine: GKStateMachine = {
        return GKStateMachine(states: [
            PrepareFlyingState(scene: self),
            FlyingState(scene: self),
            GameOverState(scene: self),
            ])
    }()

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        physicsWorld.contactDelegate = self
        
        self.addChild(background)
        self.addChild(scoreLabel)
        self.addChild(bird)
        shaking.addChild(obstacles)
        shaking.addChild(ground)
        self.addChild(shaking)
        
        gameStateMachine.enter(PrepareFlyingState.self)
    }
    
    
    // MARK: User Interaction
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameStateMachine.currentState {
            
        case _ as PrepareFlyingState, _ as GameOverState:
            guard shaking.action(forKey: "shaking") == nil else {
                break
            }
            gameStateMachine.enter(FlyingState.self)
            fallthrough
            
        case _ as FlyingState:
            bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: FlyScene.impulseOnFlap))
            
        default:
            break
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // update any game logic
    }

    fileprivate func birdDidHitObstacle() {
        gameStateMachine.enter(GameOverState.self)
    }
    
    fileprivate func increaseScore() {
        guard let flyingState = gameStateMachine.currentState as? FlyingState else {
            return
        }

        flyingState.score += 1
        
        let scoreParticleEmitter = self.scoreParticleEmitter.copy() as! SKEmitterNode
        bird.addChild(scoreParticleEmitter)
        scoreParticleEmitter.run(emitScoreExplosion)
    }
    
    fileprivate lazy var scoreParticleEmitter: SKEmitterNode = {
        let emitter = SKEmitterNode(fileNamed: "ScoreParticles")!
        emitter.targetNode = self
        return emitter
    }()
    fileprivate lazy var emitScoreExplosion: SKAction = {
        .sequence([
            .wait(forDuration: 1),
            .removeFromParent(),
            ])
    }()
    
    
    // MARK: Game Elements
    
    /// MARK: The player character
    fileprivate var bird: SKSpriteNode = {
        let sprite = SKSpriteNode(imageNamed: "bird-01")
        let physicsBody = SKPhysicsBody(circleOfRadius: sprite.size.width / 2)
        physicsBody.mass = 1
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = CollisionCategory.bird
        physicsBody.collisionBitMask = CollisionCategory.world | CollisionCategory.obstacle
        physicsBody.contactTestBitMask = CollisionCategory.obstacle | CollisionCategory.score
        sprite.physicsBody = physicsBody
        sprite.constraints = [ SKConstraint.positionX(SKRange(value: FlyScene.birdPosition, variance: 0)) ]
        return sprite
    }()
    fileprivate let animateFlappingBird: SKAction = {
        let birdTextures = SKTextureAtlas(named: "bird")
        return .repeatForever(.animate(with: birdTextures.textureNames.sorted().map({ birdTextures.textureNamed($0) }), timePerFrame: 0.2))
    }()
    fileprivate let birdHover: SKAction = {
        let moveUp = SKAction.moveBy(x: 0, y: 15, duration: 0.8)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = SKAction.moveBy(x: 0, y: -15, duration: 0.8)
        moveDown.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([
            moveUp,
            moveDown,
            ]))
    }()
    
    private let obstaclePositionRandomSource = GKARC4RandomSource()

    /// Holds all obstacles to control their shared properties such as speed
    fileprivate let obstacles: SKNode = {
        let node = SKNode()
        return node
    }()
    
    private let upperObstacleTexture = SKTexture(imageNamed: "PipeDown")
    private let lowerObstacleTexture = SKTexture(imageNamed: "PipeUp")

    /// Creates an obstacles and moves it across the screen
    fileprivate lazy var spawnObstacle: SKAction = {
        return SKAction.run {
            let upperObstacle = SKSpriteNode(texture: self.upperObstacleTexture)
            upperObstacle.anchorPoint = CGPoint(x: 0, y: 0)
            upperObstacle.centerRect = CGRect(x: 0, y: 20.0/160, width: 1, height: 140.0/160)
            upperObstacle.yScale = self.size.height / upperObstacle.size.height
            let lowerObstacle = SKSpriteNode(texture: self.lowerObstacleTexture)
            lowerObstacle.anchorPoint = CGPoint(x: 0, y: 1)
            lowerObstacle.centerRect = CGRect(x: 0, y: 0, width: 1, height: 140.0/160)
            lowerObstacle.yScale = self.size.height / lowerObstacle.size.height

            let upperPhysicsBody = SKPhysicsBody(edgeLoopFrom: upperObstacle.frame)
            upperPhysicsBody.categoryBitMask = CollisionCategory.obstacle
            upperObstacle.physicsBody = upperPhysicsBody
            let lowerPhysicsBody = SKPhysicsBody(edgeLoopFrom: lowerObstacle.frame)
            lowerPhysicsBody.categoryBitMask = CollisionCategory.obstacle
            lowerObstacle.physicsBody = lowerPhysicsBody
            
            let positionMean: CGFloat = self.size.height / 2
            let position: CGFloat = positionMean + CGFloat(self.obstaclePositionRandomSource.nextUniform()) * obstaclePositionVariance
            upperObstacle.position = CGPoint(x: 0, y: position + obstacleGap / 2)
            lowerObstacle.position = CGPoint(x: 0, y: position - obstacleGap / 2)
            
            let scoreLine = SKNode()
            let scorePhysicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: upperObstacle.size.width, y: 0), to: CGPoint(x: 0, y: self.size.height))
            scorePhysicsBody.categoryBitMask = CollisionCategory.score
            scoreLine.physicsBody = scorePhysicsBody
            
            let node = SKNode()
            node.addChild(upperObstacle)
            node.addChild(lowerObstacle)
            node.addChild(scoreLine)
            
            node.run(self.moveObstacle)
            self.obstacles.addChild(node)
        }
    }()
    fileprivate lazy var moveObstacle: SKAction = {
        let distance: CGFloat = self.size.width + self.upperObstacleTexture.size().width
        return .sequence([
            .move(to: CGPoint(x: self.size.width, y: 0), duration: 0),
            .move(by: CGVector(dx: -distance, dy: 0), duration: Double(distance / obstacleSpeed)),
            .removeFromParent(),
        ])
    }()
    fileprivate lazy var spawnObstaclesForever: SKAction = {
        .repeatForever(.sequence([
            self.spawnObstacle,
            .wait(forDuration: obstacleSpawnDelay),
        ]))
    }()

    private let groundTexture = SKTexture(imageNamed: "ground")

    fileprivate lazy var ground: SKNode = {
        let node = SKNode()
        for i in (0...Int(ceil(self.size.width / self.groundTexture.size().width))) {
            let sprite = SKSpriteNode(texture: self.groundTexture)
            let physicsBody = SKPhysicsBody(edgeLoopFrom: sprite.frame)
            physicsBody.categoryBitMask = CollisionCategory.world
            sprite.physicsBody = physicsBody
            sprite.position = CGPoint(x: CGFloat(i) * self.groundTexture.size().width, y: 0)
            node.addChild(sprite)
        }
        node.run(.repeatForever(self.moveGround))
        return node
    }()
    fileprivate lazy var moveGround: SKAction = {
        let distance: CGFloat = self.groundTexture.size().width
        return SKAction.sequence([
            .move(by: CGVector(dx: -distance, dy: 0), duration: Double(distance / obstacleSpeed)),
            .move(by: CGVector(dx: distance, dy: 0), duration: 0),
        ])
    }()

    private let backgroundTexture = SKTexture(imageNamed: "background")
    fileprivate lazy var background: SKNode = {
        let node = SKNode()
        for i in (0...Int(ceil(self.size.width / self.backgroundTexture.size().width))) {
            let sprite = SKSpriteNode(texture: self.backgroundTexture)
            sprite.position = CGPoint(x: CGFloat(i) * self.backgroundTexture.size().width, y: self.groundTexture.size().height - 2)
            node.addChild(sprite)
        }
        node.run(.repeatForever(self.moveBackground))
        return node
    }()
    fileprivate lazy var moveBackground: SKAction = {
        let distance: CGFloat = self.backgroundTexture.size().width
        return SKAction.sequence([
            .move(by: CGVector(dx: -distance, dy: 0), duration: Double(distance / (obstacleSpeed / 3))),
            .move(by: CGVector(dx: distance, dy: 0), duration: 0),
            ])
    }()
    
    fileprivate let shaking = SKNode()
    
    
    // MARK: Interface Elements
    
    fileprivate lazy var scoreLabel: SKLabelNode = {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.position = CGPoint(x: self.frame.midX, y: self.size.height / 2)
        return label
    }()
    
}


// MARK: - Game States

class GameState: GKState {
    
    let scene: FlyScene
    
    init(scene: FlyScene) {
        self.scene = scene
    }
    
}

class PrepareFlyingState: GameState {
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == FlyingState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        scene.ground.speed = 1
        scene.background.speed = 1
        scene.obstacles.speed = 0
        scene.bird.physicsBody?.isDynamic = false
        scene.bird.position = CGPoint(x: FlyScene.birdPosition, y: scene.size.height / 2)
        // hover animation
        scene.bird.run(scene.birdHover, withKey: "hover")
        scene.bird.run(scene.animateFlappingBird, withKey: "animateFlapping")
    }
    
}

class FlyingState: GameState {
    
    fileprivate var score = 0 {
        didSet {
            scene.scoreLabel.text = String(score)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == GameOverState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        score = 0
        
        scene.ground.speed = 1
        scene.background.speed = 1
        
        scene.bird.removeAction(forKey: "hover")
        scene.bird.physicsBody?.isDynamic = true

        scene.obstacles.run(.sequence([
            .wait(forDuration: 3),
            scene.spawnObstaclesForever,
            ]), withKey: "spawnObstacles")
        scene.obstacles.speed = 1
        
        switch previousState {
        
        case _ as GameOverState:
            scene.obstacles.removeAllChildren()
            scene.bird.run(scene.animateFlappingBird, withKey: "animateFlapping")
            
        default:
            break
        }
    }

}

class GameOverState: GameState {
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == FlyingState.self
    }

    override func didEnter(from previousState: GKState?) {
        scene.ground.speed = 0
        scene.background.speed = 0
        scene.obstacles.speed = 0
        scene.bird.removeAction(forKey: "animateFlapping")
        scene.shaking.run(SKAction.shake(1), withKey: "shaking")
    }

}


// MARK: - Physics Contact Delegate

extension FlyScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        switch (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask) {
            
        case let (a, b) where
            (a & CollisionCategory.bird != 0 && b & CollisionCategory.obstacle != 0) ||
            (b & CollisionCategory.bird != 0 && a & CollisionCategory.obstacle != 0):
            birdDidHitObstacle()
            
        default:
            break
        }
        
    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        switch (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask) {
            
        case let (a, b) where
            (a & CollisionCategory.bird != 0 && b & CollisionCategory.score != 0) ||
            (b & CollisionCategory.bird != 0 && a & CollisionCategory.score != 0):
            increaseScore()
            
        default:
            break
        }
    }
    
}


// MARK: - Shake Action

extension SKAction {
    
    class func shake(_ duration: TimeInterval, amplitudeX: Int = 3, amplitudeY: Int = 3) -> SKAction {
        let shakeDuration: TimeInterval = 0.015
        let numberOfShakes = duration / (shakeDuration * 2)
        var movements: [SKAction] = []
        for _ in (1...Int(numberOfShakes)) {
            let dx = CGFloat(arc4random_uniform(UInt32(amplitudeX))) - CGFloat(amplitudeX / 2)
            let dy = CGFloat(arc4random_uniform(UInt32(amplitudeY))) - CGFloat(amplitudeY / 2)
            let movement = SKAction.moveBy(x: dx, y: dy, duration: shakeDuration)
            movements.append(movement)
            movements.append(movement.reversed())
        }
        return .sequence(movements)
    }
}
