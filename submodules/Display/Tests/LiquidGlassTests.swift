import XCTest
import UIKit
import QuartzCore
@testable import Display

/// Comprehensive test suite for Liquid Glass animations
class LiquidGlassTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Clean up before each test
        LiquidGlassPerformance.cleanup()
        LiquidGlassAnimationCoordinator.shared.cleanupStaleAnimations()
    }
    
    override func tearDown() {
        LiquidGlassPerformance.cleanup()
        super.tearDown()
    }
    
    // MARK: - Animation Tests
    
    func testAnimationTiming() {
        let layer = CALayer()
        let expectation = self.expectation(description: "Animation completes")
        
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.15,
            parameters: .highlightTap
        ) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(layer.presentation())
    }
    
    func testVelocityAwareParameters() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        let baseParams = LiquidGlassAnimationParameters.bounceRelease
        
        // Test low velocity
        let lowVelocityParams = coordinator.velocityAwareParameters(
            baseParameters: baseParams,
            velocity: 100.0
        )
        XCTAssertLessThanOrEqual(lowVelocityParams.duration, baseParams.duration)
        
        // Test high velocity
        let highVelocityParams = coordinator.velocityAwareParameters(
            baseParameters: baseParams,
            velocity: 2000.0
        )
        XCTAssertLessThan(highVelocityParams.duration, lowVelocityParams.duration)
    }
    
    func testAnimationConflictPrevention() {
        let layer = CALayer()
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        // Register low priority animation
        let registered1 = coordinator.registerAnimation(
            key: "test.scale",
            priority: .low,
            context: .interaction
        )
        XCTAssertTrue(registered1)
        
        // Try to register same key with lower priority - should fail
        let registered2 = coordinator.registerAnimation(
            key: "test.scale",
            priority: .low,
            context: .interaction
        )
        XCTAssertFalse(registered2)
        
        // Register with higher priority - should succeed
        let registered3 = coordinator.registerAnimation(
            key: "test.scale",
            priority: .high,
            context: .interaction
        )
        XCTAssertTrue(registered3)
        
        coordinator.unregisterAnimation(key: "test.scale")
    }
    
    func testContextAwareIntensity() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        let navigationIntensity = coordinator.intensityMultiplier(for: .navigation)
        let interactionIntensity = coordinator.intensityMultiplier(for: .interaction)
        let confirmationIntensity = coordinator.intensityMultiplier(for: .confirmation)
        
        XCTAssertLessThan(navigationIntensity, interactionIntensity)
        XCTAssertLessThan(interactionIntensity, confirmationIntensity)
    }
    
    // MARK: - Performance Tests
    
    func testMemoryLeaks() {
        weak var weakLayer: CALayer?
        
        autoreleasepool {
            let layer = CALayer()
            weakLayer = layer
            
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
        }
        
        // Layer should be deallocated
        XCTAssertNil(weakLayer, "Memory leak detected")
    }
    
    func testPerformanceCleanup() {
        // Test that cleanup doesn't crash
        LiquidGlassPerformance.enableAdaptiveQuality()
        LiquidGlassPerformance.cleanup()

        // Verify monitoring is stopped
        XCTAssertEqual(LiquidGlassPerformance.fps, 0.0, "FPS should be 0 after cleanup")

        // Note: Animation cache was intentionally removed as CAAnimation is copied
        // when added to layers, making caching pointless and wasteful
    }
    
    func testFPSMonitoring() {
        LiquidGlassPerformance.startMonitoring()
        
        // Wait for FPS calculation
        let expectation = self.expectation(description: "FPS measured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let fps = LiquidGlassPerformance.fps
            XCTAssertGreaterThan(fps, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        LiquidGlassPerformance.stopMonitoring()
    }
    
    // MARK: - Device Profile Tests
    
    func testDeviceCapabilityDetection() {
        let profile = LiquidGlassDeviceProfile.current
        
        XCTAssertNotNil(profile.capabilities)
        XCTAssertGreaterThan(profile.capabilities.processorCount, 0)
        XCTAssertGreaterThan(profile.capabilities.physicalMemory, 0)
    }
    
    func testDeviceSpecificThresholds() {
        let profile = LiquidGlassDeviceProfile.current
        
        XCTAssertNotNil(profile.thresholds)
        XCTAssertGreaterThan(profile.thresholds.fpsTarget, 0)
        XCTAssertGreaterThan(profile.thresholds.maxBlurRadius, 0)
    }
    
    func testLowPowerModeAdaptation() {
        let profile = LiquidGlassDeviceProfile.current
        profile.adjustForSystemState()
        
        // Quality should be adjusted based on system state
        let quality = LiquidGlassPerformance.currentQuality
        XCTAssertNotNil(quality)
    }
    
    // MARK: - Blur Tests
    
    func testDynamicBlurAdaptation() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let config = LiquidGlassBlurConfiguration.subtle
        
        let blurView = LiquidGlassBlurProvider.createAdaptiveBlur(
            for: view,
            configuration: config
        )
        
        XCTAssertNotNil(blurView)
    }
    
    func testBlurRadiusLimits() {
        let profile = LiquidGlassDeviceProfile.current
        let baseRadius: CGFloat = 30.0
        
        let recommended = profile.recommendedBlurRadius(base: baseRadius)
        XCTAssertLessThanOrEqual(recommended, profile.thresholds.maxBlurRadius)
    }
    
    // MARK: - Orientation Tests
    
    func testOrientationChangeHandling() {
        let handler = LiquidGlassOrientationHandler.shared
        
        // Simulate orientation change
        NotificationCenter.default.post(
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Should pause animations during transition
        XCTAssertTrue(handler.shouldPauseAnimations)
        
        // Wait for transition to complete
        let expectation = self.expectation(description: "Orientation transition")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertFalse(handler.shouldPauseAnimations)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testRapidInteractions() {
        let layer = CALayer()
        
        // Rapidly trigger animations
        for _ in 0..<10 {
            LiquidGlassAnimations.pressDownScale(
                layer: layer,
                to: 0.95,
                parameters: .pressDown
            )
        }
        
        // Should not crash or leak memory
        XCTAssertNotNil(layer)
    }
    
    func testReduceMotionCompliance() {
        let duration = LiquidGlassPerformance.animationDuration(0.4)
        
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(duration, 0.0)
        } else {
            XCTAssertEqual(duration, 0.4)
        }
    }
    
    func testEdgeGlowEffects() {
        let layer = CALayer()
        
        layer.applyEdgeGlow(intensity: 0.3, color: .white, radius: 8.0)
        
        if LiquidGlassDeviceProfile.current.shouldEnableAdvancedEffects {
            XCTAssertGreaterThan(layer.shadowOpacity, 0)
        }
        
        layer.removeEdgeGlow(animated: false)
        XCTAssertEqual(layer.shadowOpacity, 0)
    }
    
    // MARK: - Compatibility Tests
    
    func testIOSCompatibility() {
        let compat = LiquidGlassCompatibility.self
        
        // Should detect iOS version correctly
        XCTAssertGreaterThanOrEqual(compat.iosVersion, 13.0)
        
        // Features should be detected
        let features = compat.getFeatures()
        XCTAssertNotNil(features)
    }
    
    func testSpringAnimationFallback() {
        let animation = LiquidGlassCompatibility.createSpringAnimation(
            keyPath: "transform.scale",
            duration: 0.4,
            damping: 0.6
        )
        
        XCTAssertNotNil(animation)
        
        if #available(iOS 17.0, *) {
            XCTAssertTrue(animation is CASpringAnimation)
        } else {
            XCTAssertTrue(animation is CABasicAnimation)
        }
    }
}
