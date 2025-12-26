import Foundation
import UIKit
import QuartzCore
import Display

/// Dedicated glass layer for tab bar items with liquid glass effects
public final class TabBarItemGlassLayer: CALayer {
    
    // MARK: - Properties
    
    private let blurView: LiquidGlassBlurView
    private var configuration: LiquidGlassBlurConfiguration
    private var animationState: AnimationState = .normal
    
    private enum AnimationState {
        case normal
        case highlighted
        case pressed
    }
    
    // MARK: - Initialization
    
    public init(configuration: LiquidGlassBlurConfiguration = .standard, isDark: Bool = false) {
        self.configuration = configuration
        self.blurView = LiquidGlassBlurView(
            configuration: configuration,
            isDark: isDark
        )
        
        super.init()
        
        self.allowsGroupOpacity = true
        self.masksToBounds = true
        self.cornerRadius = 22.5 // Circular for ~45-50pt diameter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(layer: Any) {
        if let glassLayer = layer as? TabBarItemGlassLayer {
            self.configuration = glassLayer.configuration
            self.blurView = LiquidGlassBlurView(
                configuration: glassLayer.configuration,
                isDark: glassLayer.blurView.isDark
            )
            self.animationState = glassLayer.animationState
        } else {
            self.configuration = .standard
            self.blurView = LiquidGlassBlurView(configuration: .standard, isDark: false)
        }
        
        super.init(layer: layer)
    }
    
    // MARK: - Layout
    
    override public func layoutSublayers() {
        super.layoutSublayers()
        
        // Ensure blur view matches layer bounds
        if blurView.superview == nil, let view = self.delegate as? UIView {
            view.insertSubview(blurView, at: 0)
        }
        blurView.frame = self.bounds
    }
    
    // MARK: - Animation Methods
    
    /// Animates highlight state (tap)
    public func animateHighlight() {
        guard animationState != .highlighted else { return }
        animationState = .highlighted

        // Scale animation using constants
        LiquidGlassAnimations.highlightScale(
            layer: self,
            from: LiquidGlassAnimationParameters.scaleNormal,
            to: LiquidGlassAnimationParameters.scaleHighlight,
            parameters: .highlightTap
        )
    }

    /// Animates press down state
    public func animatePress() {
        guard animationState != .pressed else { return }
        animationState = .pressed

        // Quick press down using scalePress constant
        LiquidGlassAnimations.pressDownScale(
            layer: self,
            to: LiquidGlassAnimationParameters.scalePress,
            parameters: .pressDown
        )

        // Add 3D depth effect
        LiquidGlassAnimations.transformWithPerspective(
            layer: self,
            scale: LiquidGlassAnimationParameters.scalePress,
            perspective: -1.0 / 1000.0,
            parameters: .pressDown
        )
    }

    /// Animates release/bounce back to normal
    public func animateRelease(completion: (() -> Void)? = nil) {
        animationState = .normal

        // Bounce back using scaleNormal constant
        LiquidGlassAnimations.bounceReleaseScale(
            layer: self,
            to: LiquidGlassAnimationParameters.scaleNormal,
            parameters: .bounceRelease,
            completion: completion
        )
    }
    
    /// Animates stretch effect when tab is changing
    public func animateStretch() {
        // Horizontal stretch using constants
        LiquidGlassAnimations.stretchScale(
            layer: self,
            scaleX: 1.05,
            scaleY: LiquidGlassAnimationParameters.scaleNormal,
            parameters: .stretch
        ) { [weak self] in
            // Return to normal
            LiquidGlassAnimations.stretchScale(
                layer: self ?? CALayer(),
                scaleX: LiquidGlassAnimationParameters.scaleNormal,
                scaleY: LiquidGlassAnimationParameters.scaleNormal,
                parameters: .stretch
            )
        }
    }
    
    /// Resets to normal state
    public func resetToNormal() {
        animationState = .normal
        LiquidGlassAnimations.removeAllAnimations(from: self)
        
        // Reset transform
        self.transform = CATransform3DIdentity
    }
    
    // MARK: - Configuration Updates
    
    /// Updates blur configuration
    public func updateConfiguration(_ configuration: LiquidGlassBlurConfiguration, animated: Bool = false) {
        self.configuration = configuration
        blurView.updateConfiguration(configuration, animated: animated)
    }
    
    /// Updates dark mode
    public func updateDarkMode(_ isDark: Bool) {
        blurView.isDark = isDark
    }
}

// MARK: - UIView Extension for Glass Layer

extension UIView {
    /// Adds a glass layer to the view
    func addGlassLayer(_ glassLayer: TabBarItemGlassLayer) {
        // Insert blur view at the bottom
        self.insertSubview(glassLayer.blurView, at: 0)
        glassLayer.blurView.frame = glassLayer.bounds
        
        // Add the glass layer
        self.layer.insertSublayer(glassLayer, at: 0)
    }
    
    /// Removes glass layer from view
    func removeGlassLayer(_ glassLayer: TabBarItemGlassLayer) {
        glassLayer.blurView.removeFromSuperview()
        glassLayer.removeFromSuperlayer()
    }
}
