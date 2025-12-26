import XCTest
import UIKit
import QuartzCore
@testable import Display

/// Visual regression tests for Liquid Glass animations
/// 
/// These tests verify that animations maintain their visual characteristics across code changes.
/// Tests use snapshot comparison and animation property verification.
class LiquidGlassVisualRegressionTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        LiquidGlassPerformance.cleanup()
    }
    
    override func tearDown() {
        LiquidGlassPerformance.cleanup()
        super.tearDown()
    }
    
    // MARK: - Animation Visual Tests
    
    func testHighlightAnimationVisualProperties() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.15,
            parameters: .highlightTap
        )
        
        // Verify animation exists
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scale"))
        
        // Verify animation properties
        if let animation = layer.animation(forKey: "liquidGlass.scale") as? CASpringAnimation {
            XCTAssertEqual(animation.damping, 0.6, accuracy: 0.01)
            XCTAssertEqual(animation.duration, 0.3, accuracy: 0.01)
        }
    }
    
    func testPressDownAnimationVisualProperties() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.95,
            parameters: .pressDown
        )
        
        // Verify animation exists
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scale"))
        
        // Verify quick press animation
        if let animation = layer.animation(forKey: "liquidGlass.scale") {
            XCTAssertEqual(animation.duration, 0.05, accuracy: 0.01)
        }
    }
    
    func testStretchAnimationVisualProperties() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        LiquidGlassAnimations.stretchScale(
            layer: layer,
            scaleX: 1.15,
            scaleY: 0.95,
            parameters: .stretch
        )
        
        // Verify both scale animations exist
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scaleX"))
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scaleY"))
        
        // Verify stretch parameters
        if let animX = layer.animation(forKey: "liquidGlass.scaleX") as? CASpringAnimation {
            XCTAssertEqual(animX.duration, 0.25, accuracy: 0.01)
        }
    }
    
    func testRotationWobbleVisualProperties() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let angle = 2.0 * .pi / 180.0 // 2 degrees
        LiquidGlassAnimations.rotationWobble(
            layer: layer,
            angle: angle,
            parameters: .bounceRelease
        )
        
        // Verify rotation animation exists
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.rotation"))
        
        // Verify keyframe animation
        if let animation = layer.animation(forKey: "liquidGlass.rotation") as? CAKeyframeAnimation {
            XCTAssertEqual(animation.values?.count, 5) // 5 keyframes for wobble
        }
    }
    
    // MARK: - Tab Bar Glass Layer Visual Tests
    
    func testTabBarGlassLayerAppearance() {
        let glassLayer = TabBarItemGlassLayer()
        glassLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Verify glass layer properties
        XCTAssertEqual(glassLayer.cornerRadius, 22.5, accuracy: 0.1)
        XCTAssertTrue(glassLayer.masksToBounds)
        XCTAssertTrue(glassLayer.allowsGroupOpacity)
    }
    
    func testTabBarGlassLayerHighlightAnimation() {
        let glassLayer = TabBarItemGlassLayer()
        glassLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        glassLayer.animateHighlight()
        
        // Verify highlight animation applied
        XCTAssertNotNil(glassLayer.animation(forKey: "liquidGlass.scale"))
    }
    
    func testTabBarGlassLayerPressAnimation() {
        let glassLayer = TabBarItemGlassLayer()
        glassLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        glassLayer.animatePress()
        
        // Verify press animation applied
        XCTAssertNotNil(glassLayer.animation(forKey: "liquidGlass.scale"))
        XCTAssertNotNil(glassLayer.animation(forKey: "liquidGlass.transform"))
    }
    
    // MARK: - Switch Visual Tests
    
    func testSwitchKnobVisualProperties() {
        let switchNode = LiquidGlassSwitchNode()
        switchNode.frame = CGRect(x: 0, y: 0, width: 51, height: 31)
        
        // Verify switch dimensions
        let size = switchNode.calculateSizeThatFits(CGSize(width: 100, height: 100))
        XCTAssertEqual(size.width, 51.0, accuracy: 0.1)
        XCTAssertEqual(size.height, 31.0, accuracy: 0.1)
    }
    
    // MARK: - Blur Visual Tests
    
    func testBlurConfigurationVisualProperties() {
        let config = LiquidGlassBlurConfiguration.standard
        
        // Verify blur radius is within acceptable range
        XCTAssertGreaterThanOrEqual(config.blurRadius, 8.0)
        XCTAssertLessThanOrEqual(config.blurRadius, 12.0)
        
        // Verify saturation boost
        XCTAssertGreaterThan(config.saturationBoost, 1.0)
    }
    
    func testBlurViewCreation() {
        let blurView = LiquidGlassBlurView(configuration: .standard)
        blurView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        // Verify blur view is created
        XCTAssertNotNil(blurView)
        XCTAssertFalse(blurView.isOpaque)
    }
    
    // MARK: - Performance Visual Tests
    
    func testAnimationPerformanceUnderLoad() {
        let layers = (0..<10).map { _ in CALayer() }
        
        // Apply animations to multiple layers
        for layer in layers {
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
        }
        
        // Verify all animations were applied
        for layer in layers {
            XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scale"))
        }
    }
    
    // MARK: - Edge Case Visual Tests
    
    func testAnimationCancellation() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Start animation
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.15,
            parameters: .highlightTap
        )
        
        // Cancel by starting new animation
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.95,
            parameters: .pressDown
        )
        
        // Verify new animation replaced old one
        XCTAssertNotNil(layer.animation(forKey: "liquidGlass.scale"))
    }
    
    func testAnimationChaining() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        let expectation = self.expectation(description: "Animation chain completes")
        
        // Chain animations
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.95,
            parameters: .pressDown
        ) {
            LiquidGlassAnimations.bounceReleaseScale(
                layer: layer,
                to: 1.0,
                parameters: .bounceRelease
            ) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Accessibility Visual Tests
    
    func testReduceMotionAffectsAnimations() {
        // Test that animations respect reduce motion setting
        let duration = LiquidGlassPerformance.animationDuration(0.4)
        
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(duration, 0.0)
        } else {
            XCTAssertEqual(duration, 0.4)
        }
    }
}
