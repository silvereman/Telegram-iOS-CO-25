import Foundation
import UIKit
import QuartzCore

public enum LiquidGlassAnimationCurve {
    case spring(damping: CGFloat, mass: CGFloat, stiffness: CGFloat, initialVelocity: CGFloat)
    case easeOut
    case easeInOut
    case custom(timingFunction: CAMediaTimingFunction)
}

public struct LiquidGlassAnimationParameters {
    public let duration: Double
    public let curve: LiquidGlassAnimationCurve
    
    public init(duration: Double, curve: LiquidGlassAnimationCurve) {
        self.duration = duration
        self.curve = curve
    }
    
    // MARK: - Computed Properties for Spring Parameters
    
    /// Returns the spring damping value if using a spring curve, or a default value
    public var springDamping: CGFloat {
        switch curve {
        case let .spring(damping, _, _, _):
            return damping
        default:
            return 1.0 // Critical damping for non-spring curves
        }
    }
    
    /// Returns the initial velocity if using a spring curve, or a default value
    public var springVelocity: CGFloat {
        switch curve {
        case let .spring(_, _, _, initialVelocity):
            return initialVelocity
        default:
            return 0.0
        }
    }
    
    /// Returns the spring mass if using a spring curve, or a default value
    public var springMass: CGFloat {
        switch curve {
        case let .spring(_, mass, _, _):
            return mass
        default:
            return 1.0
        }
    }
    
    /// Returns the spring stiffness if using a spring curve, or a default value
    public var springStiffness: CGFloat {
        switch curve {
        case let .spring(_, _, stiffness, _):
            return stiffness
        default:
            return 100.0
        }
    }
    
    /// Returns true if this uses a spring animation curve
    public var isSpring: Bool {
        if case .spring = curve {
            return true
        }
        return false
    }
    
    // MARK: - Unified Scale Constants
    
    /// Unified scale constants to eliminate hardcoded values across the codebase
    public static let scaleNormal: CGFloat = 1.0
    public static let scalePress: CGFloat = 0.92
    public static let scaleHighlight: CGFloat = 1.15
    
    // MARK: - Predefined Animation Parameters
    
    // Predefined animation parameters for consistency
    public static let highlightTap = LiquidGlassAnimationParameters(
        duration: 0.3,
        curve: .spring(damping: 0.6, mass: 1.0, stiffness: 300.0, initialVelocity: 0.0)
    )
    
    public static let pressDown = LiquidGlassAnimationParameters(
        duration: 0.05,
        curve: .spring(damping: 0.8, mass: 1.0, stiffness: 400.0, initialVelocity: 0.2)
    )
    
    public static let bounceRelease = LiquidGlassAnimationParameters(
        duration: 0.4,
        curve: .spring(damping: 0.5, mass: 1.0, stiffness: 300.0, initialVelocity: 0.5)
    )
    
    public static let stretch = LiquidGlassAnimationParameters(
        duration: 0.25,
        curve: .spring(damping: 0.7, mass: 1.0, stiffness: 250.0, initialVelocity: 0.0)
    )
    
    public static let tabSwitch = LiquidGlassAnimationParameters(
        duration: 0.35,
        curve: .spring(damping: 0.65, mass: 1.0, stiffness: 280.0, initialVelocity: 0.0)
    )
}

public final class LiquidGlassAnimations {

    // MARK: - Reduced Motion Support

    /// Check if reduced motion is enabled for accessibility
    private static var isReducedMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }

    /// Adjust parameters for reduced motion
    private static func adjustedParameters(_ parameters: LiquidGlassAnimationParameters) -> LiquidGlassAnimationParameters {
        guard isReducedMotionEnabled else {
            return parameters
        }

        // Use simpler, faster animations when reduced motion is enabled
        return LiquidGlassAnimationParameters(
            duration: min(parameters.duration * 0.5, 0.2), // Faster, max 0.2s
            curve: .easeInOut // Simple curve instead of spring
        )
    }

    /// Adjust scale values for reduced motion (less dramatic)
    private static func adjustedScale(from: CGFloat, to: CGFloat) -> CGFloat {
        guard isReducedMotionEnabled else {
            return to
        }

        // Reduce the scale change by 50%
        let delta = to - from
        return from + (delta * 0.5)
    }

    // MARK: - Scale Animations

    /// Creates a highlight animation that scales up with elastic spring
    public static func highlightScale(
        layer: CALayer,
        from fromScale: CGFloat = 1.0,
        to toScale: CGFloat = 1.15,
        parameters: LiquidGlassAnimationParameters = .highlightTap,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.scale")

        // Adjust for reduced motion
        let adjustedToScale = adjustedScale(from: fromScale, to: toScale)
        let adjustedParams = adjustedParameters(parameters)

        let animation = createScaleAnimation(
            from: fromScale,
            to: adjustedToScale,
            parameters: adjustedParams
        )
        
        // Update actual layer property to prevent stale animation state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeScale(toScale, toScale, 1.0)
        CATransaction.commit()
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(animation, forKey: "liquidGlass.scale")
            CATransaction.commit()
        } else {
            layer.add(animation, forKey: "liquidGlass.scale")
        }
    }
    
    /// Creates a press-down animation that scales down instantly
    public static func pressDownScale(
        layer: CALayer,
        to scale: CGFloat = 0.95,
        parameters: LiquidGlassAnimationParameters = .pressDown,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.scale")

        // Adjust for reduced motion
        let adjustedScale = adjustedScale(from: 1.0, to: scale)
        let adjustedParams = adjustedParameters(parameters)
        
        let fromScale = (layer.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat) ?? 1.0

        let animation = createScaleAnimation(
            from: fromScale,
            to: adjustedScale,
            parameters: adjustedParams
        )

        // Update actual layer property to prevent stale animation state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeScale(adjustedScale, adjustedScale, 1.0)
        CATransaction.commit()
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(animation, forKey: "liquidGlass.scale")
            CATransaction.commit()
        } else {
            layer.add(animation, forKey: "liquidGlass.scale")
        }
    }
    
    /// Creates a bounce release animation
    public static func bounceReleaseScale(
        layer: CALayer,
        to scale: CGFloat = 1.0,
        parameters: LiquidGlassAnimationParameters = .bounceRelease,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.scale")

        // Adjust for reduced motion
        let fromScale = (layer.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat) ?? 0.95
        let adjustedScale = adjustedScale(from: fromScale, to: scale)
        let adjustedParams = adjustedParameters(parameters)

        let animation = createScaleAnimation(
            from: fromScale,
            to: adjustedScale,
            parameters: adjustedParams
        )
        
        // Update actual layer property to prevent stale animation state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeScale(adjustedScale, adjustedScale, 1.0)
        CATransaction.commit()
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(animation, forKey: "liquidGlass.scale")
            CATransaction.commit()
        } else {
            layer.add(animation, forKey: "liquidGlass.scale")
        }
    }
    
    // MARK: - Stretch Animations
    
    /// Creates a stretch effect using separate scale values for X and Y
    public static func stretchScale(
        layer: CALayer,
        scaleX: CGFloat,
        scaleY: CGFloat,
        parameters: LiquidGlassAnimationParameters = .stretch,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.scaleX")
        layer.removeAnimation(forKey: "liquidGlass.scaleY")

        // Adjust stretch effect for reduced motion
        let fromScaleX = (layer.presentation()?.value(forKeyPath: "transform.scale.x") as? CGFloat) ?? 1.0
        let fromScaleY = (layer.presentation()?.value(forKeyPath: "transform.scale.y") as? CGFloat) ?? 1.0

        let adjustedScaleX = adjustedScale(from: fromScaleX, to: scaleX)
        let adjustedScaleY = adjustedScale(from: fromScaleY, to: scaleY)
        let adjustedParams = adjustedParameters(parameters)
        
        let animationX = createScaleAnimation(
            from: fromScaleX,
            to: adjustedScaleX,
            parameters: adjustedParams,
            keyPath: "transform.scale.x"
        )

        let animationY = createScaleAnimation(
            from: fromScaleY,
            to: adjustedScaleY,
            parameters: adjustedParams,
            keyPath: "transform.scale.y"
        )
        
        // Update actual layer property to prevent stale animation state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var transform = layer.transform
        transform = CATransform3DScale(transform, adjustedScaleX / CATransform3DGetAffineTransform(transform).a, adjustedScaleY / CATransform3DGetAffineTransform(transform).d, 1.0)
        layer.transform = transform
        CATransaction.commit()
        
        CATransaction.begin()
        if let completion = completion {
            CATransaction.setCompletionBlock(completion)
        }
        layer.add(animationX, forKey: "liquidGlass.scaleX")
        layer.add(animationY, forKey: "liquidGlass.scaleY")
        CATransaction.commit()
    }
    
    // MARK: - Transform Animations with Perspective
    
    /// Creates a 3D transform animation with perspective for depth effect
    public static func transformWithPerspective(
        layer: CALayer,
        scale: CGFloat,
        perspective: CGFloat = -1.0 / 1000.0,
        parameters: LiquidGlassAnimationParameters = .pressDown,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.transform")
        
        var transform = CATransform3DIdentity
        transform.m34 = perspective
        transform = CATransform3DScale(transform, scale, scale, 1.0)
        
        let animation: CAAnimation
        switch parameters.curve {
        case let .spring(damping, mass, stiffness, initialVelocity):
            // CASpringAnimation available since iOS 9, not iOS 17
            if #available(iOS 9.0, *) {
                let springAnimation = CASpringAnimation(keyPath: "transform")
                springAnimation.damping = damping
                springAnimation.mass = mass
                springAnimation.stiffness = stiffness
                springAnimation.initialVelocity = initialVelocity
                springAnimation.duration = springAnimation.settlingDuration
                springAnimation.toValue = NSValue(caTransform3D: transform)
                animation = springAnimation
            } else {
                // Fallback for iOS 8 and below (unlikely but safe)
                let basicAnimation = CABasicAnimation(keyPath: "transform")
                basicAnimation.toValue = NSValue(caTransform3D: transform)
                basicAnimation.duration = parameters.duration
                basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation = basicAnimation
            }
        case .easeOut:
            let basicAnimation = CABasicAnimation(keyPath: "transform")
            basicAnimation.toValue = NSValue(caTransform3D: transform)
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation = basicAnimation
        case .easeInOut:
            let basicAnimation = CABasicAnimation(keyPath: "transform")
            basicAnimation.toValue = NSValue(caTransform3D: transform)
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation = basicAnimation
        case let .custom(timingFunction):
            let basicAnimation = CABasicAnimation(keyPath: "transform")
            basicAnimation.toValue = NSValue(caTransform3D: transform)
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = timingFunction
            animation = basicAnimation
        }
        
        // Properly update layer transform and add animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = transform
        CATransaction.commit()
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(animation, forKey: "liquidGlass.transform")
            CATransaction.commit()
        } else {
            layer.add(animation, forKey: "liquidGlass.transform")
        }
    }
    
    // MARK: - Rotation Wobble
    
    /// Creates a subtle rotation wobble effect
    public static func rotationWobble(
        layer: CALayer,
        angle: CGFloat = 2.0 * .pi / 180.0, // 2 degrees
        parameters: LiquidGlassAnimationParameters = .bounceRelease,
        completion: (() -> Void)? = nil
    ) {
        layer.removeAnimation(forKey: "liquidGlass.rotation")
        
        let keyframeAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        keyframeAnimation.values = [0, angle, -angle * 0.5, angle * 0.25, 0]
        keyframeAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        keyframeAnimation.duration = parameters.duration
        
        switch parameters.curve {
        case .spring, .easeInOut:
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeOut:
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        case let .custom(timingFunction):
            keyframeAnimation.timingFunction = timingFunction
        }
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(keyframeAnimation, forKey: "liquidGlass.rotation")
            CATransaction.commit()
        } else {
            layer.add(keyframeAnimation, forKey: "liquidGlass.rotation")
        }
    }
    
    // MARK: - Pulsing Animation
    
    /// Creates a pulsing animation for recording states
    public static func pulsingScale(
        layer: CALayer,
        fromScale: CGFloat = 1.0,
        toScale: CGFloat = 1.05,
        duration: Double = 1.0,
        autoreverses: Bool = true
    ) {
        // Disable pulsing animation entirely when reduced motion is enabled
        guard !isReducedMotionEnabled else {
            layer.removeAnimation(forKey: "liquidGlass.pulse")
            // Set to normal scale
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.transform = CATransform3DMakeScale(fromScale, fromScale, 1.0)
            CATransaction.commit()
            return
        }

        layer.removeAnimation(forKey: "liquidGlass.pulse")

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = fromScale
        animation.toValue = toScale
        animation.duration = duration
        animation.autoreverses = autoreverses
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(animation, forKey: "liquidGlass.pulse")
    }
    
    /// Stops pulsing animation
    public static func stopPulsing(layer: CALayer) {
        layer.removeAnimation(forKey: "liquidGlass.pulse")
    }
    
    // MARK: - Helper Methods
    
    private static func createScaleAnimation(
        from: CGFloat,
        to: CGFloat,
        parameters: LiquidGlassAnimationParameters,
        keyPath: String = "transform.scale"
    ) -> CAAnimation {
        let animation: CAAnimation
        
        switch parameters.curve {
        case let .spring(damping, mass, stiffness, initialVelocity):
            // CASpringAnimation available since iOS 9, not iOS 17
            if #available(iOS 9.0, *) {
                let springAnimation = CASpringAnimation(keyPath: keyPath)
                springAnimation.damping = damping
                springAnimation.mass = mass
                springAnimation.stiffness = stiffness
                springAnimation.initialVelocity = initialVelocity
                springAnimation.fromValue = from
                springAnimation.toValue = to
                springAnimation.duration = springAnimation.settlingDuration
                animation = springAnimation
            } else {
                // Fallback for iOS 8 and below (unlikely but safe)
                let basicAnimation = CABasicAnimation(keyPath: keyPath)
                basicAnimation.fromValue = from
                basicAnimation.toValue = to
                basicAnimation.duration = parameters.duration
                basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation = basicAnimation
            }
        case .easeOut:
            let basicAnimation = CABasicAnimation(keyPath: keyPath)
            basicAnimation.fromValue = from
            basicAnimation.toValue = to
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation = basicAnimation
        case .easeInOut:
            let basicAnimation = CABasicAnimation(keyPath: keyPath)
            basicAnimation.fromValue = from
            basicAnimation.toValue = to
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation = basicAnimation
        case let .custom(timingFunction):
            let basicAnimation = CABasicAnimation(keyPath: keyPath)
            basicAnimation.fromValue = from
            basicAnimation.toValue = to
            basicAnimation.duration = parameters.duration
            basicAnimation.timingFunction = timingFunction
            animation = basicAnimation
        }
        
        return animation
    }
    
    // MARK: - Additive Animations
    
    /// Creates an additive animation for smooth composition
    public static func additiveScale(
        layer: CALayer,
        by delta: CGFloat,
        parameters: LiquidGlassAnimationParameters,
        completion: (() -> Void)? = nil
    ) {
        let animation = createScaleAnimation(
            from: 0,
            to: delta,
            parameters: parameters
        )
        animation.isAdditive = true
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(animation, forKey: "liquidGlass.additiveScale")
            CATransaction.commit()
        } else {
            layer.add(animation, forKey: "liquidGlass.additiveScale")
        }
    }
    
    // MARK: - Combined Animation
    
    /// Combines scale and rotation wobble for a complete bounce effect
    public static func bounceWithWobble(
        layer: CALayer,
        scale: CGFloat = 1.0,
        wobbleAngle: CGFloat = 2.0 * .pi / 180.0,
        parameters: LiquidGlassAnimationParameters = .bounceRelease,
        completion: (() -> Void)? = nil
    ) {
        let group = CAAnimationGroup()
        group.duration = parameters.duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        let fromScale = (layer.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat) ?? 0.95
        
        let scaleAnimation = createScaleAnimation(
            from: fromScale,
            to: scale,
            parameters: parameters
        )
        
        let rotationAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.values = [0, wobbleAngle, -wobbleAngle * 0.5, wobbleAngle * 0.25, 0]
        rotationAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        rotationAnimation.duration = parameters.duration
        
        group.animations = [scaleAnimation, rotationAnimation]
        
        if let completion = completion {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)
            layer.add(group, forKey: "liquidGlass.bounceWobble")
            CATransaction.commit()
        } else {
            layer.add(group, forKey: "liquidGlass.bounceWobble")
        }
    }
    
    // MARK: - Animation Cleanup
    
    /// Removes all liquid glass animations from a layer
    public static func removeAllAnimations(from layer: CALayer) {
        layer.removeAnimation(forKey: "liquidGlass.scale")
        layer.removeAnimation(forKey: "liquidGlass.scaleX")
        layer.removeAnimation(forKey: "liquidGlass.scaleY")
        layer.removeAnimation(forKey: "liquidGlass.transform")
        layer.removeAnimation(forKey: "liquidGlass.rotation")
        layer.removeAnimation(forKey: "liquidGlass.pulse")
        layer.removeAnimation(forKey: "liquidGlass.additiveScale")
        layer.removeAnimation(forKey: "liquidGlass.bounceWobble")
    }
}

// MARK: - UIView Extension

public extension UIView {
    /// Convenience method for highlight animation on views
    func liquidGlassHighlight(completion: (() -> Void)? = nil) {
        layer.allowsGroupOpacity = true
        LiquidGlassAnimations.highlightScale(layer: layer, completion: completion)
    }
    
    /// Convenience method for press animation on views
    func liquidGlassPressDown(completion: (() -> Void)? = nil) {
        layer.allowsGroupOpacity = true
        LiquidGlassAnimations.pressDownScale(layer: layer, completion: completion)
    }
    
    /// Convenience method for bounce release animation on views
    func liquidGlassBounceRelease(completion: (() -> Void)? = nil) {
        layer.allowsGroupOpacity = true
        LiquidGlassAnimations.bounceReleaseScale(layer: layer, completion: completion)
    }
    
    /// Convenience method for stretch animation on views
    func liquidGlassStretch(scaleX: CGFloat = 1.05, scaleY: CGFloat = 0.95, completion: (() -> Void)? = nil) {
        layer.allowsGroupOpacity = true
        LiquidGlassAnimations.stretchScale(layer: layer, scaleX: scaleX, scaleY: scaleY, completion: completion)
    }
}

// MARK: - CALayer Extension

public extension CALayer {
    /// Convenience method for highlight animation on layers
    func liquidGlassHighlight(completion: (() -> Void)? = nil) {
        allowsGroupOpacity = true
        LiquidGlassAnimations.highlightScale(layer: self, completion: completion)
    }
    
    /// Convenience method for press animation on layers
    func liquidGlassPressDown(completion: (() -> Void)? = nil) {
        allowsGroupOpacity = true
        LiquidGlassAnimations.pressDownScale(layer: self, completion: completion)
    }
    
    /// Convenience method for bounce release animation on layers
    func liquidGlassBounceRelease(completion: (() -> Void)? = nil) {
        allowsGroupOpacity = true
        LiquidGlassAnimations.bounceReleaseScale(layer: self, completion: completion)
    }
}
