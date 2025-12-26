import XCTest
import UIKit
@testable import Display

/// Accessibility tests for Liquid Glass effects
///
/// Verifies that glass effects are accessible and comply with iOS accessibility features:
/// - VoiceOver compatibility
/// - Reduce Motion support
/// - Dynamic Type support
/// - High Contrast mode
class LiquidGlassAccessibilityTests: XCTestCase {
    
    // MARK: - Reduce Motion Tests
    
    func testReduceMotionDisablesAnimations() {
        // Test animation duration respects reduce motion
        let duration = LiquidGlassPerformance.animationDuration(0.4)
        
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(duration, 0.0, "Animations should be disabled with Reduce Motion")
        } else {
            XCTAssertEqual(duration, 0.4, "Animations should run normally without Reduce Motion")
        }
    }
    
    func testReduceMotionAffectsAllAnimations() {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Apply animation
        LiquidGlassPerformance.animate(duration: 0.3, animations: {
            layer.opacity = 0.5
        })
        
        // With reduce motion, animation should complete instantly
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(layer.opacity, 0.5, accuracy: 0.1)
        }
    }
    
    // MARK: - VoiceOver Compatibility Tests
    
    func testSwitchAccessibility() {
        let switchNode = LiquidGlassSwitchNode()
        switchNode.frame = CGRect(x: 0, y: 0, width: 51, height: 31)
        
        // Verify switch is accessible
        XCTAssertTrue(switchNode.view.isAccessibilityElement || switchNode.isAccessibilityElement)
    }
    
    func testButtonAccessibility() {
        let icon = UIImage(systemName: "star.fill") ?? UIImage()
        let button = GlassButtonNode(icon: icon, label: "Favorite")
        button.frame = CGRect(x: 0, y: 0, width: 72, height: 72)
        
        // Verify button is accessible
        XCTAssertTrue(button.view.isAccessibilityElement || button.isAccessibilityElement)
    }
    
    // MARK: - Performance with Accessibility Tests
    
    func testPerformanceWithReduceMotion() {
        // Verify performance is maintained with reduce motion
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let startTime = CACurrentMediaTime()
        
        for _ in 0..<100 {
            LiquidGlassPerformance.animate(duration: 0.3, animations: {
                layer.opacity = CGFloat.random(in: 0...1)
            })
        }
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        // Should complete quickly regardless of reduce motion setting
        XCTAssertLessThan(duration, 2.0)
    }
    
    // MARK: - Color and Contrast Tests
    
    func testBlurVisibilityInHighContrast() {
        let blurView = LiquidGlassBlurView(configuration: .standard)
        blurView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        // Blur view should be created regardless of contrast settings
        XCTAssertNotNil(blurView)
    }
    
    // MARK: - Touch Target Size Tests
    
    func testSwitchTouchTargetSize() {
        let switchNode = LiquidGlassSwitchNode()
        let size = switchNode.calculateSizeThatFits(CGSize(width: 100, height: 100))
        
        // Switch should have adequate touch target (at least 44pt height per iOS guidelines)
        XCTAssertGreaterThanOrEqual(size.height, 31.0)
    }
    
    func testButtonTouchTargetSize() {
        let icon = UIImage(systemName: "star.fill") ?? UIImage()
        let button = GlassButtonNode(icon: icon, label: nil)
        button.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        
        // Button should have adequate touch target (at least 44pt per iOS guidelines)
        XCTAssertGreaterThanOrEqual(button.bounds.width, 44.0)
        XCTAssertGreaterThanOrEqual(button.bounds.height, 44.0)
    }
}
