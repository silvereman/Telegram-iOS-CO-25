import Foundation
import UIKit

/// Orientation change handling for liquid glass animations
public final class LiquidGlassOrientationHandler {
    
    // MARK: - Singleton
    
    public static let shared = LiquidGlassOrientationHandler()
    
    private init() {
        setupOrientationObserver()
    }
    
    // MARK: - Orientation Tracking
    
    private var currentOrientation: UIInterfaceOrientation = .portrait
    private var isTransitioning: Bool = false
    private var transitionTimer: Timer?
    private static let transitionThrottleKey = "orientation_transition"
    
    // MARK: - Observer Setup
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationWillChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func orientationWillChange() {
        isTransitioning = true
        
        // Cancel any existing transition timer
        transitionTimer?.invalidate()
        
        // Create new timer for transition end
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.isTransitioning = false
            self?.transitionTimer = nil
        }
    }
    
    // MARK: - Animation Adaptation
    
    /// Check if animations should be paused during orientation change
    public var shouldPauseAnimations: Bool {
        return isTransitioning
    }
    
    /// Adapt animation for orientation transition
    public func adaptAnimation(
        _ animation: CAAnimation,
        for transition: UIViewControllerTransitionCoordinator?
    ) -> CAAnimation {
        guard let transition = transition else { return animation }
        
        // Shorten animation duration during rotation
        if let basicAnimation = animation as? CABasicAnimation {
            basicAnimation.duration = basicAnimation.duration * 0.7
        } else if let springAnimation = animation as? CASpringAnimation {
            springAnimation.duration = springAnimation.duration * 0.7
        }
        
        return animation
    }
    
    /// Force end transition state (useful for testing)
    public func endTransition() {
        isTransitioning = false
        transitionTimer?.invalidate()
        transitionTimer = nil
    }
    
    deinit {
        // Clean up notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Clean up transition timer
        transitionTimer?.invalidate()
        transitionTimer = nil
        
        // Clean up any throttle timers created by this handler
        LiquidGlassPerformance.cancelThrottle(key: Self.transitionThrottleKey)
    }
}

// MARK: - UIView Extension for Orientation-Aware Animations

extension UIView {
    
    /// Perform animation that adapts to orientation changes
    public func performOrientationAwareAnimation(
        duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        let handler = LiquidGlassOrientationHandler.shared
        
        if handler.shouldPauseAnimations {
            // Skip animation during orientation change
            animations()
            completion?(true)
        } else {
            UIView.animate(
                withDuration: duration,
                animations: animations,
                completion: completion
            )
        }
    }
}
