//
//  FlyScene.swift
//  FlappySwift
//
//  Created by Katja D on 13.04.17.
//  Copyright © 2017 iOS Dev Kurs Universität Heidelberg. All rights reserved.
//

import UIKit
import SpriteKit

let worldCollisionCategory: UInt32 = 1 << 1
let obstacleCollisonCategory: UInt32 = 1 << 2
let birdCollisionCategory: UInt32 = 1 << 3

class FlyScene: SKScene, SKPhysicsContactDelegate {
    
    let impulseOnFlap: CGFloat = 500
    
    let bird: SKSpriteNode = {
        let spriteNode = SKSpriteNode(imageNamed: "bird-01")
        let physicsBody = SKPhysicsBody(circleOfRadius: spriteNode.size.width / 2)
        physicsBody.mass = 1
        physicsBody.linearDamping = 0
        physicsBody.restitution = 1
        physicsBody.collisionBitMask = worldCollisionCategory |
            obstacleCollisonCategory
        physicsBody.categoryBitMask = birdCollisionCategory
        physicsBody.contactTestBitMask = obstacleCollisonCategory
        spriteNode.physicsBody = physicsBody
        return spriteNode

    }()
    
    let obstacles: SKNode = {
        let node = SKNode()
        return node
    }()
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        self.physicsWorld.contactDelegate = self
    
        self.addChild(bird)
        bird.position = CGPoint(x: 0, y: 0)
        let physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width:
            self.size.width, height: self.size.height))
        physicsBody.collisionBitMask = worldCollisionCategory
        self.physicsBody = physicsBody
        
        self.addChild(obstacles)
        
        self.obstacles.run(.repeatForever(.sequence([
            .wait(forDuration: 2),
            self.spawnObstacle,
            ])))
        
    }
    
    lazy var spawnObstacle: SKAction = {
        let action = SKAction.run {
            let upperObstacle = SKSpriteNode(imageNamed: "PipeDown")
            let upperPhysicsBody = SKPhysicsBody(edgeLoopFrom:upperObstacle.frame)
            upperPhysicsBody.categoryBitMask = obstacleCollisonCategory
            upperObstacle.physicsBody = upperPhysicsBody
            self.obstacles.addChild(upperObstacle)
            upperObstacle.run(self.moveObstacle)
            
        }
    return action
        
    }()
    
        lazy var moveObstacle: SKAction = {
            let distance: CGFloat = self.size.width
            return .sequence([
                .move(to: CGPoint(x: self.size.width / 2, y: 0), duration: 0),
                .move(by: CGVector(dx: -distance, dy: 0), duration: 3),
                .removeFromParent()
                ])
    }()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if self.speed == 0 {
            self.speed = 1
            self.physicsWorld.speed = 1
            bird.position = CGPoint(x: -100, y: -100)
            bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            for obstacle in obstacles.children {
                obstacle.removeFromParent()
            }
            
        }
        
        bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: impulseOnFlap))
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
       print("Game over!")
        self.speed = 0
        self.physicsWorld.speed = 0
    }
}
