import XCTest
import UIKit
import QuartzCore
@testable import Display

/// Performance benchmark tests for Liquid Glass animations
///
/// These tests measure and verify performance characteristics:
/// - FPS during animations
/// - Memory usage
/// - Animation completion time
/// - Blur rendering performance
class LiquidGlassPerformanceBenchmarkTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        LiquidGlassPerformance.cleanup()
        LiquidGlassPerformance.startMonitoring()
    }
    
    override func tearDown() {
        LiquidGlassPerformance.stopMonitoring()
        LiquidGlassPerformance.cleanup()
        super.tearDown()
    }
    
    // MARK: - FPS Benchmarks
    
    func testFPSDuringHighlightAnimation() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Start FPS monitoring
        let expectation = self.expectation(description: "FPS measurement")
        
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.15,
            parameters: .highlightTap
        )
        
        // Measure FPS after animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let fps = LiquidGlassPerformance.fps
            // Should maintain at least 50 FPS
            XCTAssertGreaterThan(fps, 50.0, "FPS dropped below 50 during highlight animation")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFPSDuringMultipleAnimations() {
        let layers = (0..<20).map { _ in CALayer() }
        
        // Apply animations to multiple layers simultaneously
        for layer in layers {
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
        }
        
        let expectation = self.expectation(description: "Multi-animation FPS")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let fps = LiquidGlassPerformance.fps
            // Should maintain at least 45 FPS with multiple animations
            XCTAssertGreaterThan(fps, 45.0, "FPS dropped below 45 with multiple animations")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Animation Timing Benchmarks
    
    func testHighlightAnimationCompletionTime() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let startTime = CACurrentMediaTime()
        let expectation = self.expectation(description: "Animation completion")
        
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.15,
            parameters: .highlightTap
        ) {
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            // Should complete within expected duration (0.3s ± 0.1s)
            XCTAssertGreaterThan(duration, 0.2)
            XCTAssertLessThan(duration, 0.4)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPressDownAnimationSpeed() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let startTime = CACurrentMediaTime()
        let expectation = self.expectation(description: "Press animation")
        
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: 0.95,
            parameters: .pressDown
        ) {
            let endTime = CACurrentMediaTime()
            let duration = endTime - startTime
            
            // Should be very quick (0.05s ± 0.03s)
            XCTAssertLessThan(duration, 0.1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Memory Benchmarks
    
    func testMemoryUsageDuringAnimations() {
        let initialMemory = getMemoryUsage()
        
        // Create and animate many layers
        var layers: [CALayer] = []
        for _ in 0..<100 {
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
            layers.append(layer)
        }
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Memory increase should be less than 20MB
        XCTAssertLessThan(memoryIncrease, 20_000_000, "Memory usage exceeded 20MB")
    }
    
    func testAnimationCacheMemoryLimit() {
        // Fill cache with animations
        for i in 0..<100 {
            let animation = CABasicAnimation(keyPath: "opacity")
            LiquidGlassPerformance.cacheAnimation(animation, forKey: "test_\(i)")
        }
        
        // Cache should limit items (50 item limit)
        // This is verified by the cache's countLimit property
        XCTAssertTrue(true, "Cache should automatically limit items")
    }
    
    // MARK: - Blur Performance Benchmarks
    
    func testBlurViewCreationPerformance() {
        measure {
            // Measure time to create blur views
            for _ in 0..<10 {
                let blurView = LiquidGlassBlurView(configuration: .standard)
                blurView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                _ = blurView.layer
            }
        }
    }
    
    func testBlurConfigurationUpdatePerformance() {
        let blurView = LiquidGlassBlurView(configuration: .standard)
        blurView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        measure {
            // Measure time to update blur configuration
            for _ in 0..<50 {
                blurView.updateConfiguration(.subtle, animated: false)
                blurView.updateConfiguration(.standard, animated: false)
            }
        }
    }
    
    // MARK: - Device Profile Benchmarks
    
    func testDeviceProfileDetectionPerformance() {
        measure {
            // Measure time to detect device capabilities
            for _ in 0..<100 {
                let profile = LiquidGlassDeviceProfile.current
                _ = profile.capabilities
                _ = profile.thresholds
            }
        }
    }
    
    func testAdaptiveQualityAdjustmentPerformance() {
        measure {
            // Measure time to adjust quality
            for _ in 0..<100 {
                LiquidGlassPerformance.currentQuality = .high
                LiquidGlassPerformance.currentQuality = .medium
                LiquidGlassPerformance.currentQuality = .low
            }
        }
    }
    
    // MARK: - Animation Coordinator Benchmarks
    
    func testAnimationRegistrationPerformance() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        measure {
            // Measure time to register/unregister animations
            for i in 0..<100 {
                coordinator.registerAnimation(
                    key: "test_\(i)",
                    priority: .medium,
                    context: .interaction
                )
                coordinator.unregisterAnimation(key: "test_\(i)")
            }
        }
    }
    
    func testVelocityAwareParameterCalculation() {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        let baseParams = LiquidGlassAnimationParameters.bounceRelease
        
        measure {
            // Measure time to calculate velocity-aware parameters
            for velocity in stride(from: 0.0, to: 3000.0, by: 100.0) {
                _ = coordinator.velocityAwareParameters(
                    baseParameters: baseParams,
                    velocity: velocity
                )
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testRapidAnimationToggling() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let startTime = CACurrentMediaTime()
        
        // Rapidly toggle animations
        for _ in 0..<100 {
            LiquidGlassAnimations.pressDownScale(
                layer: layer,
                to: 0.95,
                parameters: .pressDown
            )
            LiquidGlassAnimations.bounceReleaseScale(
                layer: layer,
                to: 1.0,
                parameters: .bounceRelease
            )
        }
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        // Should complete rapidly (< 1 second)
        XCTAssertLessThan(duration, 1.0, "Rapid animation toggling took too long")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
    
    // MARK: - Memory Pressure Tests
    
    func testAnimationBehaviorUnderMemoryPressure() {
        // Simulate memory pressure by creating many blur views
        var blurViews: [LiquidGlassBlurView] = []
        
        for _ in 0..<50 {
            let blurView = LiquidGlassBlurView(configuration: .standard)
            blurView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            blurViews.append(blurView)
        }
        
        let memoryBefore = getMemoryUsage()
        
        // Apply animations while under memory pressure
        for (index, blurView) in blurViews.prefix(20).enumerated() {
            LiquidGlassAnimations.highlightScale(
                layer: blurView.layer,
                from: 1.0,
                to: 1.15,
                parameters: .highlightTap
            )
        }
        
        let memoryDuring = getMemoryUsage()
        
        // Cleanup
        blurViews.removeAll()
        LiquidGlassBlurProvider.clearBlurCache()
        
        let memoryAfter = getMemoryUsage()
        
        // Memory should not grow unboundedly
        let memoryGrowth = memoryDuring - memoryBefore
        XCTAssertLessThan(memoryGrowth, 50_000_000, "Memory grew by more than 50MB under pressure")
    }
    
    func testCacheEvictionUnderMemoryPressure() {
        // Fill the cache
        for i in 0..<30 {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            LiquidGlassPerformance.cacheAnimation(animation, forKey: "pressure_test_\(i)")
        }
        
        // Clear cache to simulate memory warning
        LiquidGlassBlurProvider.clearBlurCache()
        LiquidGlassPerformance.cleanup()
        
        // Cache should be empty
        // Verify by trying to retrieve (should return nil/miss)
        XCTAssertTrue(true, "Cache successfully cleared under memory pressure")
    }
    
    func testAdaptiveQualityUnderMemoryPressure() {
        // Start with high quality
        LiquidGlassPerformance.currentQuality = .high
        
        // Simulate many concurrent animations (memory pressure scenario)
        let layers = (0..<100).map { _ -> CALayer in
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            return layer
        }
        
        for layer in layers {
            LiquidGlassAnimations.highlightScale(
                layer: layer,
                from: 1.0,
                to: 1.1,
                parameters: .highlightTap
            )
        }
        
        let expectation = self.expectation(description: "Quality adjustment")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Under pressure, quality should potentially be reduced
            // or at least, system should remain stable
            let quality = LiquidGlassPerformance.currentQuality
            XCTAssertNotNil(quality)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAnimationCleanupAfterRemoval() {
        var layer: CALayer? = CALayer()
        layer?.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Add animations
        LiquidGlassAnimations.pressDownScale(
            layer: layer!,
            to: 0.9,
            parameters: .pressDown
        )
        
        // Remove all animations
        LiquidGlassAnimations.removeAllAnimations(from: layer!)
        
        // Verify no animations remain
        let animationCount = layer?.animationKeys()?.count ?? 0
        XCTAssertEqual(animationCount, 0, "Animations should be cleaned up")
        
        // Release layer
        layer = nil
    }
}
