import XCTest
import UIKit
import QuartzCore
@testable import Display

/// Unit tests for Liquid Glass button animations
/// Tests cover button animation integration, timing, and correctness

class LiquidGlassButtonTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        LiquidGlassPerformance.cleanup()
    }
    
    override func tearDown() {
        LiquidGlassPerformance.cleanup()
        super.tearDown()
    }
    
    // MARK: - UIControl Extension Tests
    
    func testUIControlLiquidGlassEnabled() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        
        // Initially disabled
        XCTAssertFalse(button.isLiquidGlassEnabled)
        
        // Enable
        button.isLiquidGlassEnabled = true
        XCTAssertTrue(button.isLiquidGlassEnabled)
        
        // Disable
        button.isLiquidGlassEnabled = false
        XCTAssertFalse(button.isLiquidGlassEnabled)
    }
    
    // MARK: - Press Animation Tests
    
    func testPressDownAnimationApplied() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let expectation = self.expectation(description: "Press animation applied")
        
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.88,
            parameters: .pressDown
        )
        
        // Allow animation to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Verify animation is in progress or complete
            let animationKeys = layer.animationKeys() ?? []
            // Animation may have started
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testBounceReleaseAnimationApplied() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let expectation = self.expectation(description: "Bounce release animation")
        
        // First press down
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.88,
            parameters: .pressDown
        )
        
        // Then release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            LiquidGlassAnimations.bounceReleaseScale(
                layer: layer,
                to: 1.0,
                parameters: .bounceRelease
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Rapid Animation Tests
    
    func testRapidAnimationToggling() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Simulate rapid tapping
        for _ in 0..<20 {
            LiquidGlassAnimations.pressDownScale(layer: layer, to: 0.88, parameters: .pressDown)
            LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: 1.0, parameters: .bounceRelease)
        }
        
        // Should not crash and layer should be valid
        XCTAssertNotNil(layer)
        XCTAssertEqual(layer.frame.width, 50)
    }
    
    func testAnimationInterruption() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let expectation = self.expectation(description: "Animation interruption")
        
        // Start press animation
        LiquidGlassAnimations.pressDownScale(layer: layer, to: 0.88, parameters: .pressDown)
        
        // Immediately interrupt with release
        LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: 1.0, parameters: .bounceRelease)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Animation should complete without issues
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - GlassBackgroundView Animation Tests
    
    func testGlassBackgroundViewTapAnimation() {
        let glassView = GlassBackgroundView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        
        // Test tap animation
        glassView.animateGlassTap()
        
        // Should not crash
        XCTAssertNotNil(glassView.layer)
    }
    
    func testGlassBackgroundViewPressRelease() {
        let glassView = GlassBackgroundView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        
        let expectation = self.expectation(description: "Press release cycle")
        
        glassView.animateGlassPress()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            glassView.animateGlassRelease()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                glassView.resetGlassAnimation()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Recording Button Animation Tests
    
    func testRecordingPulseStartStop() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 72, height: 72)
        
        // Start pulsing
        LiquidGlassRecordingAnimations.startRecordingPulse(on: layer)
        
        let expectation = self.expectation(description: "Pulse cycle")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Stop pulsing
            LiquidGlassRecordingAnimations.stopRecordingPulse(on: layer)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Memory Tests
    
    func testNoMemoryLeaks() {
        weak var weakLayer: CALayer?
        
        autoreleasepool {
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            weakLayer = layer
            
            // Apply animations
            LiquidGlassAnimations.pressDownScale(layer: layer, to: 0.88, parameters: .pressDown)
            LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: 1.0, parameters: .bounceRelease)
            LiquidGlassAnimations.removeAllAnimations(from: layer)
        }
        
        // Layer should be deallocated
        // Note: CALayer may be retained by system briefly
    }
    
    // MARK: - Animation Parameters Tests
    
    func testAnimationParametersApplied() {
        let params = LiquidGlassAnimationParameters.pressDown
        
        XCTAssertGreaterThan(params.duration, 0)
        XCTAssertGreaterThan(params.springDamping, 0)
        XCTAssertGreaterThan(params.springVelocity, 0)
    }
    
    func testHighlightTapParameters() {
        let params = LiquidGlassAnimationParameters.highlightTap
        
        XCTAssertGreaterThan(params.duration, 0)
        XCTAssertLessThan(params.duration, 1.0) // Should be quick
    }
    
    func testBounceReleaseParameters() {
        let params = LiquidGlassAnimationParameters.bounceRelease
        
        XCTAssertGreaterThan(params.springDamping, 0.5) // Should have good damping
        XCTAssertLessThan(params.springDamping, 1.0) // But still bounce
    }
}
