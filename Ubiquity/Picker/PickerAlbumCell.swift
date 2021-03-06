//
//  PickerAlbumCell.swift
//  Ubiquity
//
//  Created by SAGESSE on 6/9/17.
//  Copyright © 2017 SAGESSE. All rights reserved.
//

import UIKit

internal class PickerAlbumCell: BrowserAlbumCell, ContainerOptionsDelegate {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _configure()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // check responser for super
        guard let view = super.hitTest(point, with: event) else {
            return nil
        }
        
        // extend response region
        guard !selectedStatusView.isHidden, view === contentView, UIEdgeInsetsInsetRect(selectedStatusView.frame, UIEdgeInsetsMake(-8, -8, -8, -8)).contains(point) else {
            return view
        }
        
        return selectedStatusView
    }
    
    /// Update selection status for animate
    private func setStatus(_ status: SelectionStatus?, animated: Bool) {
        
        if !isSelectedMode {
            selectedStatusView.status = nil
            selectedForegroundView.isHidden = true
        }else{
            selectedStatusView.status = status
            selectedForegroundView.isHidden = !isSelectedMode ? true : !selectedStatusView.isSelected
        }
        
        
        // need add animation?
        guard animated else {
            return
        }
        
        let ani = CAKeyframeAnimation(keyPath: "transform.scale")
        
        ani.values = [0.8, 1.2, 1]
        ani.duration = 0.25
        ani.calculationMode = kCAAnimationCubic
        
        selectedStatusView.layer.add(ani, forKey: "selected")
    }
    
    override func willDisplay(_ container: Container, orientation: UIImageOrientation) {
        super.willDisplay(container, orientation: orientation)
        
        // if it is not picker, ignore
        guard let asset = asset, let picker = container as? Picker else {
            return
        }

        // update cell selection status
        setStatus(picker.statusOfItem(with: asset), animated: false)

        // update options for picker
//        selectedStatusView.isHidden = !picker.allowsSelection
//        selectedForegroundView.isHidden = !picker.allowsSelection || !selectedStatusView.isSelected
    }
    
    // MARK: Options change
    
    func ub_container(_ container: Container, options: String, didChange value: Any?) {
        // if it is not picker, ignore
//        guard let picker = container as? Picker, options == "allowsSelection" else {
//            return
//        }
        // the selection of whether to support the cell
//        selectedStatusView.isHidden = !picker.allowsSelection
//        selectedForegroundView.isHidden = !picker.allowsSelection || !selectedStatusView.isSelected
    }
    
    open func select() {
        if isSelectedMode {
            _select(selectedStatusView)
        }
    }

    @objc private dynamic func _select(_ sender: Any) {
        // the asset must be set
        // if it is not picker, ignore
        guard let asset = asset, let picker = container as? Picker else {
            return
        }
        
        // check old status
        if status == nil {
            // select asset
            setStatus(picker.selectItem(with: asset, sender: self), animated: true)
            
        } else {
            // deselect asset
            setStatus(picker.deselectItem(with: asset, sender: self), animated: true)
        }
    }
    
    // Init UI
    private func _configure() {
        
        // setup selected view
        selectedStatusView.frame = .init(x: bounds.width - contentInset.right - 24, y: contentInset.top, width: 24, height: 24)
        selectedStatusView.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        selectedStatusView.addTarget(self, action: #selector(_select(_:)), for: .touchUpInside)
        
        // setup selected background view
        selectedForegroundView.frame = bounds
        selectedForegroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.2)
        selectedForegroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        selectedForegroundView.isUserInteractionEnabled = false
        selectedForegroundView.isHidden = true
        
        // enable user interaction
        contentView.isUserInteractionEnabled = true
        
        // add subview
        contentView.addSubview(selectedStatusView)
        contentView.insertSubview(selectedForegroundView, at: 0)
    }
    
    // MARK: Property
    
    /// The picker selection background view.
    lazy var selectedForegroundView: UIView = UIView()
    
    /// The picker selection status view.
    lazy var selectedStatusView: SelectionStatusView = SelectionStatusView()
    
    /// The asset selection status
    var status: SelectionStatus? {
        set { return setStatus(newValue, animated: false) }
        get { return selectedStatusView.status }
    }
    
    open var isSelectedMode: Bool = true
        {
        willSet{
            
            if self.isSelectedMode == newValue {
                return
            }
            
            self.isSelectedMode = newValue
            selectedForegroundView.isHidden = true
            if !newValue {
                selectedStatusView.isHidden = true
            }else{
                selectedStatusView.isHidden = false
            }
            // deselect asset
            if status != nil {
                status = (container as? Picker)?.deselectItem(with: asset!, sender: self)
            }
        }
    }

}
