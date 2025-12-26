import Foundation
import UIKit
import CoreImage
import Accelerate

public struct LiquidGlassBlurConfiguration {
    public var blurRadius: CGFloat
    public var saturationBoost: CGFloat
    public var tintColor: UIColor?
    public var tintAlpha: CGFloat
    
    public init(
        blurRadius: CGFloat = 10.0,
        saturationBoost: CGFloat = 1.2,
        tintColor: UIColor? = nil,
        tintAlpha: CGFloat = 0.2
    ) {
        self.blurRadius = blurRadius
        self.saturationBoost = saturationBoost
        self.tintColor = tintColor
        self.tintAlpha = tintAlpha
    }
    
    // Predefined configurations
    public static let standard = LiquidGlassBlurConfiguration(
        blurRadius: 10.0,
        saturationBoost: 1.2,
        tintColor: nil,
        tintAlpha: 0.2
    )
    
    public static let strong = LiquidGlassBlurConfiguration(
        blurRadius: 12.0,
        saturationBoost: 1.3,
        tintColor: nil,
        tintAlpha: 0.25
    )
    
    public static let subtle = LiquidGlassBlurConfiguration(
        blurRadius: 8.0,
        saturationBoost: 1.15,
        tintColor: nil,
        tintAlpha: 0.15
    )
}

public final class LiquidGlassBlurProvider {
    
    // MARK: - LRU Cache with Timestamps
    
    private struct CacheEntry {
        let image: UIImage
        var lastAccessTime: CFTimeInterval
        
        init(image: UIImage) {
            self.image = image
            self.lastAccessTime = CACurrentMediaTime()
        }
        
        mutating func touch() {
            self.lastAccessTime = CACurrentMediaTime()
        }
    }
    
    private static var blurCache: [String: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.telegram.liquidglass.blurcache")
    private static let maxCacheSize = 20
    private static let maxCacheSizeBytes: Int = 10 * 1024 * 1024 // 10MB
    private static var currentCacheSizeBytes: Int = 0
    
    // MARK: - Shared Context
    
    /// Shared CIContext to avoid expensive recreation
    /// Uses Metal if available for hardware acceleration
    /// Falls back to CPU rendering if Metal is unavailable
    private static let sharedContext: CIContext = {
        // Try to create Metal-backed context first
        if let device = MTLCreateSystemDefaultDevice() {
            print("[LiquidGlass] Using Metal-accelerated blur rendering")
            return CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false, .cacheIntermediates: false])
        } else {
            // Fallback to CPU-based rendering
            print("[LiquidGlass] Metal unavailable, using CPU-based blur rendering")
            return CIContext(options: [.useSoftwareRenderer: true])
        }
    }()
    
    // MARK: - Blur Generation
    
    /// Creates a blur effect view optimized for liquid glass
    /// Uses UIBlurEffect for iOS 13+ with custom enhancements to replicate glass appearance
    public static func createBlurView(
        configuration: LiquidGlassBlurConfiguration = .standard,
        isDark: Bool = false
    ) -> UIView {
        // Use enhanced UIBlurEffect implementation for all iOS versions
        // Note: Native UIGlassEffect API not yet available as of iOS 18
        return createCustomBlurView(configuration: configuration, isDark: isDark)
    }

    private static func createCustomBlurView(
        configuration: LiquidGlassBlurConfiguration,
        isDark: Bool
    ) -> UIView {
        // Create base blur effect
        let blurStyle: UIBlurEffect.Style = isDark ? .dark : .light
        let blurEffect = UIBlurEffect(style: blurStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)
        
        // Add saturation and tint overlay
        if configuration.saturationBoost > 1.0 || configuration.tintColor != nil {
            let overlayView = UIView()
            overlayView.isUserInteractionEnabled = false
            
            if let tintColor = configuration.tintColor {
                overlayView.backgroundColor = tintColor.withAlphaComponent(configuration.tintAlpha)
            }
            
            blurView.contentView.addSubview(overlayView)
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlayView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
                overlayView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
                overlayView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
            ])
        }
        
        return blurView
    }
    
    // MARK: - Layer-based Blur
    
    /// Creates a blur layer for CALayer-based implementations
    /// This renders a UIVisualEffectView to create actual blur content
    /// For real-time blur, use LiquidGlassBlurView in the view hierarchy instead
    public static func createBlurLayer(
        configuration: LiquidGlassBlurConfiguration = .standard,
        size: CGSize,
        isDark: Bool = false
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: size)
        
        // For proper blur, we need to create a snapshot of a blur effect view
        // This provides static blur suitable for decorative purposes
        if let blurImage = renderBlurEffectToImage(size: size, isDark: isDark, configuration: configuration) {
            containerLayer.contents = blurImage.cgImage
            containerLayer.contentsGravity = .resizeAspectFill
        } else {
            // Fallback: semi-transparent background with saturation effect
            containerLayer.backgroundColor = (isDark ? UIColor.black : UIColor.white).withAlphaComponent(0.25).cgColor
        }
        
        // Apply corner curve for iOS 13+
        if #available(iOS 13.0, *) {
            containerLayer.cornerCurve = .continuous
        }
        
        // Add tint overlay sublayer
        if let tintColor = configuration.tintColor {
            let tintLayer = CALayer()
            tintLayer.frame = containerLayer.bounds
            tintLayer.backgroundColor = tintColor.withAlphaComponent(configuration.tintAlpha).cgColor
            containerLayer.addSublayer(tintLayer)
        }
        
        return containerLayer
    }
    
    /// Renders a UIVisualEffectView to an image for layer-based usage
    private static func renderBlurEffectToImage(
        size: CGSize,
        isDark: Bool,
        configuration: LiquidGlassBlurConfiguration
    ) -> UIImage? {
        guard size.width > 0 && size.height > 0 else { return nil }
        
        // Create blur effect view
        let blurStyle: UIBlurEffect.Style = isDark ? .dark : .light
        let blurEffect = UIBlurEffect(style: blurStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(origin: .zero, size: size)
        
        // Add gradient background to give the blur something to work with
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurView.bounds
        gradientLayer.colors = isDark 
            ? [UIColor(white: 0.15, alpha: 1.0).cgColor, UIColor(white: 0.1, alpha: 1.0).cgColor]
            : [UIColor(white: 0.95, alpha: 1.0).cgColor, UIColor(white: 0.9, alpha: 1.0).cgColor]
        
        // Create container with gradient background
        let containerView = UIView(frame: blurView.bounds)
        containerView.layer.addSublayer(gradientLayer)
        containerView.addSubview(blurView)
        
        // Add saturation overlay if needed
        if configuration.saturationBoost > 1.0 {
            let overlayView = UIView(frame: blurView.bounds)
            overlayView.backgroundColor = (isDark ? UIColor.white : UIColor.black).withAlphaComponent(0.02 * (configuration.saturationBoost - 1.0))
            blurView.contentView.addSubview(overlayView)
        }
        
        // Render to image
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            containerView.layer.render(in: context.cgContext)
        }
    }
    
    // MARK: - CIFilter-based Blur (iOS 13-16)
    
    /// Applies blur using Core Image filters with comprehensive error handling
    public static func applyBlur(
        to image: UIImage,
        configuration: LiquidGlassBlurConfiguration = .standard
    ) -> UIImage? {
        let cacheKey = blurCacheKey(for: image, configuration: configuration)

        // Check cache first
        if let cachedImage = getCachedBlur(key: cacheKey) {
            return cachedImage
        }

        // Validate input image
        guard let ciImage = CIImage(image: image) else {
            print("[LiquidGlass] Error: Failed to create CIImage from UIImage")
            return image // Return original image as fallback
        }

        // Use shared context
        let context = LiquidGlassBlurProvider.sharedContext

        // Apply Gaussian blur
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("[LiquidGlass] Error: CIGaussianBlur filter unavailable")
            return image // Return original image as fallback
        }

        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(configuration.blurRadius, forKey: kCIInputRadiusKey)

        guard var outputImage = blurFilter.outputImage else {
            print("[LiquidGlass] Error: Blur filter produced no output")
            return image // Return original image as fallback
        }

        // Apply saturation boost
        if configuration.saturationBoost != 1.0 {
            if let saturationFilter = CIFilter(name: "CIColorControls") {
                saturationFilter.setValue(outputImage, forKey: kCIInputImageKey)
                saturationFilter.setValue(configuration.saturationBoost, forKey: kCIInputSaturationKey)
                if let saturatedImage = saturationFilter.outputImage {
                    outputImage = saturatedImage
                } else {
                    print("[LiquidGlass] Warning: Failed to apply saturation boost")
                }
            } else {
                print("[LiquidGlass] Warning: CIColorControls filter unavailable")
            }
        }

        // Apply tint if specified
        if let tintColor = configuration.tintColor {
            outputImage = applyTint(to: outputImage, color: tintColor, alpha: configuration.tintAlpha)
        }

        // Render to UIImage with error handling
        let extent = outputImage.extent
        guard extent.width > 0 && extent.height > 0 && extent.width.isFinite && extent.height.isFinite else {
            print("[LiquidGlass] Error: Invalid output image extent: \(extent)")
            return image // Return original image as fallback
        }

        guard let cgImage = context.createCGImage(outputImage, from: extent) else {
            print("[LiquidGlass] Error: Failed to create CGImage from CIImage")
            return image // Return original image as fallback
        }

        let blurredImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Cache the result
        cacheBlur(image: blurredImage, key: cacheKey)

        return blurredImage
    }
    
    private static func applyTint(to image: CIImage, color: UIColor, alpha: CGFloat) -> CIImage {
        guard let colorFilter = CIFilter(name: "CIConstantColorGenerator") else {
            return image
        }
        
        let ciColor = CIColor(color: color.withAlphaComponent(alpha))
        colorFilter.setValue(ciColor, forKey: kCIInputColorKey)
        
        guard let colorImage = colorFilter.outputImage else {
            return image
        }
        
        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
            return image
        }
        
        compositeFilter.setValue(colorImage, forKey: kCIInputImageKey)
        compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter.outputImage ?? image
    }
    
    // MARK: - Metal-based Blur (iOS 16+)
    
    @available(iOS 16.0, *)
    public static func applyMetalBlur(
        to image: UIImage,
        configuration: LiquidGlassBlurConfiguration = .standard
    ) -> UIImage? {
        // Use Metal for better performance on iOS 16+
        // This is a placeholder for Metal-based implementation
        // For now, fall back to Core Image
        return applyBlur(to: image, configuration: configuration)
    }
    
    // MARK: - Blur Filter Creation (Documented APIs Only)
    
    /// Creates a CIFilter for blur - uses only documented Core Image APIs
    /// This approach avoids private CAFilter API usage for App Store compliance
    private static func createCIBlurFilter(radius: CGFloat) -> CIFilter? {
        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            return nil
        }
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        return filter
    }
    
    /// Creates blur effect using documented UIBlurEffect API
    /// This is the recommended approach for iOS 13+ blur effects
    public static func createBlurEffect(isDark: Bool) -> UIBlurEffect {
        return UIBlurEffect(style: isDark ? .dark : .light)
    }
    
    // MARK: - Cache Management

    /// Generate unique cache key using image characteristics
    /// Uses size, scale, and memory address instead of hashValue to avoid collisions
    private static func blurCacheKey(for image: UIImage, configuration: LiquidGlassBlurConfiguration) -> String {
        let imageId = String(format: "%.0fx%.0f@%.0fx-%p",
                           image.size.width,
                           image.size.height,
                           image.scale,
                           Unmanaged.passUnretained(image).toOpaque())
        let configId = String(format: "%.1f-%.2f-%.2f",
                             configuration.blurRadius,
                             configuration.saturationBoost,
                             configuration.tintAlpha)
        return "\(imageId)-\(configId)"
    }

    /// Estimate memory size of UIImage in bytes
    private static func estimateImageSize(_ image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return width * height * 4 // 4 bytes per pixel (RGBA)
    }
    
    private static func getCachedBlur(key: String) -> UIImage? {
        var result: UIImage?
        cacheQueue.sync {
            if var entry = blurCache[key] {
                entry.touch() // Update access time
                blurCache[key] = entry
                result = entry.image
            }
        }
        return result
    }
    
    private static func cacheBlur(image: UIImage, key: String) {
        cacheQueue.async {
            let imageSize = estimateImageSize(image)

            // Evict cache entries if we exceed size or count limits
            while (blurCache.count >= maxCacheSize || currentCacheSizeBytes + imageSize > maxCacheSizeBytes) && !blurCache.isEmpty {
                // Find and remove the least recently used entry
                if let oldestEntry = blurCache.min(by: { $0.value.lastAccessTime < $1.value.lastAccessTime }) {
                    let removedSize = estimateImageSize(oldestEntry.value.image)
                    blurCache.removeValue(forKey: oldestEntry.key)
                    currentCacheSizeBytes -= removedSize
                }
            }

            blurCache[key] = CacheEntry(image: image)
            currentCacheSizeBytes += imageSize
        }
    }

    public static func clearBlurCache() {
        cacheQueue.async {
            blurCache.removeAll()
            currentCacheSizeBytes = 0
        }
    }
    
    // MARK: - Performance Optimization
    
    private static var currentFrameRate: Int = 60
    private static var shouldReduceQuality: Bool = false
    
    /// Adjusts blur quality based on performance
    public static func setAdaptiveQuality(enabled: Bool) {
        shouldReduceQuality = enabled
    }
    
    /// Returns optimized configuration based on current performance
    public static func optimizedConfiguration(
        base: LiquidGlassBlurConfiguration = .standard
    ) -> LiquidGlassBlurConfiguration {
        guard shouldReduceQuality else {
            return base
        }
        
        // Reduce quality if performance is poor
        let optimizedRadius = base.blurRadius * 0.75
        return LiquidGlassBlurConfiguration(
            blurRadius: optimizedRadius,
            saturationBoost: base.saturationBoost,
            tintColor: base.tintColor,
            tintAlpha: base.tintAlpha
        )
    }
    
    // MARK: - Update Throttling
    
    private static var lastUpdateTime: CFTimeInterval = 0
    private static let minUpdateInterval: CFTimeInterval = 1.0 / 60.0 // 60 fps
    
    /// Checks if enough time has passed for another blur update
    public static func shouldUpdateBlur() -> Bool {
        let currentTime = CACurrentMediaTime()
        let timeSinceLastUpdate = currentTime - lastUpdateTime
        
        if timeSinceLastUpdate >= minUpdateInterval {
            lastUpdateTime = currentTime
            return true
        }
        return false
    }
    
    /// Throttles blur updates to specified frame rate
    public static func shouldUpdateBlur(targetFPS: Int) -> Bool {
        let targetInterval = 1.0 / Double(targetFPS)
        let currentTime = CACurrentMediaTime()
        let timeSinceLastUpdate = currentTime - lastUpdateTime
        
        if timeSinceLastUpdate >= targetInterval {
            lastUpdateTime = currentTime
            return true
        }
        return false
    }
}

// MARK: - Liquid Glass Blur View

/// A reusable view that provides liquid glass blur effect
public final class LiquidGlassBlurView: UIView {
    
    private let blurView: UIView
    private var configuration: LiquidGlassBlurConfiguration
    
    public var isDark: Bool = false {
        didSet {
            if isDark != oldValue {
                updateAppearance()
            }
        }
    }
    
    public init(
        frame: CGRect = .zero,
        configuration: LiquidGlassBlurConfiguration = .standard,
        isDark: Bool = false
    ) {
        self.configuration = configuration
        self.blurView = LiquidGlassBlurProvider.createBlurView(
            configuration: configuration,
            isDark: isDark
        )
        
        super.init(frame: frame)
        
        self.addSubview(blurView)
        self.blurView.frame = self.bounds
        self.blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.isUserInteractionEnabled = false
        self.layer.allowsGroupOpacity = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateConfiguration(_ configuration: LiquidGlassBlurConfiguration, animated: Bool = false) {
        self.configuration = configuration
        
        let newBlurView = LiquidGlassBlurProvider.createBlurView(
            configuration: configuration,
            isDark: isDark
        )
        newBlurView.frame = self.bounds
        newBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if animated {
            newBlurView.alpha = 0
            self.addSubview(newBlurView)
            
            UIView.animate(withDuration: 0.2, animations: {
                newBlurView.alpha = 1
                self.blurView.alpha = 0
            }, completion: { _ in
                self.blurView.removeFromSuperview()
            })
        } else {
            blurView.removeFromSuperview()
            self.addSubview(newBlurView)
        }
    }
    
    private func updateAppearance() {
        if let effectView = blurView as? UIVisualEffectView {
            effectView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
    }
}

// MARK: - Snapshot Helper

extension LiquidGlassBlurProvider {
    
    /// Creates a blurred snapshot of a view
    public static func createBlurredSnapshot(
        of view: UIView,
        configuration: LiquidGlassBlurConfiguration = .standard
    ) -> UIImage? {
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            return nil
        }
        
        // Create snapshot
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        view.layer.render(in: context)
        guard let snapshot = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        
        // Apply blur
        return applyBlur(to: snapshot, configuration: configuration)
    }
}

// MARK: - CALayer Extension (Documented APIs)

extension CALayer {
    /// Note: For layer-based blur effects, use UIVisualEffectView wrapped in a container
    /// instead of private CAFilter APIs for App Store compliance.
    /// 
    /// Example usage:
    /// ```
    /// let blurEffect = LiquidGlassBlurProvider.createBlurEffect(isDark: isDark)
    /// let blurView = UIVisualEffectView(effect: blurEffect)
    /// containerView.addSubview(blurView)
    /// ```
    
    /// Applies a subtle glass-like background to the layer using documented APIs
    func applyLiquidGlassBackground(isDark: Bool = false, alpha: CGFloat = 0.1) {
        self.backgroundColor = (isDark ? UIColor.black : UIColor.white).withAlphaComponent(alpha).cgColor
    }
    
    /// Removes glass background from layer
    func removeLiquidGlassBackground() {
        self.backgroundColor = nil
    }
}

// MARK: - Backdrop Blur Layer (Documented API Implementation)

/// LiquidGlassBackdropView provides real-time backdrop blur using documented UIKit APIs.
/// This replaces the stubbed CABackdropLayer with a functional implementation.
///
/// Key features:
/// - Uses UIVisualEffectView for blur (documented API, App Store safe)
/// - Provides layer access for CALayer-based compositing
/// - Supports dynamic blur intensity adjustment
/// - iOS 13+ compatible
public final class LiquidGlassBackdropView: UIView {
    
    private let blurEffectView: UIVisualEffectView
    private let saturationView: UIView
    
    public var blurRadius: CGFloat = 10.0 {
        didSet {
            updateBlurIntensity()
        }
    }
    
    public var isDark: Bool = false {
        didSet {
            if isDark != oldValue {
                updateBlurStyle()
            }
        }
    }
    
    public override init(frame: CGRect) {
        let blurStyle: UIBlurEffect.Style = .light
        let blurEffect = UIBlurEffect(style: blurStyle)
        self.blurEffectView = UIVisualEffectView(effect: blurEffect)
        self.saturationView = UIView()
        
        super.init(frame: frame)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Add blur effect view
        blurEffectView.frame = bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurEffectView)
        
        // Add saturation overlay for enhanced glass effect
        saturationView.frame = bounds
        saturationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        saturationView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        saturationView.isUserInteractionEnabled = false
        blurEffectView.contentView.addSubview(saturationView)
        
        // Allow group opacity for layer compositing
        layer.allowsGroupOpacity = true
        
        // Continuous corners for iOS 13+
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
            blurEffectView.layer.cornerCurve = .continuous
        }
    }
    
    private func updateBlurStyle() {
        let style: UIBlurEffect.Style = isDark ? .dark : .light
        blurEffectView.effect = UIBlurEffect(style: style)
        saturationView.backgroundColor = (isDark ? UIColor.black : UIColor.white).withAlphaComponent(0.1)
    }
    
    private func updateBlurIntensity() {
        // Blur intensity is controlled by effect style
        // For variable intensity, we adjust the saturation overlay alpha
        let normalizedRadius = min(blurRadius / 20.0, 1.0)
        saturationView.alpha = 0.1 + (normalizedRadius * 0.15)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        blurEffectView.frame = bounds
        saturationView.frame = bounds
    }
    
    /// Provides the blur layer for CALayer-based compositing
    public var blurLayer: CALayer {
        return blurEffectView.layer
    }
    
    /// Convenience method to create a layer snapshot for layer-only contexts
    /// Note: For best results, use the view directly when possible
    public func createBlurLayerSnapshot(size: CGSize) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: size)
        containerLayer.backgroundColor = (isDark ? UIColor.black : UIColor.white).withAlphaComponent(0.2).cgColor
        containerLayer.allowsGroupOpacity = true
        
        if #available(iOS 13.0, *) {
            containerLayer.cornerCurve = .continuous
        }
        
        return containerLayer
    }
}

// MARK: - CALayer Extension for Backdrop Blur

extension CALayer {
    /// Applies a backdrop blur effect using a LiquidGlassBackdropView
    /// This is the recommended approach for layer-based blur on pre-iOS 26 devices
    ///
    /// Example usage:
    /// ```swift
    /// let backdropView = layer.addLiquidGlassBackdrop(
    ///     to: hostView,
    ///     size: CGSize(width: 100, height: 100),
    ///     cornerRadius: 20
    /// )
    /// ```
    @discardableResult
    public func addLiquidGlassBackdrop(
        to hostView: UIView,
        size: CGSize,
        cornerRadius: CGFloat = 0,
        isDark: Bool = false
    ) -> LiquidGlassBackdropView {
        let backdropView = LiquidGlassBackdropView(frame: CGRect(origin: .zero, size: size))
        backdropView.isDark = isDark
        backdropView.layer.cornerRadius = cornerRadius
        backdropView.clipsToBounds = true
        
        hostView.insertSubview(backdropView, at: 0)
        
        return backdropView
    }
}

