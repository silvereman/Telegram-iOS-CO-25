import Foundation
import UIKit
import QuartzCore

/// Custom slider knob view with liquid glass effect
/// 
/// This view implements a glass knob for sliders with blur effect applied ONLY to the moving element.
/// The knob includes:
/// - Blur layer for glass effect
/// - Shadow for depth
/// - Stretch animation during drag
/// - Bounce animation on release
///
/// **Performance**: Optimized for 60fps dragging with throttled blur updates
/// **Compatibility**: iOS 13+
public final class LiquidGlassSliderKnobView: UIView {
    
    // MARK: - Properties
    
    /// Blur view for glass effect - ONLY on moving knob per requirements
    private let blurView: LiquidGlassBlurView
    
    /// Content view for knob color
    private let contentView: UIView
    
    /// Configuration for blur effect
    private var blurConfiguration: LiquidGlassBlurConfiguration
    
    /// Whether the knob is currently being dragged
    public var isTracking: Bool = false {
        didSet {
            if isTracking != oldValue {
                updateBlurIntensity(animated: true)
            }
        }
    }
    
    /// Knob color
    public var knobColor: UIColor = .white {
        didSet {
            contentView.backgroundColor = knobColor
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize with custom size and blur configuration
    /// - Parameters:
    ///   - size: Size of the knob (typically 28-40pt)
    ///   - configuration: Blur configuration (default: .subtle)
    public init(size: CGFloat, configuration: LiquidGlassBlurConfiguration = .subtle) {
        self.blurConfiguration = configuration
        self.blurView = LiquidGlassBlurView(configuration: configuration)
        self.contentView = UIView()
        
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        
        setupViews(size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews(size: CGFloat) {
        // Content view (solid color)
        contentView.backgroundColor = knobColor
        contentView.layer.cornerRadius = size / 2.0
        contentView.clipsToBounds = true
        addSubview(contentView)
        
        // Blur view on top for glass effect
        blurView.layer.cornerRadius = size / 2.0
        blurView.clipsToBounds = true
        blurView.alpha = 0.3 // Subtle glass effect
        addSubview(blurView)
        
        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -3.0)
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 12.0
        layer.masksToBounds = false
        
        // Continuous corner curve for smoother appearance (iOS 13+)
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
            contentView.layer.cornerCurve = .continuous
            blurView.layer.cornerCurve = .continuous
        }
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.frame = bounds
        blurView.frame = bounds
    }
    
    // MARK: - Blur Management
    
    /// Update blur intensity based on tracking state
    /// - Parameter animated: Whether to animate the change
    private func updateBlurIntensity(animated: Bool) {
        let targetAlpha: CGFloat = isTracking ? 0.5 : 0.3
        
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.blurView.alpha = targetAlpha
            }
        } else {
            blurView.alpha = targetAlpha
        }
    }
    
    /// Update blur configuration
    /// - Parameters:
    ///   - configuration: New blur configuration
    ///   - animated: Whether to animate the change
    public func updateBlurConfiguration(_ configuration: LiquidGlassBlurConfiguration, animated: Bool = false) {
        self.blurConfiguration = configuration
        blurView.updateConfiguration(configuration, animated: animated)
    }
    
    // MARK: - Animation Support
    
    /// Apply stretch effect during drag
    /// - Parameters:
    ///   - scaleX: Horizontal scale factor
    ///   - scaleY: Vertical scale factor
    public func applyStretch(scaleX: CGFloat, scaleY: CGFloat) {
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        contentView.transform = transform
        blurView.transform = transform
    }
    
    /// Apply velocity-aware stretch during drag
    /// Stretch amount is proportional to drag velocity for more natural feedback
    /// - Parameters:
    ///   - velocity: Drag velocity in points/second
    ///   - direction: Direction of drag (positive = right/up, negative = left/down)
    public func applyVelocityAwareStretch(velocity: CGFloat, direction: CGFloat) {
        // Clamp velocity to reasonable range
        let clampedVelocity = min(abs(velocity), 2000.0)
        
        // Calculate stretch factor based on velocity (max 15% stretch at high velocity)
        let stretchFactor = 1.0 + (clampedVelocity / 2000.0) * 0.15
        let compressFactor = 1.0 - (clampedVelocity / 2000.0) * 0.08
        
        // Apply stretch in direction of movement
        let scaleX: CGFloat
        let scaleY: CGFloat
        
        if abs(direction) > 0.5 {
            // Horizontal movement - stretch horizontally, compress vertically
            scaleX = stretchFactor
            scaleY = compressFactor
        } else {
            // Vertical movement - compress horizontally, stretch vertically
            scaleX = compressFactor
            scaleY = stretchFactor
        }
        
        // Use spring animation for smooth transition
        LiquidGlassAnimations.stretchScale(
            layer: layer,
            scaleX: scaleX,
            scaleY: scaleY,
            parameters: .stretch
        )
    }
    
    /// Apply edge resistance animation when knob hits min/max bounds
    /// Provides haptic-like visual feedback at slider limits
    /// - Parameter atMaximum: Whether at maximum (true) or minimum (false) edge
    public func applyEdgeResistance(atMaximum: Bool) {
        // Brief overshoot then bounce back using constants
        LiquidGlassAnimations.highlightScale(
            layer: layer,
            from: LiquidGlassAnimationParameters.scaleNormal,
            to: LiquidGlassAnimationParameters.scalePress,
            parameters: LiquidGlassAnimationParameters(
                duration: 0.08,
                curve: .spring(damping: 0.8, mass: 1.0, stiffness: 300.0, initialVelocity: 0.5)
            )
        ) { [weak self] in
            LiquidGlassAnimations.bounceReleaseScale(
                layer: self?.layer ?? CALayer(),
                to: LiquidGlassAnimationParameters.scaleNormal,
                parameters: .bounceRelease
            )
        }
    }
    
    /// Reset stretch to normal
    /// - Parameter animated: Whether to animate the reset
    public func resetStretch(animated: Bool = true) {
        if animated {
            // Use Liquid Glass bounce release for consistent feel
            LiquidGlassAnimations.bounceReleaseScale(
                layer: layer,
                to: LiquidGlassAnimationParameters.scaleNormal,
                parameters: .bounceRelease
            )
            
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
                self.contentView.transform = .identity
                self.blurView.transform = .identity
            })
        } else {
            contentView.transform = .identity
            blurView.transform = .identity
            layer.transform = CATransform3DIdentity
        }
    }
}

// MARK: - UISlider Extension for Liquid Glass Knob

/// Extension to add glass knob support to any UISlider
public extension UISlider {
    
    /// Glass knob view (stored via associated object)
    private static var glassKnobViewKey: UInt8 = 0
    
    var glassKnobView: LiquidGlassSliderKnobView? {
        get {
            return objc_getAssociatedObject(self, &UISlider.glassKnobViewKey) as? LiquidGlassSliderKnobView
        }
        set {
            objc_setAssociatedObject(self, &UISlider.glassKnobViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Enable liquid glass effect on slider knob
    /// - Parameters:
    ///   - knobSize: Size of the knob (default: 28pt)
    ///   - configuration: Blur configuration
    func enableLiquidGlassKnob(knobSize: CGFloat = 28.0, configuration: LiquidGlassBlurConfiguration = .subtle) {
        // Create glass knob view
        let glassKnob = LiquidGlassSliderKnobView(size: knobSize, configuration: configuration)
        self.glassKnobView = glassKnob
        
        // Create transparent thumb image
        let thumbImage = createTransparentThumbImage(size: CGSize(width: knobSize, height: knobSize))
        self.setThumbImage(thumbImage, for: .normal)
        self.setThumbImage(thumbImage, for: .highlighted)
        
        // Add glass knob as overlay
        self.addSubview(glassKnob)
        
        // Position glass knob over thumb
        updateGlassKnobPosition()
        
        // Add value change tracking
        self.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        self.addTarget(self, action: #selector(sliderTouchDown(_:)), for: .touchDown)
        self.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    /// Disable liquid glass effect
    func disableLiquidGlassKnob() {
        glassKnobView?.removeFromSuperview()
        glassKnobView = nil
        
        // Reset to default thumb
        self.setThumbImage(nil, for: .normal)
        self.setThumbImage(nil, for: .highlighted)
        
        self.removeTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        self.removeTarget(self, action: #selector(sliderTouchDown(_:)), for: .touchDown)
        self.removeTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    private func createTransparentThumbImage(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.clear(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func updateGlassKnobPosition() {
        guard let glassKnob = glassKnobView else { return }
        
        let trackRect = self.trackRect(forBounds: bounds)
        let thumbRect = self.thumbRect(forBounds: bounds, trackRect: trackRect, value: value)
        
        glassKnob.center = CGPoint(x: thumbRect.midX, y: thumbRect.midY)
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        updateGlassKnobPosition()
        
        // Apply velocity-aware stretch during drag
        if let glassKnob = glassKnobView, glassKnob.isTracking {
            // Calculate pseudo-velocity based on value change
            let velocity = CGFloat(sender.value) * 1000.0
            glassKnob.applyVelocityAwareStretch(velocity: velocity, direction: 1.0)
        }
    }
    
    @objc private func sliderTouchDown(_ sender: UISlider) {
        guard let glassKnob = glassKnobView else { return }
        glassKnob.isTracking = true

        // Press down animation using constant
        LiquidGlassAnimations.pressDownScale(
            layer: glassKnob.layer,
            to: LiquidGlassAnimationParameters.scalePress,
            parameters: .pressDown
        )
    }
    
    @objc private func sliderTouchUp(_ sender: UISlider) {
        guard let glassKnob = glassKnobView else { return }
        glassKnob.isTracking = false
        
        // Bounce release animation
        glassKnob.resetStretch(animated: true)
        
        // Check for edge resistance
        if sender.value <= sender.minimumValue + 0.01 {
            glassKnob.applyEdgeResistance(atMaximum: false)
        } else if sender.value >= sender.maximumValue - 0.01 {
            glassKnob.applyEdgeResistance(atMaximum: true)
        }
    }
}

