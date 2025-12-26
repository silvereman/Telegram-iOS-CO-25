import Foundation
import UIKit
import QuartzCore

/// iOS version compatibility layer for liquid glass effects
public final class LiquidGlassCompatibility {
    
    // MARK: - iOS Version Detection
    
    public static var iosVersion: Float {
        return (UIDevice.current.systemVersion as NSString).floatValue
    }
    
    public static var isIOS13Available: Bool {
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }
    
    public static var isIOS14Available: Bool {
        if #available(iOS 14.0, *) {
            return true
        }
        return false
    }
    
    public static var isIOS15Available: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }
    
    public static var isIOS16Available: Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }
    
    public static var isIOS17Available: Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }

    public static var isIOS18Available: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }
    
    // MARK: - Animation Compatibility
    
    /// Create spring animation with iOS version compatibility
    /// CASpringAnimation is available since iOS 9.0
    public static func createSpringAnimation(
        keyPath: String,
        duration: TimeInterval,
        damping: CGFloat,
        mass: CGFloat = 1.0,
        stiffness: CGFloat = 100.0,
        initialVelocity: CGFloat = 0.0
    ) -> CAAnimation {
        if #available(iOS 9.0, *) {
            // Use CASpringAnimation for iOS 9+
            let animation = CASpringAnimation(keyPath: keyPath)
            animation.duration = duration
            animation.damping = damping
            animation.mass = mass
            animation.stiffness = stiffness
            animation.initialVelocity = initialVelocity
            return animation
        } else {
            // Fallback to CABasicAnimation for iOS 8 (unlikely but safe)
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return animation
        }
    }
    
    // MARK: - Blur Compatibility

    /// Get appropriate blur effect for iOS version
    public static func blurEffect(style: UIBlurEffect.Style, isDark: Bool) -> UIVisualEffect {
        if #available(iOS 13.0, *) {
            // Use UIBlurEffect with system materials for iOS 13+
            return UIBlurEffect(style: style)
        } else {
            // Fallback for older iOS versions
            return UIBlurEffect(style: .light)
        }
    }

    /// Check if native glass effect is available
    /// Note: As of iOS 18, native UIGlassEffect is not yet available
    /// This implementation uses custom UIBlurEffect-based glass appearance
    public static var hasNativeGlassEffect: Bool {
        return false
    }
    
    // MARK: - Corner Curve Compatibility
    
    /// Set corner curve with compatibility
    public static func setCornerCurve(_ layer: CALayer, continuous: Bool) {
        if #available(iOS 13.0, *) {
            layer.cornerCurve = continuous ? .continuous : .circular
        }
        // No-op for iOS 12 and below
    }
    
    // MARK: - Animation Features
    
    /// Check if advanced spring animations are available
    /// CASpringAnimation has been available since iOS 9
    public static var hasAdvancedSpringAnimations: Bool {
        if #available(iOS 9.0, *) {
            return true
        }
        return false
    }
    
    /// Check if Metal-based blur is available
    public static var hasMetalBlur: Bool {
        return isIOS16Available
    }
    
    /// Check if backdrop filters are available
    public static var hasBackdropFilters: Bool {
        return isIOS17Available
    }
    
    // MARK: - Feature Detection
    
    public struct Features {
        public let springAnimations: Bool
        public let metalBlur: Bool
        public let backdropFilters: Bool
        public let nativeGlass: Bool
        public let continuousCorners: Bool
        
        public var description: String {
            return """
            Liquid Glass Compatibility:
            - iOS Version: \(LiquidGlassCompatibility.iosVersion)
            - Spring Animations: \(springAnimations)
            - Metal Blur: \(metalBlur)
            - Backdrop Filters: \(backdropFilters)
            - Native Glass: \(nativeGlass)
            - Continuous Corners: \(continuousCorners)
            """
        }
    }
    
    /// Get available features for current iOS version
    public static func getFeatures() -> Features {
        return Features(
            springAnimations: hasAdvancedSpringAnimations,
            metalBlur: hasMetalBlur,
            backdropFilters: hasBackdropFilters,
            nativeGlass: hasNativeGlassEffect,
            continuousCorners: isIOS13Available
        )
    }
    
    // MARK: - Fallback Strategies
    
    /// Get recommended animation duration based on iOS version
    public static func recommendedAnimationDuration(base: TimeInterval) -> TimeInterval {
        if isIOS17Available {
            return base
        } else if isIOS15Available {
            return base * 0.9
        } else {
            return base * 0.8
        }
    }
    
    /// Get recommended blur radius based on iOS version
    public static func recommendedBlurRadius(base: CGFloat) -> CGFloat {
        if hasMetalBlur {
            return base
        } else {
            // Reduce blur radius for older devices
            return base * 0.7
        }
    }
    
    // MARK: - Device Capabilities
    
    /// Check if device supports high-performance animations
    public static var supportsHighPerformance: Bool {
        // Check for newer devices with better GPUs
        let processorCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Devices with 4+ cores and 3GB+ RAM
        return processorCount >= 4 && physicalMemory >= 3_000_000_000
    }
    
    /// Get recommended quality based on device
    public static var recommendedQuality: LiquidGlassPerformance.AnimationQuality {
        if supportsHighPerformance && isIOS17Available {
            return .high
        } else if isIOS15Available {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Migration Helpers
    
    /// Migrate animation parameters for compatibility
    public static func migrateAnimationParameters(
        duration: TimeInterval,
        damping: CGFloat,
        velocity: CGFloat
    ) -> (duration: TimeInterval, damping: CGFloat, velocity: CGFloat) {
        if isIOS17Available {
            return (duration, damping, velocity)
        } else {
            // Adjust for older iOS versions
            return (
                duration: duration * 0.9,
                damping: min(damping * 1.1, 1.0),
                velocity: velocity * 0.8
            )
        }
    }
    
    // MARK: - Logging
    
    /// Log compatibility information
    public static func logCompatibilityInfo() {
        let features = getFeatures()
        print(features.description)
        
        print("Device Performance: \(supportsHighPerformance ? "High" : "Standard")")
        print("Recommended Quality: \(recommendedQuality)")
    }
}
