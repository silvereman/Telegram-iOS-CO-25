import Foundation
import UIKit
import QuartzCore

/// Animation coordinator to prevent conflicts and manage animation priorities
public final class LiquidGlassAnimationCoordinator {
    
    // MARK: - Singleton
    
    public static let shared = LiquidGlassAnimationCoordinator()
    
    private init() {}
    
    // MARK: - Animation Priority
    
    public enum AnimationPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        public static func < (lhs: AnimationPriority, rhs: AnimationPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Animation Context
    
    public enum AnimationContext {
        case navigation      // Tab switching, navigation - subtle
        case interaction     // Button taps, switches - medium
        case confirmation    // Important actions - pronounced
        case feedback        // User feedback - immediate
    }
    
    // MARK: - Active Animations Tracking
    
    private struct ActiveAnimation {
        let key: String
        let priority: AnimationPriority
        let context: AnimationContext
        let startTime: CFTimeInterval
    }
    
    private var activeAnimations: [String: ActiveAnimation] = [:]
    private let lock = NSLock()
    
    // MARK: - Animation Management
    
    /// Register an animation before adding it to a layer
    public func registerAnimation(
        key: String,
        priority: AnimationPriority = .normal,
        context: AnimationContext = .interaction
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if there's a conflicting animation
        if let existing = activeAnimations[key] {
            // If new animation has higher priority, allow it
            if priority > existing.priority {
                activeAnimations[key] = ActiveAnimation(
                    key: key,
                    priority: priority,
                    context: context,
                    startTime: CACurrentMediaTime()
                )
                return true
            }
            // Lower or equal priority - reject
            return false
        }
        
        // No conflict, register
        activeAnimations[key] = ActiveAnimation(
            key: key,
            priority: priority,
            context: context,
            startTime: CACurrentMediaTime()
        )
        return true
    }
    
    /// Unregister an animation when it completes
    public func unregisterAnimation(key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        activeAnimations.removeValue(forKey: key)
    }
    
    /// Check if an animation is currently active
    public func isAnimationActive(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return activeAnimations[key] != nil
    }
    
    /// Cancel lower priority animations for a given layer
    public func cancelLowerPriorityAnimations(
        on layer: CALayer,
        thanPriority priority: AnimationPriority
    ) {
        lock.lock()
        let keysToRemove = activeAnimations.filter { $0.value.priority < priority }.map { $0.key }
        lock.unlock()
        
        for key in keysToRemove {
            layer.removeAnimation(forKey: key)
            unregisterAnimation(key: key)
        }
    }
    
    /// Get animation intensity based on context
    public func intensityMultiplier(for context: AnimationContext) -> CGFloat {
        switch context {
        case .navigation:
            return 0.7  // Subtle
        case .interaction:
            return 1.0  // Normal
        case .confirmation:
            return 1.3  // Pronounced
        case .feedback:
            return 1.1  // Slightly enhanced
        }
    }
    
    /// Get animation duration multiplier based on context
    public func durationMultiplier(for context: AnimationContext) -> CGFloat {
        switch context {
        case .navigation:
            return 0.8  // Faster
        case .interaction:
            return 1.0  // Normal
        case .confirmation:
            return 1.2  // Slower, more deliberate
        case .feedback:
            return 0.9  // Quick feedback
        }
    }
    
    /// Clean up stale animations (older than 5 seconds)
    public func cleanupStaleAnimations() {
        lock.lock()
        defer { lock.unlock() }
        
        let currentTime = CACurrentMediaTime()
        let staleKeys = activeAnimations.filter { currentTime - $0.value.startTime > 5.0 }.map { $0.key }
        
        for key in staleKeys {
            activeAnimations.removeValue(forKey: key)
        }
    }
    
    // MARK: - Velocity-Aware Parameters
    
    /// Calculate animation parameters based on gesture velocity
    public func velocityAwareParameters(
        baseParameters: LiquidGlassAnimationParameters,
        velocity: CGFloat,
        context: AnimationContext = .interaction
    ) -> LiquidGlassAnimationParameters {
        // Normalize velocity (typical range: 0-3000 points/second)
        let normalizedVelocity = min(abs(velocity) / 1000.0, 3.0)
        
        // Adjust duration: faster velocity = shorter duration
        let velocityDurationFactor = max(0.6, 1.0 - (normalizedVelocity * 0.15))
        let contextDurationFactor = durationMultiplier(for: context)
        let adjustedDuration = baseParameters.duration * velocityDurationFactor * contextDurationFactor
        
        // Adjust curve based on velocity
        let adjustedCurve: LiquidGlassAnimationCurve
        switch baseParameters.curve {
        case let .spring(damping, mass, stiffness, initialVelocity):
            // Higher velocity = less damping (snappier), higher stiffness
            let velocityDampingFactor = max(0.4, damping - (normalizedVelocity * 0.1))
            let velocityStiffnessFactor = stiffness + (normalizedVelocity * 50.0)
            
            adjustedCurve = .spring(
                damping: velocityDampingFactor,
                mass: mass,
                stiffness: velocityStiffnessFactor,
                initialVelocity: normalizedVelocity
            )
        default:
            adjustedCurve = baseParameters.curve
        }
        
        return LiquidGlassAnimationParameters(
            duration: adjustedDuration,
            curve: adjustedCurve
        )
    }
    
    /// Get scale multiplier based on context
    public func scaleMultiplier(for context: AnimationContext) -> CGFloat {
        return intensityMultiplier(for: context)
    }
}

// MARK: - CALayer Extension for Coordinated Animations

extension CALayer {
    /// Add animation with coordination
    public func addCoordinatedAnimation(
        _ animation: CAAnimation,
        forKey key: String,
        priority: LiquidGlassAnimationCoordinator.AnimationPriority = .normal,
        context: LiquidGlassAnimationCoordinator.AnimationContext = .interaction,
        completion: (() -> Void)? = nil
    ) {
        let coordinator = LiquidGlassAnimationCoordinator.shared
        
        // Check if we can add this animation
        guard coordinator.registerAnimation(key: key, priority: priority, context: context) else {
            // Animation rejected due to lower priority
            return
        }
        
        // Cancel lower priority animations
        coordinator.cancelLowerPriorityAnimations(on: self, thanPriority: priority)
        
        // Add completion handler to unregister
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                coordinator.unregisterAnimation(key: key)
                completion()
            }
            self.add(animation, forKey: key)
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                coordinator.unregisterAnimation(key: key)
            }
            self.add(animation, forKey: key)
            CATransaction.commit()
        }
    }
}
