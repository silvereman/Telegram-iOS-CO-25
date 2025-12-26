import Foundation
import UIKit
import QuartzCore
import AsyncDisplayKit

/// Custom liquid glass switch node with smooth animations
public final class LiquidGlassSwitchNode: ASDisplayNode {
    private let trackView: UIView
    private let thumbView: UIView
    private let blurView: LiquidGlassBlurView
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get { return _isOn }
        set {
            if _isOn != newValue {
                _isOn = newValue
                updateState(animated: false)
            }
        }
    }
    
    public var onTintColor: UIColor = .systemGreen {
        didSet {
            updateColors()
        }
    }
    
    public var offTintColor: UIColor = UIColor(white: 0.9, alpha: 1.0) {
        didSet {
            updateColors()
        }
    }
    
    public var thumbTintColor: UIColor = .white {
        didSet {
            thumbView.backgroundColor = thumbTintColor
        }
    }
    
    public var valueChanged: ((Bool) -> Void)?
    
    private let switchSize = CGSize(width: 51.0, height: 31.0)
    private let thumbSize: CGFloat = 27.0
    private let thumbInset: CGFloat = 2.0
    
    public override init() {
        // Track (background) - NO BLUR per requirements
        self.trackView = UIView()
        self.trackView.layer.cornerRadius = 15.5
        self.trackView.isUserInteractionEnabled = false
        
        // Thumb (moving circle) - BLUR ONLY ON MOVING ELEMENT per requirements
        self.thumbView = UIView()
        self.thumbView.backgroundColor = .white
        self.thumbView.layer.cornerRadius = thumbSize / 2.0
        self.thumbView.isUserInteractionEnabled = false
        
        // Blur view for glass effect - ON THUMB ONLY (moving element)
        self.blurView = LiquidGlassBlurView(configuration: .subtle)
        self.blurView.isUserInteractionEnabled = false
        self.blurView.layer.cornerRadius = thumbSize / 2.0
        self.blurView.clipsToBounds = true
        
        // Shadow for thumb
        self.thumbView.layer.shadowColor = UIColor.black.cgColor
        self.thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.thumbView.layer.shadowOpacity = 0.15
        self.thumbView.layer.shadowRadius = 3.0
        
        super.init()
        
        self.view.addSubview(self.trackView)
        // Blur is now on thumb, not track
        self.thumbView.addSubview(self.blurView)
        self.view.addSubview(self.thumbView)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.view.addGestureRecognizer(tapGesture)
        
        updateColors()
    }
    
    @objc private func handleTap() {
        setOn(!_isOn, animated: true)
        valueChanged?(_isOn)
        
        // Liquid glass tap animation on thumb
        LiquidGlassAnimations.highlightScale(
            layer: thumbView.layer,
            from: 1.0,
            to: 1.1,
            parameters: .highlightTap
        ) { [weak self] in
            guard let self = self else { return }
            LiquidGlassAnimations.bounceReleaseScale(
                layer: self.thumbView.layer,
                to: 1.0,
                parameters: .bounceRelease
            )
        }
    }
    
    public func setOn(_ on: Bool, animated: Bool) {
        guard _isOn != on else { return }
        _isOn = on
        updateState(animated: animated)
    }
    
    private func updateState(animated: Bool) {
        let thumbX = _isOn ? (switchSize.width - thumbSize - thumbInset) : thumbInset
        
        if animated {
            // Liquid glass slide animation with spring
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                self.thumbView.frame.origin.x = thumbX
                self.updateColors()
            }, completion: nil)
            
            // Add stretch effect during transition
            LiquidGlassAnimations.stretchScale(
                layer: thumbView.layer,
                scaleX: 1.15,
                scaleY: 0.95,
                parameters: .pressDown
            ) { [weak self] in
                guard let self = self else { return }
                LiquidGlassAnimations.stretchScale(
                    layer: self.thumbView.layer,
                    scaleX: 1.0,
                    scaleY: 1.0,
                    parameters: .bounceRelease
                )
            }
        } else {
            thumbView.frame.origin.x = thumbX
            updateColors()
        }
    }
    
    private func updateColors() {
        let targetColor = _isOn ? onTintColor : offTintColor
        trackView.backgroundColor = targetColor
        blurView.alpha = _isOn ? 0.3 : 0.1
    }
    
    public override func layout() {
        super.layout()
        
        trackView.frame = CGRect(origin: .zero, size: switchSize)
        
        let thumbY = (switchSize.height - thumbSize) / 2.0
        let thumbX = _isOn ? (switchSize.width - thumbSize - thumbInset) : thumbInset
        thumbView.frame = CGRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        
        // Blur view fills the thumb (moving element)
        blurView.frame = thumbView.bounds
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return switchSize
    }
}
