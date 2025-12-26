import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import TelegramPresentationData
import LiquidGlassAnimations
import LiquidGlassBlurProvider

public final class SwitchComponent: Component {
    public typealias EnvironmentType = Empty
    
    let tintColor: UIColor?
    let value: Bool
    let valueUpdated: (Bool) -> Void
    
    public init(
        tintColor: UIColor? = nil,
        value: Bool,
        valueUpdated: @escaping (Bool) -> Void
    ) {
        self.tintColor = tintColor
        self.value = value
        self.valueUpdated = valueUpdated
    }
    
    public static func ==(lhs: SwitchComponent, rhs: SwitchComponent) -> Bool {
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let switchNode: LiquidGlassSwitchNode
    
        private var component: SwitchComponent?
        
        override init(frame: CGRect) {
            self.switchNode = LiquidGlassSwitchNode()
            
            super.init(frame: frame)
            
            self.addSubnode(self.switchNode)
            
            self.switchNode.valueChanged = { [weak self] value in
                self?.component?.valueUpdated(value)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SwitchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
          
            if let tintColor = component.tintColor {
                self.switchNode.onTintColor = tintColor
            }
            self.switchNode.setOn(component.value, animated: !transition.animation.isImmediate)
            
            let switchSize = self.switchNode.calculateSizeThatFits(availableSize)
            self.switchNode.frame = CGRect(origin: .zero, size: switchSize)
                        
            return switchSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
