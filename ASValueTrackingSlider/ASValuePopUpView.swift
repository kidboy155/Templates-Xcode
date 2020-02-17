//
//  ASValuePopUpView.swift
//  ValuePopUpView
//
//  Created by QuocNV on 2/17/20.
//  Copyright © 2020 QuocNV. All rights reserved.
//

import Foundation
import UIKit

protocol ASValuePopUpViewDelegate: NSObjectProtocol {
    func currentValueOffset() -> CGFloat //expects value in the range 0.0 - 1.0
    func colorDidUpdate(_ opaqueColor: UIColor?)
}

extension CALayer {
    func animateKey(_ animationName: String?, fromValue: Any?, toValue: Any?, customize block: @escaping (_ animation: CABasicAnimation?) -> Void) {
        setValue(toValue, forKey: animationName ?? "")
        let anim = CABasicAnimation(keyPath: animationName)
        anim.fromValue = fromValue ?? presentation()?.value(forKey: animationName ?? "")
        anim.toValue = toValue
        block(anim)
        add(anim, forKey: animationName)
    }
}

class ASValuePopUpView: UIView, CAAnimationDelegate {
    weak var delegate: ASValuePopUpViewDelegate?
    var cornerRadius: CGFloat = 0.0
    var arrowLength: CGFloat = 0.0
    var widthPaddingFactor: CGFloat = 0.0
    var heightPaddingFactor: CGFloat = 0.0
    let SliderFillColorAnim = "fillColor"
    
    var shouldAnimate: Bool = true
    var animDuration: CFTimeInterval = 0.0

    var attributedString: NSMutableAttributedString!
    var pathLayer: CAShapeLayer!
    var font: UIFont?

    var textLayer: CATextLayer!
    var arrowCenterOffset: CGFloat = 0.0

    // never actually visible, its purpose is to interpolate color values for the popUpView color animation
    // using shape layer because it has a 'fillColor' property which is consistent with _backgroundLayer
    var colorAnimLayer: CAShapeLayer!
    
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }

    private func opaqueUIColorFromCGColor(_ col: CGColor?) -> UIColor? {
        if col == nil {
            return nil
        }

        let components = col?.components
        var color: UIColor?
        if col?.numberOfComponents == 2 {
            color = UIColor(white: components?[0] ?? 0.0, alpha: 1.0)
        } else {
            color = UIColor(red: components?[0] ?? 0.0, green: components?[1] ?? 0.0, blue: components?[2] ?? 0.0, alpha: 1.0)
        }
        return color
    }
    // if ivar _shouldAnimate) is YES then return an animation
    // otherwise return NSNull (no animation)

    override func action(for layer: CALayer, forKey key: String) -> CAAction? {
        if shouldAnimate {
            let anim = CABasicAnimation(keyPath: key)
            anim.beginTime = CACurrentMediaTime()
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anim.fromValue = layer.presentation()?.value(forKey: key)
            anim.duration = animDuration
            return anim
        } else {
            return nil
        }
    }

    // MARK: public function
    override init(frame: CGRect) {

        super.init(frame: frame)
        shouldAnimate = false
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)

        isUserInteractionEnabled = false
        pathLayer = layer as? CAShapeLayer // ivar can now be accessed without casting to CAShapeLayer every time

        cornerRadius = 4.0
        arrowLength = 13.0
        widthPaddingFactor = 1.15
        heightPaddingFactor = 1.1

        textLayer = CATextLayer()
        textLayer.alignmentMode = .center
        textLayer.anchorPoint = CGPoint(x: 0, y: 0)
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.actions = [
        "contents": NSNull()
        ]

        colorAnimLayer = CAShapeLayer()

        layer.addSublayer(colorAnimLayer)
        layer.addSublayer(textLayer)
        attributedString = NSMutableAttributedString(string: " ", attributes: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    func setCornerRadius(radius: CGFloat){
        if cornerRadius == radius {
            return
        }
        cornerRadius = radius
//        pathLayer.path = path(forRect: bounds, withArrowOffset: arrowCenterOffset).cgPath
        pathLayer.shadowPath = UIBezierPath(rect: bounds).cgPath
        pathLayer.shadowRadius = arrowCenterOffset
    }

    func color() -> UIColor? {
        if let fill = pathLayer.presentation()?.fillColor {
            return UIColor(cgColor: fill)
        }
        return nil
    }

    func setColor(_ color: UIColor?) {
        pathLayer.fillColor = color?.cgColor
        colorAnimLayer.removeAnimation(forKey: SliderFillColorAnim) // single color, no animation required
    }

    func opaqueColor() -> UIColor? {
        return opaqueUIColorFromCGColor(colorAnimLayer.presentation()?.fillColor ?? pathLayer.fillColor)
    }

    func setTextColor(_ color: UIColor?) {
        textLayer.foregroundColor = color?.cgColor
    }

    func setFont(_ font: UIFont?) {
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedString.length))

        textLayer.font = font?.fontName as CFTypeRef?
        textLayer.fontSize = font?.pointSize ?? 0.0
        
        self.font = font
    }

    func setText(_ string: String?) {
        textLayer.string = string
    }
    // set up an animation, but prevent it from running automatically
    // the animation progress will be adjusted manually
    func setAnimatedColors(_ animatedColors: [AnyHashable]?, withKeyTimes keyTimes: [AnyHashable]?) {
        var cgColors: [AnyHashable] = []
        for col in animatedColors ?? [] {
            guard let col = col as? UIColor else {
                continue
            }
            cgColors.append(col.cgColor)
        }

        let colorAnim = CAKeyframeAnimation(keyPath: SliderFillColorAnim)
        colorAnim.keyTimes = keyTimes as? [NSNumber]
        colorAnim.values = cgColors
        colorAnim.fillMode = .both
        colorAnim.duration = 1.0
        colorAnim.delegate = self

        // As the interpolated color values from the presentationLayer are needed immediately
        // the animation must be allowed to start to initialize _colorAnimLayer's presentationLayer
        // hence the speed is set to min value - then set to zero in 'animationDidStart:' delegate method
        colorAnimLayer.speed = Float.leastNormalMagnitude
        colorAnimLayer.timeOffset = 0.0

        colorAnimLayer.add(colorAnim, forKey: SliderFillColorAnim)
    }

   func setAnimationOffset(_ animOffset: CGFloat, returnColor block: @escaping (_ opaqueReturnColor: UIColor?) -> Void) {
        if colorAnimLayer.animation(forKey: SliderFillColorAnim) != nil {
            colorAnimLayer.timeOffset = CFTimeInterval(animOffset)
            pathLayer.fillColor = colorAnimLayer.presentation()?.fillColor
            block(opaqueColor())
        }
    }

    func setFrame(_ frame: CGRect, arrowOffset: CGFloat, text: String?) {
        // only redraw path if either the arrowOffset or popUpView size has changed
        if arrowOffset != arrowCenterOffset || !frame.size.equalTo(self.frame.size) {
//            pathLayer.path = path(for: frame, withArrowOffset: arrowOffset).cgPath
            pathLayer.shadowPath = UIBezierPath(rect: bounds).cgPath
            pathLayer.shadowRadius = arrowCenterOffset
        }
        arrowCenterOffset = arrowOffset

        let anchorX = 0.5 + (arrowOffset / frame.width)
        layer.anchorPoint = CGPoint(x: anchorX, y: 1)
        layer.position = CGPoint(x: frame.minX + frame.width * anchorX, y: 0)
        layer.bounds = .init(origin: .zero, size: frame.size)

        self.setText(text)
    }
    // _shouldAnimate = YES; causes 'actionForLayer:' to return an animation for layer property changes
    // call the supplied block, then set _shouldAnimate back to NO
    func animateBlock(_ block: @escaping (_ duration: CFTimeInterval) -> Void) {
        shouldAnimate = true
        animDuration = 0.5

        if let anim = layer.animation(forKey: "position") {
            // if previous animation hasn't finished reduce the time of new animation
            let elapsedTime = min(CACurrentMediaTime() - (anim.beginTime), anim.duration)
            animDuration = animDuration * elapsedTime / (anim.duration)
        }

        block(animDuration)
        shouldAnimate = false
    }

    func popUpSize(for string: String?) -> CGSize {
        attributedString = NSMutableAttributedString(string: string ?? "")
        var w: CGFloat
        var h: CGFloat
        w = CGFloat(ceilf(Float(attributedString.size().width * widthPaddingFactor)))
        h = CGFloat(ceilf(Float((attributedString.size().height * heightPaddingFactor) + arrowLength)))
        return CGSize(width: w, height: h)
    }


    func show(animated: Bool) {
        if !animated {
            layer.opacity = 1.0
            return
        }

       CATransaction.begin()
        do {
            let fromValue = layer.animation(forKey: "transform") != nil ? (layer.presentation()?.value(forKey: "transform") as? NSValue) : NSValue(caTransform3D: CATransform3DMakeScale(0.5, 0.5, 1))

            layer.animateKey("transform", fromValue: fromValue, toValue: NSValue(caTransform3D: CATransform3DIdentity), customize: { animation in
                animation?.duration = 0.4
                animation?.timingFunction = CAMediaTimingFunction(controlPoints: 0.8, _: 2.5, _: 0.35, _: 0.5)
            })

            layer.animateKey("opacity", fromValue: nil, toValue: NSNumber(value: 1.0), customize: { animation in
                animation?.duration = 0.1
            })
        }
        CATransaction.commit()
    }

    func hide(animated: Bool, completionBlock block: @escaping () -> Void) {
        CATransaction.begin()
        do {
            CATransaction.setCompletionBlock({
                block()
                self.layer.transform = CATransform3DIdentity
            })
            if animated {
                layer.animateKey("transform", fromValue: nil, toValue: NSValue(caTransform3D: CATransform3DMakeScale(0.5, 0.5, 1)), customize: { animation in
                    animation?.duration = 0.55
                    animation?.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, _: -2, _: 0.3, _: 3)
                })

                layer.animateKey("opacity", fromValue: nil, toValue: NSNumber(value: 0.0), customize: { animation in
                    animation?.duration = 0.75
                })
            } else {
                // not animated - just set opacity to 0.0
                layer.opacity = 0.0
            }
        }
        CATransaction.commit()
    }
    // MARK: - CAAnimation delegate
    // set the speed to zero to freeze the animation and set the offset to the correct value
    // the animation can now be updated manually by explicity setting its 'timeOffset'

    func animationDidStart(_ animation: CAAnimation) {
        colorAnimLayer.speed = 0.0
        if let currentValueOffset = delegate?.currentValueOffset(){
            colorAnimLayer.timeOffset = CFTimeInterval(currentValueOffset)
        }

        pathLayer.fillColor = colorAnimLayer.presentation()?.fillColor
        delegate?.colorDidUpdate(opaqueColor())
    }
    // MARK: - private
    func path(for rect: CGRect, withArrowOffset arrowOffset: CGFloat) -> UIBezierPath? {
        var rect = rect
        if rect.equalTo(CGRect.zero) {
            return nil
        }

        rect = CGRect(origin: .zero, size: rect.size) // ensure origin is CGPointZero

        // Create rounded rect
        var roundedRect = rect
        roundedRect.size.height -= self.arrowLength
        let popUpPath = UIBezierPath(roundedRect: roundedRect, cornerRadius: cornerRadius)

        // Create arrow path
        let maxX = roundedRect.maxX // prevent arrow from extending beyond this point
        let arrowTipX = rect.midX + arrowOffset
        let tip = CGPoint(x: arrowTipX, y: rect.maxY)

        let arrowLength: CGFloat = roundedRect.height / 2.0
        let x = arrowLength * tan(45.0 * .pi / 180) // x = half the length of the base of the arrow

        let arrowPath = UIBezierPath()
        arrowPath.move(to: tip)
        arrowPath.addLine(to: CGPoint(x: max(arrowTipX - x, 0), y: roundedRect.maxY - arrowLength))
        arrowPath.addLine(to: CGPoint(x: min(arrowTipX + x, maxX), y: roundedRect.maxY - arrowLength))
        arrowPath.close()

        popUpPath.append(arrowPath)

        return popUpPath
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let tempLabel = UILabel()
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.font = self.font
        tempLabel.attributedText = attributedString

        let newSize = tempLabel.sizeThatFits(.init(width: bounds.size.width, height: .infinity))
        let textRect = CGRect(x: bounds.origin.x, y: (bounds.size.height - arrowLength - newSize.height) / 2, width: newSize.width, height: newSize.height)
        textLayer.frame = textRect.integral
    }
    static func opaqueUIColorFromCGColor(_ col: CGColor?) -> UIColor? {
        if col == nil {
            return nil
        }

        let components = col?.components
        var color: UIColor?
        if col?.numberOfComponents == 2 {
            color = UIColor(white: components?[0] ?? 0.0, alpha: 1.0)
        } else {
            color = UIColor(red: components?[0] ?? 0.0, green: components?[1] ?? 0.0, blue: components?[2] ?? 0.0, alpha: 1.0)
        }
        return color
    }

}

