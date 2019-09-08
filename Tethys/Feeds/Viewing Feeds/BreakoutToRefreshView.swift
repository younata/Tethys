//
//  BreakOutToRefreshView.swift
//  PullToRefreshDemo
//
//  Created by dasdom on 17.01.15.
//
//  Copyright (c) 2015 Dominik Hauser <dominik.hauser@dasdom.de>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import SpriteKit

// swiftlint:disable file_length

@objc public protocol BreakOutToRefreshDelegate: class {
    func refreshViewDidRefresh(_ refreshView: BreakOutToRefreshView)
}

public class BreakOutToRefreshView: SKView {

    fileprivate let sceneHeight = CGFloat(100)

    fileprivate let breakOutScene: BreakOutScene
    fileprivate unowned let scrollView: UIScrollView
    @objc public weak var refreshDelegate: BreakOutToRefreshDelegate?
    public var forceEnd = false

    public var isRefreshing = false
    fileprivate var isDragging = false
    fileprivate var isVisible = false

    public var scenebackgroundColor: UIColor {
        didSet {
            self.breakOutScene.scenebackgroundColor = self.scenebackgroundColor
            self.startScene.backgroundColor = self.scenebackgroundColor
        }
    }

    public var textColor: UIColor {
        didSet {
            self.breakOutScene.textColor = self.textColor
            self.startScene.textColor = self.textColor
        }
    }

    public var paddleColor: UIColor {
        didSet {
            self.breakOutScene.paddleColor = self.paddleColor
        }
    }
    public var ballColor: UIColor {
        didSet {
            self.breakOutScene.ballColor = self.ballColor
        }
    }

    public var blockColors: [UIColor] {
        didSet {
            self.breakOutScene.blockColors = self.blockColors
        }
    }

    fileprivate lazy var startScene: StartScene = {
        let size = CGSize(width: self.scrollView.frame.size.width, height: self.sceneHeight)
        let startScene = StartScene(size: size)
        startScene.backgroundColor = self.scenebackgroundColor
        startScene.textColor = self.textColor
        return startScene
    }()

    public override init(frame: CGRect) {
        fatalError("Use init(scrollView:) instead.")
    }

    @objc public init(scrollView inScrollView: UIScrollView) {

        let frame = CGRect(x: 0.0, y: -self.sceneHeight, width: inScrollView.frame.size.width, height: self.sceneHeight)

        self.breakOutScene = BreakOutScene(size: frame.size)
        self.scrollView = inScrollView

        self.scenebackgroundColor = UIColor.white
        self.textColor = UIColor.black
        self.paddleColor = UIColor.gray
        self.ballColor = UIColor.black
        self.blockColors = [
            UIColor(white: 0.2, alpha: 1.0),
            UIColor(white: 0.4, alpha: 1.0),
            UIColor(white: 0.6, alpha: 1.0)
        ]

        self.breakOutScene.scenebackgroundColor = self.scenebackgroundColor
        self.breakOutScene.textColor = self.textColor
        self.breakOutScene.paddleColor = self.paddleColor
        self.breakOutScene.ballColor = self.ballColor
        self.breakOutScene.blockColors = self.blockColors

        super.init(frame: frame)

        self.layer.borderColor = UIColor.gray.cgColor
        self.layer.borderWidth = 1.0

        self.presentScene(startScene)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.breakOutScene.size = self.bounds.size
        self.startScene.size = self.bounds.size
    }

    public func beginRefreshing() {
        self.isRefreshing = true

        self.presentScene(self.breakOutScene, transition: .doorsOpenVertical(withDuration: 0.4))
        self.breakOutScene.updateLabel("Loading...")

        if self.scrollView.contentOffset.y < -60 {
            self.breakOutScene.reset()
            self.breakOutScene.start()
        }
        self.isVisible = true
        UIView.animate(withDuration: 0.4, delay: 0, options: [], animations: { () -> Void in
            if #available(iOS 11.0, *) {
                self.scrollView.contentInset.top += self.sceneHeight + self.scrollView.safeAreaInsets.top
            } else {
                self.scrollView.contentInset.top += self.sceneHeight
            }
        })
    }

    @objc public func endRefreshing() {
        if (!self.isDragging || self.forceEnd) && self.isVisible {
            self.isVisible = false
            UIView.animate(withDuration: 0.4, delay: 0, options: [], animations: { () -> Void in
                if #available(iOS 11.0, *) {
                    self.scrollView.contentInset.top -= self.sceneHeight + self.scrollView.safeAreaInsets.top
                } else {
                    self.scrollView.contentInset.top -= self.sceneHeight
                }
            }, completion: { (_) -> Void in
                self.isRefreshing = false
                self.presentScene(self.startScene, transition: .doorsCloseVertical(withDuration: 0.3))
            })
        } else {
            self.breakOutScene.updateLabel("Loading Finished")
            self.isRefreshing = false
        }
    }
}

extension BreakOutToRefreshView: UIScrollViewDelegate {

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isDragging = true
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.isDragging = false

        if !self.isRefreshing && scrollView.contentOffset.y + scrollView.contentInset.top < -self.sceneHeight {
            self.beginRefreshing()
            targetContentOffset.pointee.y = -scrollView.contentInset.top
            self.refreshDelegate?.refreshViewDidRefresh(self)
        }

        if !self.isRefreshing {
            self.endRefreshing()
        }

    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yPosition = self.sceneHeight - (-scrollView.contentInset.top-scrollView.contentOffset.y)*2

        self.breakOutScene.moveHandle(yPosition)
    }
}

private class BreakOutScene: SKScene, SKPhysicsContactDelegate {

    let ballName = "ball"
    let paddleName = "paddle"
    let blockName = "block"
    let backgroundLabelName = "backgroundLabel"

    let ballCategory: UInt32 = 0x1 << 0
    let backCategory: UInt32 = 0x1 << 1
    let blockCategory: UInt32 = 0x1 << 2
    let paddleCategory: UInt32 = 0x1 << 3

    var contentCreated = false
    var isStarted = false

    var scenebackgroundColor: UIColor! {
        didSet {
            self.backgroundColor = self.scenebackgroundColor
        }
    }
    var textColor: UIColor! {
        didSet {
            guard let labelNode = self.childNode(withName: self.backgroundLabelName) as? SKLabelNode else {
                return
            }
            labelNode.fontColor = self.textColor
        }
    }
    var paddleColor: UIColor!
    var ballColor: UIColor!
    var blockColors: [UIColor]!

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if !self.contentCreated {
            self.createSceneContents()
            self.contentCreated = true
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let ball = self.childNode(withName: ballName) as? SKSpriteNode,
            let physicsBody = ball.physicsBody else {
                return
        }

        let maxSpeed: CGFloat = 600.0
        let speed = sqrt(
            physicsBody.velocity.dx * physicsBody.velocity.dx + physicsBody.velocity.dy * physicsBody.velocity.dy
        )

        if speed > maxSpeed {
            physicsBody.linearDamping = 0.4
        } else {
            physicsBody.linearDamping = 0.0
        }
    }

    func createSceneContents() {
        self.physicsWorld.gravity = CGVector(dx: 0.0, dy: 0.0)
        self.physicsWorld.contactDelegate = self

        self.backgroundColor = self.scenebackgroundColor
        self.scaleMode = .aspectFit

        self.physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        self.physicsBody?.restitution = 1.0
        self.physicsBody?.friction = 0.0
        self.name = "scene"

        let back = SKNode()
        back.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: frame.size.width - 1, y: 0),
                                         to: CGPoint(x: frame.size.width - 1, y: frame.size.height))
        back.physicsBody?.categoryBitMask = self.backCategory
        self.addChild(back)

        self.createLoadingLabelNode()

        let paddle = self.createPaddle()
        paddle.position = CGPoint(x: frame.size.width-30.0, y: frame.midY)
        addChild(paddle)

        self.createBall()
        self.createBlocks()

    }

    func createPaddle() -> SKSpriteNode {
        let paddle = SKSpriteNode(color: self.paddleColor, size: CGSize(width: 5, height: 30))

        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddle.size)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.restitution = 1.0
        paddle.physicsBody?.friction = 0.0

        paddle.name = self.paddleName

        return paddle
    }

    func createBlocks() {
        for i in 0..<3 {
            var color = self.blockColors.count > 0 ? self.blockColors[0] : UIColor(white: 0.2, alpha: 1.0)
            if i == 1 {
                color = self.blockColors.count > 1 ? self.blockColors[1] : UIColor(white: 0.4, alpha: 1.0)
            } else if i == 2 {
                color = self.blockColors.count > 2 ? self.blockColors[2] : UIColor(white: 0.6, alpha: 1.0)
            }

            for j in 0..<5 {
                let block = SKSpriteNode(color: color, size: CGSize(width: 5, height: 19))
                block.position = CGPoint(x: 20+CGFloat(i)*6, y: CGFloat(j)*20 + 10)
                block.name = self.blockName
                block.physicsBody = SKPhysicsBody(rectangleOf: block.size)

                block.physicsBody?.categoryBitMask = self.blockCategory
                block.physicsBody?.allowsRotation = false
                block.physicsBody?.restitution = 1.0
                block.physicsBody?.friction = 0.0
                block.physicsBody?.isDynamic = false

                self.addChild(block)
            }
        }
    }

    func removeBlocks() {
        var node = childNode(withName: self.blockName)
        while node != nil {
            node?.removeFromParent()
            node = childNode(withName: self.blockName)
        }
    }

    func createBall() {
        let ball = SKSpriteNode(color: self.ballColor, size: CGSize(width: 8, height: 8))

        ball.position = CGPoint(
            x: frame.size.width - 30.0 - ball.size.width,
            y: frame.height * CGFloat(arc4random()) / CGFloat(UINT32_MAX)
        )
        ball.name = self.ballName

        ball.physicsBody = SKPhysicsBody(circleOfRadius: ceil(ball.size.width/2.0))
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = self.ballCategory
        ball.physicsBody?.contactTestBitMask = self.blockCategory | self.paddleCategory | self.backCategory
        ball.physicsBody?.allowsRotation = false

        ball.physicsBody?.linearDamping = 0.0
        ball.physicsBody?.restitution = 1.0
        ball.physicsBody?.friction = 0.0

        self.addChild(ball)
    }

    func removeBall() {
        if let ball = childNode(withName: self.ballName) {
            ball.removeFromParent()
        }
    }

    func createLoadingLabelNode() {
        let loadingLabelNode = SKLabelNode(text: "Loading...")
        loadingLabelNode.fontColor = self.textColor
        loadingLabelNode.fontSize = 20
        loadingLabelNode.position = CGPoint(x: frame.midX, y: frame.midY)
        loadingLabelNode.name = self.backgroundLabelName

        self.addChild(loadingLabelNode)
    }

    func reset() {
        self.removeBlocks()
        self.createBlocks()
        self.removeBall()
        self.createBall()
    }

    func start() {
        self.isStarted = true

        let ball = childNode(withName: self.ballName)
        ball?.physicsBody?.applyImpulse(CGVector(dx: -0.5, dy: 0.2))
    }

    func updateLabel(_ text: String) {
        if let label: SKLabelNode = childNode(withName: self.backgroundLabelName) as? SKLabelNode {
            label.text = text
        }
    }

    func moveHandle(_ value: CGFloat) {
        let paddle = childNode(withName: self.paddleName)

        paddle?.position.y = value
    }

    func didEnd(_ contact: SKPhysicsContact) {
        var ballBody: SKPhysicsBody?
        var otherBody: SKPhysicsBody?

        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            ballBody = contact.bodyA
            otherBody = contact.bodyB
        } else {
            ballBody = contact.bodyB
            otherBody = contact.bodyA
        }

        if (otherBody?.categoryBitMask ?? 0) == self.backCategory {
            self.reset()
            self.start()
        } else if ballBody!.categoryBitMask & self.ballCategory != 0 {
            let minimalXVelocity = CGFloat(20.0)
            let minimalYVelocity = CGFloat(20.0)
            var velocity = ballBody!.velocity as CGVector
            if velocity.dx > -minimalXVelocity && velocity.dx <= 0 {
                velocity.dx = -minimalXVelocity-1
            } else if velocity.dx > 0 && velocity.dx < minimalXVelocity {
                velocity.dx = minimalXVelocity+1
            }
            if velocity.dy > -minimalYVelocity && velocity.dy <= 0 {
                velocity.dy = -minimalYVelocity-1
            } else if velocity.dy > 0 && velocity.dy < minimalYVelocity {
                velocity.dy = minimalYVelocity+1
            }
            ballBody?.velocity = velocity
        }

        guard let body = otherBody else { return }
        if (body.categoryBitMask & self.blockCategory != 0) && body.categoryBitMask == self.blockCategory {
            body.node?.removeFromParent()
            if self.isGameWon() {
                self.reset()
                self.start()
            }
        }
    }

    func isGameWon() -> Bool {
        var numberOfBricks = 0
        self.enumerateChildNodes(withName: self.blockName) { _, _ in
            numberOfBricks += 1
        }
        return numberOfBricks == 0
    }
}

private class StartScene: SKScene {
    var contentCreated = false

    var textColor = SKColor.black {
        didSet {
            self.startLabelNode.fontColor = self.textColor
            self.descriptionLabelNode.fontColor = self.textColor
        }
    }

    lazy var startLabelNode: SKLabelNode = {
        let startNode = SKLabelNode(text: "Pull to Break Out!")
        startNode.fontColor = self.textColor
        startNode.fontSize = 20
        startNode.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        startNode.name = "start"

        return startNode
    }()

    lazy var descriptionLabelNode: SKLabelNode = {
        let descriptionNode = SKLabelNode(text: "Scroll to move handle")
        descriptionNode.fontColor = self.textColor
        descriptionNode.fontSize = 17
        descriptionNode.position = CGPoint(x: self.frame.midX, y: self.frame.midY-20)
        descriptionNode.name = "description"

        return descriptionNode
    }()

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if !self.contentCreated {
            self.createSceneContents()
            self.contentCreated = true
        }
    }

    func createSceneContents() {
        self.scaleMode = .aspectFit
        self.addChild(self.startLabelNode)
        self.addChild(self.descriptionLabelNode)
    }
}
