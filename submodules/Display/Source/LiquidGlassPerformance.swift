import Foundation
import UIKit
import QuartzCore

/// Performance monitoring and optimization for liquid glass animations
public final class LiquidGlassPerformance {
    
    // MARK: - Weak Proxy for CADisplayLink
    
    /// Weak proxy to break retain cycle with CADisplayLink
    private class DisplayLinkProxy {
        weak var target: AnyObject?
        let selector: Selector
        
        init(target: AnyObject, selector: Selector) {
            self.target = target
            self.selector = selector
        }
        
        @objc func tick(_ displayLink: CADisplayLink) {
            _ = (target as? LiquidGlassPerformance.Type)?.displayLinkTick(displayLink)
        }
    }
    
    // MARK: - Performance Monitoring

    private static var fpsDisplayLink: CADisplayLink?
    private static var displayLinkProxy: DisplayLinkProxy?
    private static var frameCount: Int = 0
    private static var lastTimestamp: CFTimeInterval = 0
    private static var currentFPS: Double = 60.0

    // Store notification observers to remove them properly
    private static var notificationObservers: [NSObjectProtocol] = []
    private static var adaptiveQualityTimer: Timer?
    
    /// Current frames per second
    public static var fps: Double {
        return currentFPS
    }
    
    /// Start monitoring FPS
    public static func startMonitoring() {
        guard fpsDisplayLink == nil else { return }
        
        // Use weak proxy to prevent retain cycle
        let proxy = DisplayLinkProxy(target: self, selector: #selector(DisplayLinkProxy.tick(_:)))
        displayLinkProxy = proxy
        
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        displayLink.add(to: .main, forMode: .common)
        fpsDisplayLink = displayLink
        lastTimestamp = CACurrentMediaTime()
    }
    
    /// Stop monitoring FPS
    public static func stopMonitoring() {
        fpsDisplayLink?.invalidate()
        fpsDisplayLink = nil
        displayLinkProxy = nil
        frameCount = 0
    }
    
    @objc private static func displayLinkTick(_ displayLink: CADisplayLink) {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastTimestamp
        
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = currentTime
        }
    }
    
    // MARK: - Animation Quality Management
    
    public enum AnimationQuality {
        case high      // Full animations, 60fps target
        case medium    // Reduced complexity, 30fps acceptable
        case low       // Minimal animations, performance priority
    }
    
    private static var _currentQuality: AnimationQuality = .high
    public static var currentQuality: AnimationQuality {
        get { return _currentQuality }
        set {
            _currentQuality = newValue
            applyQualitySettings(newValue)
        }
    }
    
    private static func applyQualitySettings(_ quality: AnimationQuality) {
        switch quality {
        case .high:
            CATransaction.setAnimationDuration(0.4)
        case .medium:
            CATransaction.setAnimationDuration(0.3)
        case .low:
            CATransaction.setAnimationDuration(0.2)
        }
    }
    
    /// Automatically adjust quality based on FPS
    public static func enableAdaptiveQuality(fpsThreshold: Double = 45.0) {
        startMonitoring()

        // Initialize device profile
        let deviceProfile = LiquidGlassDeviceProfile.current
        deviceProfile.adjustForSystemState()

        // Monitor for low power mode changes - store observer reference
        let powerObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            deviceProfile.adjustForSystemState()
        }
        notificationObservers.append(powerObserver)

        // Add memory warning observer to clear caches - store observer reference
        let memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Clear blur caches on memory warning
            LiquidGlassBlurProvider.clearBlurCache()
            print("[LiquidGlass] Performance: Cleared caches due to memory warning")
        }
        notificationObservers.append(memoryObserver)

        // Store timer reference for cleanup
        adaptiveQualityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Adjust for system state (low power, thermal)
            deviceProfile.adjustForSystemState()

            // Adjust based on FPS
            if currentFPS < fpsThreshold {
                if currentQuality == .high {
                    currentQuality = .medium
                    print("[LiquidGlass] Performance: Reduced to medium quality (FPS: \(Int(currentFPS)))")
                } else if currentQuality == .medium && currentFPS < 30.0 {
                    currentQuality = .low
                    print("[LiquidGlass] Performance: Reduced to low quality (FPS: \(Int(currentFPS)))")
                }
            } else if currentFPS > fpsThreshold + 10.0 {
                if currentQuality == .low {
                    currentQuality = .medium
                    print("[LiquidGlass] Performance: Increased to medium quality (FPS: \(Int(currentFPS)))")
                } else if currentQuality == .medium && currentFPS > 55.0 {
                    currentQuality = .high
                    print("[LiquidGlass] Performance: Increased to high quality (FPS: \(Int(currentFPS)))")
                }
            }
        }
    }
    
    // MARK: - Memory Management
    // Note: Animation cache removed - CAAnimation is copied when added to layer,
    // so caching the original animation object is pointless and wastes memory.
    
    // MARK: - Layer Optimization
    
    /// Optimize layer for animations
    public static func optimizeLayer(_ layer: CALayer) {
        layer.shouldRasterize = false
        layer.rasterizationScale = UIScreen.main.scale
        layer.drawsAsynchronously = true
        
        // Enable edge antialiasing for smooth animations
        layer.allowsEdgeAntialiasing = true
        
        // Disable unnecessary features
        layer.needsDisplayOnBoundsChange = false
    }
    
    /// Prepare layer for animation
    public static func prepareForAnimation(_ layer: CALayer) {
        // Disable implicit animations
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAllAnimations()
        CATransaction.commit()
    }
    
    // MARK: - Batch Animation
    
    /// Execute multiple animations in a single transaction
    public static func batchAnimations(_ animations: () -> Void, completion: (() -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        animations()
        CATransaction.commit()
    }
    
    // MARK: - Reduce Motion Support
    
    /// Check if reduce motion is enabled
    public static var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    /// Get animation duration respecting reduce motion
    public static func animationDuration(_ duration: TimeInterval) -> TimeInterval {
        return isReduceMotionEnabled ? 0.0 : duration
    }
    
    /// Execute animation respecting reduce motion
    public static func animate(
        duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        if isReduceMotionEnabled {
            animations()
            completion?()
        } else {
            UIView.animate(withDuration: duration, animations: animations) { _ in
                completion?()
            }
        }
    }
    
    // MARK: - Performance Metrics
    
    public struct Metrics {
        public let fps: Double
        public let quality: AnimationQuality
        public let cacheSize: Int
        public let reduceMotionEnabled: Bool
        
        public var description: String {
            return """
            Liquid Glass Performance Metrics:
            - FPS: \(Int(fps))
            - Quality: \(quality)
            - Cache Size: \(cacheSize)
            - Reduce Motion: \(reduceMotionEnabled)
            """
        }
    }
    
    /// Get current performance metrics
    public static func getMetrics() -> Metrics {
        return Metrics(
            fps: currentFPS,
            quality: currentQuality,
            cacheSize: 0, // Animation cache removed as it was pointless
            reduceMotionEnabled: isReduceMotionEnabled
        )
    }
    
    // MARK: - Throttling
    
    private static var throttleTimers: [String: Timer] = [:]
    
    /// Throttle function execution
    public static func throttle(key: String, interval: TimeInterval, action: @escaping () -> Void) {
        throttleTimers[key]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
            throttleTimers.removeValue(forKey: key)
        }
        
        throttleTimers[key] = timer
    }
    
    /// Cancel a specific throttle timer
    public static func cancelThrottle(key: String) {
        throttleTimers[key]?.invalidate()
        throttleTimers.removeValue(forKey: key)
    }
    
    // MARK: - Cleanup
    
    /// Clean up all performance monitoring resources
    public static func cleanup() {
        stopMonitoring()

        // Invalidate and clear adaptive quality timer
        adaptiveQualityTimer?.invalidate()
        adaptiveQualityTimer = nil

        // Remove all notification observers
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        // Clean up throttle timers
        throttleTimers.values.forEach { $0.invalidate() }
        throttleTimers.removeAll()
    }
}
