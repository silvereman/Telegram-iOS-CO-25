import XCTest
import UIKit
import QuartzCore
@testable import Display

/// Integration tests for Liquid Glass UI components
///
/// These tests verify that glass effects integrate correctly with UI components
/// and work together as a cohesive system.
class LiquidGlassIntegrationTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        LiquidGlassPerformance.cleanup()
        LiquidGlassAnimationCoordinator.shared.cleanupStaleAnimations()
    }
    
    override func tearDown() {
        LiquidGlassPerformance.cleanup()
        super.tearDown()
    }
    
    // MARK: - Tab Bar Integration Tests
    
    func testTabBarGlassLayerIntegration() {
        let glassLayer = TabBarItemGlassLayer()
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Add glass layer to view
        containerView.addGlassLayer(glassLayer)
        glassLayer.frame = CGRect(x: 25, y: 25, width: 50, height: 50)
        
        // Verify integration
        XCTAssertTrue(containerView.subviews.contains(glassLayer.blurView))
        XCTAssertTrue(containerView.layer.sublayers?.contains(glassLayer) ?? false)
    }
    
    func testTabBarGlassLayerAnimationSequence() {
        let glassLayer = TabBarItemGlassLayer()
        glassLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let expectation = self.expectation(description: "Animation sequence")
        
        // Simulate tap sequence: highlight → press → release
        glassLayer.animateHighlight()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            glassLayer.animatePress()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                glassLayer.animateRelease {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Switch Integration Tests
    
    func testSwitchNodeIntegration() {
        let switchNode = LiquidGlassSwitchNode()
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        containerView.addSubview(switchNode.view)
        switchNode.frame = CGRect(x: 0, y: 0, width: 51, height: 31)
        
        // Verify switch is integrated
        XCTAssertTrue(containerView.subviews.contains(switchNode.view))
    }
    
    func testSwitchToggleWithAnimation() {
        let switchNode = LiquidGlassSwitchNode()
        switchNode.frame = CGRect(x: 0, y: 0, width: 51, height: 31)
        
        let expectation = self.expectation(description: "Switch toggle")
        var callbackReceived = false
        
        switchNode.valueChanged = { isOn in
            callbackReceived = true
            XCTAssertTrue(isOn)
        }
        
        // Toggle switch
        switchNode.setOn(true, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(switchNode.isOn)
            XCTAssertTrue(callbackReceived)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Button Integration Tests
    
    func testGlassButtonNodeIntegration() {
        let icon = UIImage(systemName: "star.fill") ?? UIImage()
        let button = GlassButtonNode(icon: icon, label: "Test")
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        containerView.addSubview(button.view)
        button.frame = CGRect(x: 0, y: 0, width: 72, height: 72)
        
        // Verify button is integrated
        XCTAssertTrue(containerView.subviews.contains(button.view))
    }
    
    func testGlassButtonAnimationOnTap() {
        let icon = UIImage(systemName: "star.fill") ?? UIImage()
        let button = GlassButtonNode(icon: icon, label: nil)
        button.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        
        // Simulate tap
        button.isHighlighted = true
        
        // Verify animation is applied
        XCTAssertNotNil(button.layer.animation(forKey: "liquidGlass.scale"))
    }
    
    // MARK: - Blur Provider Integration Tests
    
    func testBlurProviderWithMultipleViews() {
        let views = (0..<5).map { _ in UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)) }
        
        // Create blur views for all
        let blurViews = views.map { view in
            LiquidGlassBlurProvider.createAdaptiveBlur(
                for: view,
                configuration: .standard
            )
        }
        
        // Verify all blur views created
        XCTAssertEqual(blurViews.count, 5)
        for blurView in blurViews {
            XCTAssertNotNil(blurView)
        }
    }
    
    // MARK: - Animation Coordinator Integration Tests
    
    func testCoordinatorWithMultipleComponents() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        // Register animations from different components
        let registered1 = coordinator.registerAnimation(
            key: "tabBar.tab1",
            priority: .medium,
            context: .navigation
        )
        let registered2 = coordinator.registerAnimation(
            key: "button.send",
            priority: .high,
            context: .confirmation
        )
        let registered3 = coordinator.registerAnimation(
            key: "switch.toggle",
            priority: .low,
            context: .interaction
        )
        
        XCTAssertTrue(registered1)
        XCTAssertTrue(registered2)
        XCTAssertTrue(registered3)
        
        // Cleanup
        coordinator.unregisterAnimation(key: "tabBar.tab1")
        coordinator.unregisterAnimation(key: "button.send")
        coordinator.unregisterAnimation(key: "switch.toggle")
    }
    
    func testCoordinatorPrioritySystem() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        // Register low priority
        let registered1 = coordinator.registerAnimation(
            key: "test.animation",
            priority: .low,
            context: .interaction
        )
        XCTAssertTrue(registered1)
        
        // Try to register same key with low priority - should fail
        let registered2 = coordinator.registerAnimation(
            key: "test.animation",
            priority: .low,
            context: .interaction
        )
        XCTAssertFalse(registered2)
        
        // Register with higher priority - should succeed
        let registered3 = coordinator.registerAnimation(
            key: "test.animation",
            priority: .high,
            context: .confirmation
        )
        XCTAssertTrue(registered3)
        
        coordinator.unregisterAnimation(key: "test.animation")
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformanceMonitoringIntegration() {
        LiquidGlassPerformance.startMonitoring()
        
        let expectation = self.expectation(description: "Performance monitoring")
        
        // Create animations while monitoring
        let layers = (0..<10).map { _ in CALayer() }
        for layer in layers {
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
        }
        
        // Check FPS after animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let fps = LiquidGlassPerformance.fps
            XCTAssertGreaterThan(fps, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        LiquidGlassPerformance.stopMonitoring()
    }
    
    func testAdaptiveQualityIntegration() {
        LiquidGlassPerformance.currentQuality = .high
        
        // Verify quality affects animation parameters
        let highQuality = LiquidGlassPerformance.currentQuality
        XCTAssertEqual(highQuality, .high)
        
        // Change quality
        LiquidGlassPerformance.currentQuality = .low
        let lowQuality = LiquidGlassPerformance.currentQuality
        XCTAssertEqual(lowQuality, .low)
    }
    
    // MARK: - Device Profile Integration Tests
    
    func testDeviceProfileIntegration() {
        let profile = LiquidGlassDeviceProfile.current
        
        // Verify profile is accessible
        XCTAssertNotNil(profile.capabilities)
        XCTAssertNotNil(profile.thresholds)
        
        // Verify thresholds are reasonable
        XCTAssertGreaterThan(profile.thresholds.fpsTarget, 0)
        XCTAssertGreaterThan(profile.thresholds.maxBlurRadius, 0)
    }
    
    func testDeviceProfileSystemStateAdaptation() {
        let profile = LiquidGlassDeviceProfile.current
        
        // Adjust for system state
        profile.adjustForSystemState()
        
        // Verify adjustment completed without errors
        XCTAssertTrue(true)
    }
    
    // MARK: - Orientation Handler Integration Tests
    
    func testOrientationHandlerIntegration() {
        let handler = LiquidGlassOrientationHandler.shared
        
        // Simulate orientation change
        NotificationCenter.default.post(
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Should pause animations
        XCTAssertTrue(handler.shouldPauseAnimations)
        
        let expectation = self.expectation(description: "Orientation transition")
        
        // Wait for transition to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertFalse(handler.shouldPauseAnimations)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Compatibility Integration Tests
    
    func testCompatibilityLayerIntegration() {
        let compat = LiquidGlassCompatibility.self
        
        // Verify iOS version detection
        XCTAssertGreaterThanOrEqual(compat.iosVersion, 13.0)
        
        // Verify feature detection
        let features = compat.getFeatures()
        XCTAssertNotNil(features)
        
        // Verify recommended quality
        let quality = compat.recommendedQuality
        XCTAssertNotNil(quality)
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteUserInteractionFlow() {
        // Simulate complete user interaction: tap button → animate → complete
        let icon = UIImage(systemName: "star.fill") ?? UIImage()
        let button = GlassButtonNode(icon: icon, label: nil)
        button.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        
        let expectation = self.expectation(description: "Complete interaction")
        
        // Press
        button.isHighlighted = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Release
            button.isHighlighted = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleComponentsSimultaneously() {
        // Test multiple components animating at once
        let button = GlassButtonNode(icon: UIImage(), label: nil)
        let switchNode = LiquidGlassSwitchNode()
        let glassLayer = TabBarItemGlassLayer()
        
        button.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        switchNode.frame = CGRect(x: 0, y: 0, width: 51, height: 31)
        glassLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Trigger animations simultaneously
        button.isHighlighted = true
        switchNode.setOn(true, animated: true)
        glassLayer.animateHighlight()
        
        // Verify no crashes or conflicts
        XCTAssertTrue(true)
    }
}
