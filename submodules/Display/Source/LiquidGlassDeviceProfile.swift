import Foundation
import UIKit
import QuartzCore

/// Device-specific optimization profiles for liquid glass effects
public final class LiquidGlassDeviceProfile {
    
    // MARK: - Singleton
    
    public static let current = LiquidGlassDeviceProfile()
    
    private init() {
        detectDeviceCapabilities()
        setupOptimalThresholds()
    }
    
    // MARK: - Device Capabilities
    
    public struct DeviceCapabilities {
        public let processorCount: Int
        public let physicalMemory: UInt64
        public let supportsMetalBlur: Bool
        public let screenScale: CGFloat
        public let deviceModel: String
        public let performanceTier: PerformanceTier
    }
    
    public enum PerformanceTier {
        case high       // iPhone 13 Pro and newer
        case medium     // iPhone 11-13, iPhone SE 3rd gen
        case low        // iPhone SE 2nd gen and older
    }
    
    private(set) public var capabilities: DeviceCapabilities!
    
    // MARK: - Optimal Thresholds
    
    public struct OptimalThresholds {
        public let fpsTarget: Double
        public let fpsLowThreshold: Double
        public let maxBlurRadius: CGFloat
        public let animationQuality: LiquidGlassPerformance.AnimationQuality
        public let enableAdvancedEffects: Bool
        public let cacheSize: Int
    }
    
    private(set) public var thresholds: OptimalThresholds!
    
    // MARK: - Device Detection

    private func detectDeviceCapabilities() {
        let processInfo = ProcessInfo.processInfo
        let processorCount = processInfo.processorCount
        let physicalMemory = processInfo.physicalMemory
        let screenScale = UIScreen.main.scale

        // Detect Metal blur support (iOS 16+)
        let supportsMetalBlur: Bool
        if #available(iOS 16.0, *) {
            supportsMetalBlur = true
        } else {
            supportsMetalBlur = false
        }

        // Get device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Determine performance tier using device model parsing
        let performanceTier = parsePerformanceTier(from: deviceModel, cpuCount: processorCount, memory: physicalMemory)

        capabilities = DeviceCapabilities(
            processorCount: processorCount,
            physicalMemory: physicalMemory,
            supportsMetalBlur: supportsMetalBlur,
            screenScale: screenScale,
            deviceModel: deviceModel,
            performanceTier: performanceTier
        )
    }

    /// Parse device model string to determine performance tier
    /// This provides more accurate tier assignment than CPU/RAM alone
    private func parsePerformanceTier(from model: String, cpuCount: Int, memory: UInt64) -> PerformanceTier {
        // iPhone models
        if model.hasPrefix("iPhone") {
            // Extract major and minor version numbers
            let numbers = model.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }

            guard numbers.count >= 2 else {
                return fallbackPerformanceTier(cpuCount: cpuCount, memory: memory)
            }

            let major = numbers[0]
            let minor = numbers[1]

            // iPhone 15 (iPhone15,x) and newer: High tier
            if major >= 16 {
                return .high
            }

            // iPhone 14 Pro (iPhone15,2/3), iPhone 13 Pro (iPhone14,2/3): High tier
            if major == 15 || (major == 14 && (minor == 2 || minor == 3)) {
                return .high
            }

            // iPhone 13 (iPhone14,x), iPhone 12 (iPhone13,x), iPhone 11 (iPhone12,x): Medium tier
            if major >= 12 && major <= 14 {
                return .medium
            }

            // iPhone SE 3rd gen (iPhone14,6): Medium tier
            if major == 14 && minor == 6 {
                return .medium
            }

            // iPhone X (iPhone10,x) and newer: Medium tier
            if major >= 10 {
                return .medium
            }

            // Older iPhones: Low tier
            return .low
        }

        // iPad models
        if model.hasPrefix("iPad") {
            let numbers = model.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }

            guard numbers.count >= 1 else {
                return fallbackPerformanceTier(cpuCount: cpuCount, memory: memory)
            }

            let major = numbers[0]

            // iPad Pro with M1/M2 (iPad13,x and newer): High tier
            if major >= 13 {
                return .high
            }

            // Recent iPad Air and iPad Pro: Medium tier
            if major >= 11 {
                return .medium
            }

            // Older iPads: Low tier
            return .low
        }

        // Fallback to CPU and memory analysis
        return fallbackPerformanceTier(cpuCount: cpuCount, memory: memory)
    }

    /// Fallback tier detection based on hardware specs
    private func fallbackPerformanceTier(cpuCount: Int, memory: UInt64) -> PerformanceTier {
        if cpuCount >= 6 && memory >= 4_000_000_000 {
            return .high
        } else if cpuCount >= 4 && memory >= 3_000_000_000 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Threshold Setup
    
    private func setupOptimalThresholds() {
        let tier = capabilities.performanceTier
        
        switch tier {
        case .high:
            thresholds = OptimalThresholds(
                fpsTarget: 60.0,
                fpsLowThreshold: 55.0,
                maxBlurRadius: 20.0,
                animationQuality: .high,
                enableAdvancedEffects: true,
                cacheSize: 50
            )
            
        case .medium:
            thresholds = OptimalThresholds(
                fpsTarget: 60.0,
                fpsLowThreshold: 45.0,
                maxBlurRadius: 15.0,
                animationQuality: .medium,
                enableAdvancedEffects: true,
                cacheSize: 30
            )
            
        case .low:
            thresholds = OptimalThresholds(
                fpsTarget: 30.0,
                fpsLowThreshold: 25.0,
                maxBlurRadius: 10.0,
                animationQuality: .low,
                enableAdvancedEffects: false,
                cacheSize: 20
            )
        }
    }
    
    // MARK: - Dynamic Adjustments
    
    /// Adjust thresholds based on current system state
    public func adjustForSystemState() {
        // Check low power mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            // Reduce quality in low power mode
            LiquidGlassPerformance.currentQuality = .low
        } else {
            // Use device-appropriate quality
            LiquidGlassPerformance.currentQuality = thresholds.animationQuality
        }
        
        // Check thermal state
        if #available(iOS 11.0, *) {
            let thermalState = ProcessInfo.processInfo.thermalState
            switch thermalState {
            case .critical, .serious:
                // Reduce quality when device is hot
                LiquidGlassPerformance.currentQuality = .low
            case .fair:
                if capabilities.performanceTier == .high {
                    LiquidGlassPerformance.currentQuality = .medium
                }
            default:
                break
            }
        }
    }
    
    /// Get recommended blur radius for current conditions
    public func recommendedBlurRadius(base: CGFloat) -> CGFloat {
        let maxRadius = thresholds.maxBlurRadius
        let clampedBase = min(base, maxRadius)
        
        // Adjust for low power mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return clampedBase * 0.7
        }
        
        return clampedBase
    }
    
    /// Get recommended animation duration
    public func recommendedAnimationDuration(base: TimeInterval) -> TimeInterval {
        switch capabilities.performanceTier {
        case .high:
            return base
        case .medium:
            return base * 0.9
        case .low:
            return base * 0.8
        }
    }
    
    /// Check if advanced effects should be enabled
    public var shouldEnableAdvancedEffects: Bool {
        return thresholds.enableAdvancedEffects &&
               !ProcessInfo.processInfo.isLowPowerModeEnabled &&
               LiquidGlassPerformance.currentQuality != .low
    }
    
    // MARK: - Logging
    
    public func logDeviceInfo() {
        print("""
        [LiquidGlass] Device Profile:
        - Model: \(capabilities.deviceModel)
        - Performance Tier: \(capabilities.performanceTier)
        - Processors: \(capabilities.processorCount)
        - Memory: \(capabilities.physicalMemory / 1_000_000_000)GB
        - Screen Scale: \(capabilities.screenScale)x
        - Metal Blur: \(capabilities.supportsMetalBlur)
        - FPS Target: \(thresholds.fpsTarget)
        - Max Blur Radius: \(thresholds.maxBlurRadius)pt
        - Animation Quality: \(thresholds.animationQuality)
        - Advanced Effects: \(thresholds.enableAdvancedEffects)
        """)
    }
}

// MARK: - Dynamic Blur Adaptation

extension LiquidGlassBlurProvider {
    
    /// Create adaptive blur that adjusts to background brightness
    public static func createAdaptiveBlur(
        for view: UIView,
        configuration: LiquidGlassBlurConfiguration
    ) -> UIVisualEffectView {
        // Detect background brightness
        let brightness = detectBackgroundBrightness(for: view)
        
        // Adjust blur radius based on brightness
        var adaptedConfig = configuration
        if brightness < 0.3 {
            // Dark background - increase blur for visibility
            adaptedConfig.blurRadius = min(configuration.blurRadius * 1.3, LiquidGlassDeviceProfile.current.thresholds.maxBlurRadius)
        } else if brightness > 0.7 {
            // Light background - reduce blur for clarity
            adaptedConfig.blurRadius = configuration.blurRadius * 0.8
        }
        
        // Apply device-specific limits
        adaptedConfig.blurRadius = LiquidGlassDeviceProfile.current.recommendedBlurRadius(base: adaptedConfig.blurRadius)
        
        return createBlurView(configuration: adaptedConfig)
    }
    
    /// Detect average brightness of background
    private static func detectBackgroundBrightness(for view: UIView) -> CGFloat {
        guard let superview = view.superview else { return 0.5 }
        
        // Get background color
        var brightness: CGFloat = 0.5
        
        if let backgroundColor = superview.backgroundColor {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            // Calculate perceived brightness (ITU-R BT.709)
            brightness = (0.2126 * red + 0.7152 * green + 0.0722 * blue)
        }
        
        return brightness
    }
}

// MARK: - Color Tinting

extension LiquidGlassBlurView {
    
    /// Apply subtle color tint from background
    public func applySubtleColorTint(from sourceView: UIView?) {
        guard let sourceView = sourceView,
              LiquidGlassDeviceProfile.current.shouldEnableAdvancedEffects else {
            return
        }
        
        // Extract average color from source
        if let averageColor = extractAverageColor(from: sourceView) {
            // Apply very subtle tint (10% opacity)
            let tintColor = averageColor.withAlphaComponent(0.1)
            self.backgroundColor = tintColor
        }
    }
    
    /// Extract average color from a view
    private func extractAverageColor(from view: UIView) -> UIColor? {
        // For performance, just use the background color if available
        if let backgroundColor = view.backgroundColor, backgroundColor != .clear {
            return backgroundColor
        }
        
        // Could implement more sophisticated color extraction here
        // For now, return nil to avoid performance impact
        return nil
    }
}

// MARK: - Edge Glow Effects

extension CALayer {
    
    /// Add subtle edge glow for interactive states
    public func applyEdgeGlow(
        intensity: CGFloat = 0.3,
        color: UIColor = .white,
        radius: CGFloat = 8.0
    ) {
        guard LiquidGlassDeviceProfile.current.shouldEnableAdvancedEffects else {
            return
        }
        
        self.shadowColor = color.cgColor
        self.shadowOpacity = Float(intensity)
        self.shadowRadius = radius
        self.shadowOffset = .zero
        self.masksToBounds = false
    }
    
    /// Remove edge glow
    public func removeEdgeGlow(animated: Bool = true) {
        if animated {
            let animation = CABasicAnimation(keyPath: "shadowOpacity")
            animation.fromValue = self.shadowOpacity
            animation.toValue = 0.0
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.add(animation, forKey: "removeGlow")
        }
        
        self.shadowOpacity = 0.0
    }
}
