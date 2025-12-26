import Foundation
import UIKit
import QuartzCore

/// Helper extension to add Liquid Glass button animations to any UIView or CALayer
/// Use these animations on glass buttons to achieve the iOS 26 Liquid Glass effect
/// on older iOS versions (iOS 13+)

// MARK: - UIControl Extension for Glass Buttons

public extension UIControl {
    
    private struct AssociatedKeys {
        static var isLiquidGlassEnabled = "isLiquidGlassEnabled"
    }
    
    /// Enable Liquid Glass tap animations on this control
    /// Call this in viewDidLoad or initialization
    var isLiquidGlassEnabled: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.isLiquidGlassEnabled) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isLiquidGlassEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            if newValue {
                setupLiquidGlassAnimations()
            } else {
                removeLiquidGlassAnimations()
            }
        }
    }
    
    private func setupLiquidGlassAnimations() {
        // Add tracking for touch events
        addTarget(self, action: #selector(liquidGlassTouchDown), for: .touchDown)
        addTarget(self, action: #selector(liquidGlassTouchUp), for: [.touchUpInside, .touchUpOutside])
        addTarget(self, action: #selector(liquidGlassTouchCancel), for: .touchCancel)
    }
    
    private func removeLiquidGlassAnimations() {
        removeTarget(self, action: #selector(liquidGlassTouchDown), for: .touchDown)
        removeTarget(self, action: #selector(liquidGlassTouchUp), for: [.touchUpInside, .touchUpOutside])
        removeTarget(self, action: #selector(liquidGlassTouchCancel), for: .touchCancel)
        
        // Reset transform
        layer.transform = CATransform3DIdentity
    }
    
    @objc private func liquidGlassTouchDown() {
        LiquidGlassAnimations.pressDownScale(layer: layer, to: LiquidGlassAnimationParameters.scalePress, parameters: .pressDown)
    }
    
    @objc private func liquidGlassTouchUp() {
        LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: LiquidGlassAnimationParameters.scaleNormal, parameters: .bounceRelease)
    }
    
    @objc private func liquidGlassTouchCancel() {
        LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: LiquidGlassAnimationParameters.scaleNormal, parameters: .bounceRelease)
    }
}

// MARK: - HighlightTrackingButton Extension

/// Extension specifically for HighlightTrackingButton (used by Telegram's glass buttons)
public extension HighlightTrackingButton {
    
    /// Animate highlight state with Liquid Glass effects
    func animateLiquidGlassHighlight(_ isHighlighted: Bool) {
        if isHighlighted {
            LiquidGlassAnimations.pressDownScale(
                layer: layer,
                to: LiquidGlassAnimationParameters.scalePress,
                parameters: .pressDown
            )
        } else {
            LiquidGlassAnimations.bounceReleaseScale(
                layer: layer,
                to: LiquidGlassAnimationParameters.scaleNormal,
                parameters: .bounceRelease
            )
        }
    }
}

// MARK: - GlassBackgroundView Extension

/// Extension to add Liquid Glass animations to GlassBackgroundView
public extension GlassBackgroundView {
    
    /// Animate a tap/touch on the glass element
    func animateGlassTap() {
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: 1.0,
            to: 1.08,
            parameters: .highlightTap
        ) { [weak self] in
            self?.resetGlassAnimation()
        }
    }
    
    /// Animate press down state
    func animateGlassPress() {
        LiquidGlassAnimations.pressDownScale(
            layer: layer,
            to: LiquidGlassAnimationParameters.scalePress,
            parameters: .pressDown
        )
    }
    
    /// Animate release with bounce
    func animateGlassRelease() {
        LiquidGlassAnimations.bounceReleaseScale(
            layer: layer,
            to: LiquidGlassAnimationParameters.scaleNormal,
            parameters: .bounceRelease
        )
    }
    
    /// Reset to normal state
    func resetGlassAnimation() {
        LiquidGlassAnimations.removeAllAnimations(from: layer)
        layer.transform = CATransform3DIdentity
    }
}

// MARK: - UIView Glass Button Helper

public extension UIView {
    
    /// Apply Liquid Glass button behavior to any view
    /// This adds touch tracking and animations
    func applyLiquidGlassButtonBehavior() {
        isUserInteractionEnabled = true
        
        // Add gesture recognizers
        let tapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLiquidGlassGesture(_:)))
        tapRecognizer.minimumPressDuration = 0
        tapRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapRecognizer)
    }
    
    @objc private func handleLiquidGlassGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            LiquidGlassAnimations.pressDownScale(layer: layer, to: LiquidGlassAnimationParameters.scalePress, parameters: .pressDown)
        case .ended, .cancelled, .failed:
            LiquidGlassAnimations.bounceReleaseScale(layer: layer, to: LiquidGlassAnimationParameters.scaleNormal, parameters: .bounceRelease)
        default:
            break
        }
    }
    
    /// Remove Liquid Glass button behavior
    func removeLiquidGlassButtonBehavior() {
        gestureRecognizers?.forEach { recognizer in
            if let target = recognizer as? UILongPressGestureRecognizer,
               target.minimumPressDuration == 0 {
                removeGestureRecognizer(recognizer)
            }
        }
    }
}

// MARK: - Recording Button Animations

public final class LiquidGlassRecordingAnimations {
    
    /// Start pulsing animation for recording state
    public static func startRecordingPulse(on layer: CALayer) {
        LiquidGlassAnimations.pulsingScale(
            layer: layer,
            fromScale: 1.0,
            toScale: 1.05,
            duration: 0.8,
            autoreverses: true
        )
    }
    
    /// Stop pulsing animation
    public static func stopRecordingPulse(on layer: CALayer) {
        LiquidGlassAnimations.stopPulsing(layer: layer)
        LiquidGlassAnimations.bounceReleaseScale(
            layer: layer,
            to: LiquidGlassAnimationParameters.scaleNormal,
            parameters: .bounceRelease
        )
    }
    
    /// Animate lock state during recording
    public static func animateLock(on layer: CALayer) {
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: LiquidGlassAnimationParameters.scaleNormal,
            to: LiquidGlassAnimationParameters.scaleHighlight,
            parameters: .highlightTap
        )
    }
}
