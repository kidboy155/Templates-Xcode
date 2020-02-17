//
//  ASValueTrackingSlider.swift
//  ValuePopUpView
//
//  Created by QuocNV on 2/17/20.
//  Copyright © 2020 QuocNV. All rights reserved.
//

import Foundation
import UIKit
// to supply custom text to the popUpView label, implement <ASValueTrackingSliderDataSource>
// the dataSource will be messaged each time the slider value changes

protocol ASValueTrackingSliderDataSource: NSObjectProtocol {
    func slider(_ slider: ASValueTrackingSlider?, stringForValue value: Float) -> String?
}
// when embedding an ASValueTrackingSlider inside a TableView or CollectionView
// you need to ensure that the cell it resides in is brought to the front of the view hierarchy
// to prevent the popUpView from being obscured

@objc protocol ASValueTrackingSliderDelegate: NSObjectProtocol {
    func sliderWillDisplayPopUpView(_ slider: ASValueTrackingSlider?)

    @objc optional func sliderWillHidePopUpView(_ slider: ASValueTrackingSlider?)
    @objc optional func sliderDidHidePopUpView(_ slider: ASValueTrackingSlider?)
}
class ASValueTrackingSlider: UISlider, ASValuePopUpViewDelegate {
    // present the popUpView manually, without touch event.
    func showPopUpView(animated: Bool) {
        popUpViewAlwaysOn = true
        _showPopUpView(animated: animated)
    }

    // the popUpView will not hide again until you call 'hidePopUpViewAnimated:'
    func hidePopUpView(animated: Bool) {
        popUpViewAlwaysOn = false
        _hidePopUpView(animated: animated)
    }

    var textColor: UIColor?
    // font can not be nil, it must be a valid UIFont
    // default is ‘boldSystemFontOfSize:22.0’
    var font: UIFont?
    // setting the value of 'popUpViewColor' overrides 'popUpViewAnimatedColors' and vice versa
    // the return value of 'popUpViewColor' is the currently displayed value
    // this will vary if 'popUpViewAnimatedColors' is set (see below)
    var popUpViewColor: UIColor?
    // pass an array of 2 or more UIColors to animate the color change as the slider moves
    var popUpViewAnimatedColors: [AnyHashable]?

    // cornerRadius of the popUpView, default is 4.0
    var popUpViewCornerRadius: CGFloat = 0.0{
        didSet{
            popUpView.cornerRadius = popUpViewCornerRadius
        }
    }
    // arrow height of the popUpView, default is 13.0
    var popUpViewArrowLength: CGFloat = 0.0
    // width padding factor of the popUpView, default is 1.15
    var popUpViewWidthPaddingFactor: CGFloat = 0.0
    // height padding factor of the popUpView, default is 1.1
    var popUpViewHeightPaddingFactor: CGFloat = 0.0
    // changes the left handside of the UISlider track to match current popUpView color
    // the track color alpha is always set to 1.0, even if popUpView color is less than 1.0
    var autoAdjustTrackColor = false// (default is YES)
    // take full control of the format dispayed with a custom NSNumberFormatter
    var numberFormatter: NumberFormatter!
    // supply entirely customized strings for slider values using the datasource protocol - see below
    weak var dataSource: ASValueTrackingSliderDataSource?
    // delegate is only needed when used with a TableView or CollectionView - see below
    weak var delegate: ASValueTrackingSliderDelegate?
    
    private var popUpView: ASValuePopUpView!
    private var popUpViewAlwaysOn = false // default is NO
    private var keyTimes: [AnyHashable]?
    private var valueRange: CGFloat = 0.0
    
    // MARK: - initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    // MARK: - public
    func setAutoAdjustTrackColor(_ autoAdjust: Bool) {
        if autoAdjustTrackColor == autoAdjust {
            return
        }

        autoAdjustTrackColor = autoAdjust

        // setMinimumTrackTintColor has been overridden to also set autoAdjustTrackColor to NO
        // therefore super's implementation must be called to set minimumTrackTintColor
        if autoAdjust == false {
            super.minimumTrackTintColor = nil // sets track to default blue color
        } else {
            super.minimumTrackTintColor = popUpView.opaqueColor()
        }
    }
    func setTextColor(_ color: UIColor?) {
        textColor = color
        popUpView.setTextColor(color)
    }

    func setFont(_ font: UIFont?) {
        assert(font != nil, "font can not be nil, it must be a valid UIFont")
        self.font = font
        popUpView.setFont(font)
    }

    func setPopUpViewColor(_ color: UIColor?) {
        popUpViewColor = color
        popUpViewAnimatedColors = nil // animated colors should be discarded
        popUpView.setColor(color)

        if autoAdjustTrackColor {
            super.minimumTrackTintColor = popUpView.opaqueColor()
        }
    }
    
    // the above @property distributes the colors evenly across the slider
    // to specify the exact position of colors on the slider scale, pass an NSArray of NSNumbers
    // if 2 or more colors are present, set animated colors
    // if only 1 color is present then call 'setPopUpViewColor:'
    // if arg is nil then restore previous _popUpViewColor
    func setPopUpViewAnimatedColors(_ colors: [AnyHashable]?, withPositions positions: [AnyHashable]?) {
        guard positions != nil else {
            setPopUpViewAnimatedColors(colors, withPositions: nil)
            return
        }

        popUpViewAnimatedColors = colors
        keyTimes = keyTimes(fromSliderPositions: positions)

        if (colors?.count ?? 0) >= 2 {
            popUpView.setAnimatedColors(colors, withKeyTimes: keyTimes)
        } else {
            self.popUpViewColor = colors?.last as? UIColor
        }
    }
    
    func setPopUpViewCornerRadius(_ radius: CGFloat) {
        popUpView.cornerRadius = radius
    }

//    func popUpViewCornerRadius() -> CGFloat {
//        return popUpView.cornerRadius
//    }
    func setPopUpViewArrowLength(_ length: CGFloat) {
        popUpView.arrowLength = length
    }

//    func popUpViewArrowLength() -> CGFloat {
//        return popUpView.arrowLength
//    }

    func setPopUpViewWidthPaddingFactor(_ factor: CGFloat) {
        popUpView.widthPaddingFactor = factor
    }
//    func popUpViewWidthPaddingFactor() -> CGFloat {
//        return popUpView.widthPaddingFactor
//    }

    func setPopUpViewHeightPaddingFactor(_ factor: CGFloat) {
        popUpView.heightPaddingFactor = factor
    }

//    func popUpViewHeightPaddingFactor() -> CGFloat {
//        return popUpView.heightPaddingFactor
//    }
    
    // when either the min/max value or number formatter changes, recalculate the popUpView width
    func setMaximumValue(maximumValue: Float){
        super.maximumValue = maximumValue
        valueRange = CGFloat(self.maximumValue - self.minimumValue)
    }
    func setMinimumValue(minimumValue: Float){
       super.minimumValue = minimumValue
       valueRange = CGFloat(self.maximumValue - self.minimumValue)
    }
    // set max and min digits to same value to keep string length consistent
    // when setting max FractionDigits the min value is automatically set to the same value
    // this ensures that the PopUpView frame maintains a consistent width
    func setMaxFractionDigitsDisplayed(_ maxDigits: Int) {
        numberFormatter.maximumFractionDigits = maxDigits
        numberFormatter.minimumFractionDigits = maxDigits
    }

    func setNumberFormatter(numberFormatter: NumberFormatter){
        self.numberFormatter = numberFormatter
    }

    // MARK: - ASValuePopUpViewDelegate
    func colorDidUpdate(_ opaqueColor: UIColor?) {
        super.minimumTrackTintColor = opaqueColor
    }
    // returns the current offset of UISlider value in the range 0.0 – 1.0

    func currentValueOffset() -> CGFloat {
        return CGFloat(truncating: NSNumber(value: (value - minimumValue) / Float(valueRange)))
    }
    // MARK: - private
    func setup() {
        autoAdjustTrackColor = true
        valueRange = CGFloat(maximumValue - minimumValue)
        popUpViewAlwaysOn = false

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        numberFormatter = formatter

        popUpView = ASValuePopUpView(frame: CGRect.zero)
        popUpViewColor = UIColor(hue: 0.6, saturation: 0.6, brightness: 0.5, alpha: 0.8)

        popUpView.alpha = 0.0
        popUpView.delegate = self
        addSubview(popUpView)

        textColor = UIColor.white
        font = UIFont.boldSystemFont(ofSize: 22.0)
    }
    // ensure animation restarts if app is closed then becomes active again

    @objc func didBecomeActiveNotification(_ note: Notification?) {
        if let popUpViewAnimatedColors = popUpViewAnimatedColors {
            popUpView.setAnimatedColors(popUpViewAnimatedColors, withKeyTimes: keyTimes)
        }
    }
    func updatePopUpView() {
        var valueString: String?
        var popUpViewSize: CGSize
        // ask dataSource for string, if nil or blank, get string from _numberFormatter
        if let valueString = dataSource?.slider(self, stringForValue: value), valueString.count > 0{
//        if (valueString = dataSource?.slider(self, stringForValue: value)) != nil && (valueString?.count ?? 0) != 0 {
            popUpViewSize = popUpView.popUpSize(for: valueString)
        } else {
            valueString = numberFormatter.string(from: NSNumber(value: value))
            popUpViewSize = calculatePopUpViewSize()
        }

        // calculate the popUpView frame
        let thumbRect = self.thumbRect()
        let thumbW = thumbRect.size.width
        let thumbH = thumbRect.size.height

        var popUpRect = thumbRect.insetBy(dx: (thumbW - popUpViewSize.width) / 2, dy: (thumbH - popUpViewSize.height) / 2)
        popUpRect.origin.y = thumbRect.origin.y - popUpViewSize.height

        // determine if popUpRect extends beyond the frame of the progress view
        // if so adjust frame and set the center offset of the PopUpView's arrow
        let minOffsetX = popUpRect.minX
        let maxOffsetX: CGFloat = popUpRect.maxX - bounds.width

        let offset = minOffsetX < 0.0 ? minOffsetX : (maxOffsetX > 0.0 ? maxOffsetX : 0.0)
        popUpRect.origin.x -= offset

        popUpView.setFrame(popUpRect, arrowOffset: offset, text: valueString)
    }
    func calculatePopUpViewSize() -> CGSize {
        // negative values need more width than positive values
        let minValSize = popUpView.popUpSize(for: numberFormatter.string(from: NSNumber(value: minimumValue )))
        let maxValSize = popUpView.popUpSize(for: numberFormatter.string(from: NSNumber(value: maximumValue )))

        return (minValSize.width >= maxValSize.width) ? minValSize : maxValSize
    }

    // takes an array of NSNumbers in the range self.minimumValue - self.maximumValue
    // returns an array of NSNumbers in the range 0.0 - 1.0

    func keyTimes(fromSliderPositions positions: [AnyHashable]?) -> [AnyHashable]? {
        guard let positions = positions else {
            return nil
        }

        var keyTimes: [AnyHashable] = []
        for num in positions{
            guard let num = num as? NSNumber else {
                continue
            }
            let value = (num.floatValue - minimumValue) / Float(valueRange)
            keyTimes.append(NSNumber(value: value))
        }
        return keyTimes
    }

    func thumbRect() -> CGRect {
        return thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
    }
    
    func _showPopUpView(animated: Bool) {
        delegate?.sliderWillDisplayPopUpView(self)
        popUpView.show(animated: animated)
    }

    func _hidePopUpView(animated: Bool) {
        if let delegateSliderDidHidePopUpView = delegate?.sliderWillHidePopUpView {
            delegateSliderDidHidePopUpView(self)
        }
        popUpView.hide(animated: animated, completionBlock: {
            if let delegateSliderDidHidePopUpView = self.delegate?.sliderDidHidePopUpView {
                delegateSliderDidHidePopUpView(self)
            }
        })
    }
    
    // MARK: - subclassed
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePopUpView()
    }

    override func didMoveToWindow() {
        if let _ = window {
            // removed from window - cancel notifications
            NotificationCenter.default.removeObserver(self)
        } else {
            // added to window - register notifications

            if let popUpViewAnimatedColors = popUpViewAnimatedColors {
                // restart color animation if needed
                popUpView.setAnimatedColors(popUpViewAnimatedColors, withKeyTimes: keyTimes)
            }

            NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNotification(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    func setValue(_ value: Float) {
        super.setValue(value, animated: true)
        popUpView.setAnimationOffset(currentValueOffset(), returnColor: { opaqueReturnColor in
            super.minimumTrackTintColor = opaqueReturnColor
        })
    }

    override func setValue(_ value: Float, animated: Bool) {
        if animated {
            popUpView.animateBlock({ duration in
                UIView.animate(withDuration: TimeInterval(duration), animations: {
                    super.setValue(value, animated: animated)
                    self.popUpView.setAnimationOffset(self.currentValueOffset(), returnColor: { opaqueReturnColor in
                        super.minimumTrackTintColor = opaqueReturnColor
                    })
                    self.layoutIfNeeded()
                })
            })
        } else {
            super.setValue(value, animated: animated)
        }
    }
    
    func setMinimumTrackTintColor(color: UIColor){
        self.autoAdjustTrackColor = false // if a custom value is set then prevent auto coloring
        super.minimumTrackTintColor = color
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let begin = super.beginTracking(touch, with: event)
        if begin && !popUpViewAlwaysOn {
            _showPopUpView(animated: true)
        }
        return begin
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let continueTrack = super.continueTracking(touch, with: event)
        if continueTrack {
            popUpView.setAnimationOffset(currentValueOffset(), returnColor: { opaqueReturnColor in
                super.minimumTrackTintColor = opaqueReturnColor
            })
        }
        return continueTrack
    }
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        if popUpViewAlwaysOn == false {
            _hidePopUpView(animated: true)
        }
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        if popUpViewAlwaysOn == false {
            _hidePopUpView(animated: true)
        }
    }
}
