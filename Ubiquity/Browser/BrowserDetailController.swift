//
//  BrowserDetailController.swift
//  Ubiquity
//
//  Created by sagesse on 16/03/2017.
//  Copyright © 2017 SAGESSE. All rights reserved.
//

import UIKit

internal class BrowserDetailController: UICollectionViewController {
    
    init(source: DataSource, library: Library, at indexPath: IndexPath) {
        _source = source
        _library = library.ub_cache
        _itemIndexPath = indexPath
        
        let collectionViewLayout = BrowserDetailLayout()
        
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumLineSpacing = -extraContentInset.left * 2
        collectionViewLayout.minimumInteritemSpacing = -extraContentInset.right * 2
        collectionViewLayout.headerReferenceSize = CGSize(width: -extraContentInset.left, height: 0)
        collectionViewLayout.footerReferenceSize = CGSize(width: -extraContentInset.right, height: 0)

        super.init(collectionViewLayout: collectionViewLayout)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// collection view cell class provider
    var collectionViewCellProvider: Templatize.Type {
        return BrowserDetailCell.self
    }
//    /// indicator view cell class provider
//    var indicatorViewCellProvider: Templatize.Type {
//        return BrowserAlbumCell.self
//    }
    
    override func loadView() {
        super.loadView()
        // setup controller
        title = "Detail"
        automaticallyAdjustsScrollViewInsets = false
        
        // setup view
        view.clipsToBounds = true
        view.backgroundColor = .white
        
        // setup gesture recognizer
        interactiveDismissGestureRecognizer.delegate = self
        interactiveDismissGestureRecognizer.maximumNumberOfTouches = 1
        interactiveDismissGestureRecognizer.addTarget(self, action: #selector(_handleDismiss(_:)))
        
        view.addGestureRecognizer(interactiveDismissGestureRecognizer)
        
        // setup colleciton view
        collectionView?.frame = UIEdgeInsetsInsetRect(view.bounds, extraContentInset)
        collectionView?.scrollsToTop = false
        collectionView?.isPagingEnabled = true
        collectionView?.alwaysBounceVertical = false
        collectionView?.alwaysBounceHorizontal = true
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
        collectionView?.allowsMultipleSelection = false
        collectionView?.allowsSelection = false
        collectionView?.backgroundColor = .white
        
        collectionView?.register(collectionViewCellProvider.class(with: PhotoContentView.self), forCellWithReuseIdentifier: _identifier(with: .image))
        collectionView?.register(collectionViewCellProvider.class(with: VideoContentView.self), forCellWithReuseIdentifier: _identifier(with: .video))
        
//        // setup indicator 
//        indicatorItem.indicatorView.delegate = self
//        indicatorItem.indicatorView.dataSource = self
//        indicatorItem.indicatorView.register(IndicatorViewCell.dynamic(with: UIImageView.self), forCellWithReuseIdentifier: "ASSET-IMAGE")
//        //indicatorItem.indicatorView.register(IndicatorViewCell.dynamic(with: UIScrollView.self), forCellWithReuseIdentifier: "ASSET-IMAGE")
        
        // setup toolbar items
        let toolbarItems = [
//            indicatorItem,
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: nil),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: nil)
        ]
        setToolbarItems(toolbarItems, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIView.performWithoutAnimation {
            collectionView?.scrollToItem(at: _itemIndexPath, at: .centeredHorizontally, animated: false)
            indicatorItem.indicatorView.scrollToItem(at: _itemIndexPath, animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        super.viewWillAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // size change
        guard _cacheBounds?.size != view.bounds.size else {
            return
        }
        // view.bounds is change, need update content inset
        _cacheBounds = view.bounds
        _updateSystemContentInsetIfNeeded()
    }
    
    // MARK: internal var
    
    var animator: Animator? {
        willSet {
            ub_transitioningDelegate = newValue
        }
    }
    
    let indicatorItem = IndicatorItem()
    let interactiveDismissGestureRecognizer = UIPanGestureRecognizer()
    let tapGestureRecognizer = UITapGestureRecognizer()
    
    let extraContentInset = UIEdgeInsetsMake(0, -20, 0, -20)
    
    var vaildContentOffset = CGPoint.zero
    
    var ignoreContentOffsetChange: Bool {
        objc_sync_enter(self)
        let result = _ignoreContentOffsetChange
        objc_sync_enter(self)
        return result
    }
    
    /// the any item update delegate
    weak var updateDelegate: DetailControllerItemUpdateDelegate?
    
    
    fileprivate func _identifier(with mediaType: AssetMediaType) -> String {
        switch mediaType {
        case .image: return "ASSET-DETAIL-IMAGE"
        case .video: return "ASSET-DETAIL-VIDEO"
        case .audio: return "ASSET-DETAIL-IMAGE"
        case .unknown: return "ASSET-DETAIL-IMAGE"
        }
    }
    
    fileprivate func _animate(with duration: TimeInterval, options: UIViewAnimationOptions, animations: @escaping () -> Swift.Void, completion: ((Bool) -> Void)? = nil) {
        //UIView.animate(withDuration: duration * 5, delay: 0, options: options, animations: animations, completion: completion)
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 10, options: options, animations: animations, completion: completion)
    }
    
    // MARK: private ivar
    
    fileprivate let _source: DataSource
    fileprivate let _library: Library
    
    // transition
    fileprivate var _transitionIsInteractiving: Bool = false
    fileprivate var _transitionAtLocation: CGPoint = .zero
    fileprivate var _transitionContext: TransitioningContext?
    
    // full-screen mode
    fileprivate var _isFullscreen: Bool = false
    
    // cache
    fileprivate var _cacheBounds: CGRect?
    
    // 插入/删除的时候必须清除
    fileprivate var _interactivingFromIndex: Int?
    fileprivate var _interactivingFromIndexPath: IndexPath?
    fileprivate var _interactivingToIndex: Int?
    fileprivate var _interactivingToIndexPath: IndexPath?
    
    // the current item context
    fileprivate var _itemIndexPath: IndexPath
    fileprivate var _itemLayoutAttributes: UICollectionViewLayoutAttributes?
    
    fileprivate var _orientationes: [String: UIImageOrientation] = [:]
    
    fileprivate var _ignoreContentOffsetChange: Bool = false
    fileprivate var _systemContentInset: UIEdgeInsets = .zero
}

// private method
extension BrowserDetailController {
    
    fileprivate func _updateCurrentItem(at indexPath: IndexPath) {
        logger.debug?.write(indexPath)
        
        let changed = _itemIndexPath != indexPath
        
        // notify user item will change
        if changed {
            updateDelegate?.detailController(self, willShowItem: indexPath)
        }
        
        // update current item context
        _itemIndexPath = indexPath
        _itemLayoutAttributes = collectionView?.layoutAttributesForItem(at: indexPath)
        
        // notify user item did change
        if changed {
            updateDelegate?.detailController(self, didShowItem: indexPath)
        }
    }
    fileprivate func _updateCurrentItem(with contentOffset: CGPoint) {
        
        // must has a collection view
        guard let collectionView = collectionView else {
            return
        }
        let x = contentOffset.x + collectionView.bounds.width / 2
        
        // check for any changes
        if let item = _itemLayoutAttributes, item.frame.minX <= x && x < item.frame.maxX {
            return // hit cache
        }
        
        // find item at content offset
        guard let indexPath = collectionView.indexPathForItem(at: CGPoint(x: x, y: 0)) else {
            return // not found, ignore
        }
        _updateCurrentItem(at: indexPath)
    }
    
    fileprivate func _updateCurrentItemForIndicator(with contentOffset: CGPoint) {
        // must has a collection view
        guard let collectionView = collectionView else {
            return
        }
        let value = contentOffset.x / collectionView.bounds.width
        let to = Int(ceil(value))
        let from = Int(floor(value))
        let percent = modf(value + 1).1
        // if from index is changed
        if _interactivingFromIndex != from {
            // get index path from collection view
            let indexPath = collectionView.indexPathForItem(at: CGPoint(x: (CGFloat(from) + 0.5) * collectionView.bounds.width , y: 0))
            
            _interactivingFromIndex = from
            _interactivingFromIndexPath = indexPath
        }
        // if to index is changed
        if _interactivingToIndex != to {
            // get index path from collection view
            let indexPath = collectionView.indexPathForItem(at: CGPoint(x: (CGFloat(to) + 0.5) * collectionView.bounds.width , y: 0))
            
            _interactivingToIndex = to
            _interactivingToIndexPath = indexPath
        }
        // use percentage update index
        indicatorItem.indicatorView.updateIndexPath(from: _interactivingFromIndexPath, to: _interactivingToIndexPath, percent: percent)
    }
    fileprivate func _updateSystemContentInsetIfNeeded(forceUpdate: Bool = false) {
        
        var contentInset  = UIEdgeInsets.zero
        
        if !ub_isFullscreen {
            // have navigation bar?
            contentInset.top = topLayoutGuide.length
            // have toolbar?
            contentInset.bottom = bottomLayoutGuide.length + indicatorItem.height
        }
        // is change?
        guard _systemContentInset != contentInset else {
            return
        }
        logger.trace?.write(contentInset)
        
        // notice all displayed cell
        collectionView?.visibleCells.forEach {
            ($0 as? BrowserDetailCell)?.updateContentInset(contentInset, forceUpdate: forceUpdate)
        }
        // update cache
        _systemContentInset = contentInset
    }
    
    fileprivate dynamic func _handleDismiss(_ sender: UIPanGestureRecognizer) {
       
        if !_transitionIsInteractiving { // start
            // check the direction of gestures => vertical & up
            let velocity = sender.velocity(in: view)
            guard velocity.y > 0 && fabs(velocity.x / velocity.y) < 1.5 else {
                return
            }
            // get cell & detail view & container view
            guard let cell = collectionView?.visibleCells.last as? BrowserDetailCell, let contentView = cell.ub_contentView else {
                return
            }
            // check whether this has triggered bounces
            let mh = sender.location(in: view).y
            let point = sender.location(in: cell.ub_contentView?.superview)
            guard point.y - mh < 0 || contentView.frame.height <= view.frame.height else {
                return
            }
            // enable interactiving
            _transitionAtLocation = sender.location(in: nil)
            _transitionIsInteractiving = true
            // dismiss
            DispatchQueue.main.async {
                // if is navigation controller poped
                if let navigationController = self.navigationController {
                    navigationController.popViewController(animated: true)
                    return
                }
                
                // is presented
                self.dismiss(animated: true, completion: nil)
            }
            logger.debug?.write("start")
            
        } else if sender.state == .changed { // update
            
            let origin = _transitionAtLocation
            let current = sender.location(in: nil)
            
            let offset = CGPoint(x: current.x - origin.x, y: current.y - origin.y)
            let percent = offset.y / (UIScreen.main.bounds.height * 3 / 5)
            
            _transitionContext?.ub_update(percent: min(max(percent, 0), 1), at: offset)
            
        } else { // stop
            
            logger.debug?.write("stop")
            // read of state
            let context = _transitionContext
            let complete = sender.state == .ended && sender.velocity(in: nil).y >= 0
            // have to delay treatment, otherwise will not found draggingContentOffset
            DispatchQueue.main.async {
                // forced to reset the content of offset
                // prevent jitter caused by the rolling animation
                self.collectionView?.visibleCells.forEach {
                    // fetch cell & containerView
                    guard let cell = ($0 as? BrowserDetailCell), let containerView = cell.ub_containerView else {
                        return
                    }
                    guard let offset = cell.ub_draggingContentOffset, containerView.isDecelerating else {
                        return
                    }
                    // stop all scroll animation
                    containerView.setContentOffset(offset, animated: false)
                }
                // commit animation
                context?.ub_complete(complete)
            }
            // disable interactiving
            _transitionContext = nil
            _transitionIsInteractiving = false
        }
    }
    
    fileprivate func _performWithoutContentOffsetChange<T>(_ actionsWithoutAnimation: () -> T) -> T {
        objc_sync_enter(self)
        _ignoreContentOffsetChange = true
        let result = actionsWithoutAnimation()
        _ignoreContentOffsetChange = false
        objc_sync_exit(self)
        return result
    }
}

// add full-screen display support
extension BrowserDetailController {
    
//    override var prefersStatusBarHidden: Bool {
//        return _isFullscreen || super.prefersStatusBarHidden
//    }
//    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
//        return .none
//    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
       // full screen mode shows white status bar
        guard _isFullscreen else {
            // default case
            return super.preferredStatusBarStyle
        }
        return .lightContent
    }
    
    override var ub_isFullscreen: Bool {
        return _isFullscreen
    }
    
    @discardableResult
    override func ub_enterFullscreen(animated: Bool) -> Bool {
        logger.debug?.write(animated)
        
        _isFullscreen = true
        _animate(with: 0.25, options: .curveEaseInOut, animations: {
            // need to add animation?
            guard animated else {
                return
            }
            
            self.setNeedsStatusBarAppearanceUpdate()
            
            self.view.backgroundColor = .black
            self.collectionView?.backgroundColor = .black
            
            self.navigationController?.toolbar?.alpha = 0
            self.navigationController?.navigationBar.alpha = 0
            
            self._updateSystemContentInsetIfNeeded(forceUpdate: true)
            
        }, completion: { finished in
            
            self.setNeedsStatusBarAppearanceUpdate()
            
            self.view.backgroundColor = .black
            self.collectionView?.backgroundColor = .black
            
            self.navigationController?.toolbar?.alpha = 1
            self.navigationController?.toolbar.isHidden =  true
            self.navigationController?.navigationBar.alpha = 1
            self.navigationController?.navigationBar.isHidden =  true
            
            self._updateSystemContentInsetIfNeeded()
        })
        
        return true
    }
    
    @discardableResult
    override func ub_exitFullscreen(animated: Bool) -> Bool {
        logger.debug?.write(animated)
        
        _isFullscreen = false
        _animate(with: 0.25, options: .curveEaseInOut, animations: {
            // need to add animation?
            guard animated else {
                return
            }
            UIView.performWithoutAnimation {
                
                self.navigationController?.toolbar?.alpha = 0
                self.navigationController?.toolbar.isHidden = false
                self.navigationController?.navigationBar.alpha = 0
                self.navigationController?.navigationBar.isHidden = false
            }
            
            self.setNeedsStatusBarAppearanceUpdate()
            
            self.view.backgroundColor = .white
            self.collectionView?.backgroundColor = .white
            
            self.navigationController?.toolbar?.alpha = 1
            self.navigationController?.navigationBar.alpha = 1
            
            self._updateSystemContentInsetIfNeeded(forceUpdate: true)
            
        }, completion: { finished in
            
            self.view.backgroundColor = .white
            self.collectionView?.backgroundColor = .white
            
            self._updateSystemContentInsetIfNeeded()
        })
        
        return true
    }
}

// add interactivable transitioning support
extension BrowserDetailController: TransitioningDataSource {
    
    func ub_transitionView(using animator: Animator, for operation: Animator.Operation) -> TransitioningView? {
        logger.trace?.write()
        
        guard let indexPath = animator.indexPath else {
            return nil
        }
        // get at current index path the cell
        return collectionView?.cellForItem(at: indexPath) as? BrowserDetailCell
    }
    
    func ub_transitionShouldStart(using animator: Animator, for operation: Animator.Operation) -> Bool {
        logger.trace?.write()
        animator.indexPath = _itemIndexPath
        return true
    }
    func ub_transitionShouldStartInteractive(using animator: Animator, for operation: Animator.Operation) -> Bool {
        logger.trace?.write()
        
        let state = interactiveDismissGestureRecognizer.state
        guard state == .changed || state == .began else {
            return false
        }
        // transitions in full-screen mode, require additional add exit full-screen of the animation
        guard ub_isFullscreen else {
            return true
        }
        UIView.performWithoutAnimation {
            
            self.setNeedsStatusBarAppearanceUpdate()
            
            self.navigationController?.toolbar?.alpha = 0
            self.navigationController?.toolbar?.isHidden = false
            self.navigationController?.navigationBar.alpha = 0
            self.navigationController?.navigationBar.isHidden = false
        }
        UIView.animate(withDuration: 0.25) {
            
            self.navigationController?.toolbar?.alpha = 1
            self.navigationController?.navigationBar.alpha = 1
            
            self.setNeedsStatusBarAppearanceUpdate()
        }
        return true
    }
    
    func ub_transitionDidPrepare(using animator: Animator, context: TransitioningContext) {
        logger.trace?.write()
        
        // must be attached to the collection view
        guard let collectionView = collectionView, let indexPath = animator.indexPath else {
            return
        }
        // check the index path is displaying
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            // no, scroll to the cell at index path
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            // must call the layoutIfNeeded method, otherwise cell may not create
            UIView.performWithoutAnimation {
                collectionView.setNeedsLayout()
                collectionView.layoutIfNeeded()
                indicatorItem.indicatorView.setNeedsLayout()
                indicatorItem.indicatorView.layoutIfNeeded()
            }
        }
    }
    
    func ub_transitionDidStart(using animator: Animator, context: TransitioningContext) {
        _transitionContext = context
    }
    func ub_transitionDidEnd(using animator: Animator, transitionCompleted: Bool) {
        _transitionContext = nil
        
        // transitions in failure, if needed restore full-screen mode
        guard !transitionCompleted && ub_isFullscreen else {
            return
        }
        UIView.performWithoutAnimation {
            
            self.navigationController?.toolbar?.alpha = 1
            self.navigationController?.toolbar?.isHidden = true
            self.navigationController?.navigationBar.alpha = 1
            self.navigationController?.navigationBar.isHidden = true
            
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

// add collection view display support
extension BrowserDetailController: UICollectionViewDelegateFlowLayout {
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // only process in collection view
        // check whether to allow the change of content offset
        guard collectionView === scrollView, !ignoreContentOffsetChange else {
            return
        }
        
        // update current item & index pathd
        _updateCurrentItem(with: scrollView.contentOffset)
        _updateCurrentItemForIndicator(with: scrollView.contentOffset)
    }
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // only process in collection view
        guard collectionView === scrollView else {
            return
        }
        
        // notify indicator interactive start
        indicatorItem.indicatorView.beginInteractiveMovement()
    }
    override  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // only process in collection view
        // if you do not need to decelerate, notify indicator interactive finish
        guard collectionView === scrollView, !decelerate else {
            return
        }
        
        indicatorItem.indicatorView.endInteractiveMovement()
    }
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // only process in collection view
        guard collectionView === scrollView else {
            return
        }
        
        // notify indicator interactive finish
        indicatorItem.indicatorView.endInteractiveMovement()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return _source.numberOfSections
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return _source.numberOfItems(inSection: section)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // generate the reuse identifier
        let type = _source.asset(at: indexPath)?.ub_mediaType ?? .unknown
        let identifier = _identifier(with: type)
        
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // try fetch cell
        // try fetch asset
        guard let asset = _source.asset(at: indexPath), let displayer = cell as? Displayable else {
            return
        }
        
        // update content inset
        (cell as? BrowserDetailCell)?.updateContentInset(_systemContentInset, forceUpdate: false)
        
        // update disaply content
        displayer.willDisplay(with: asset, in: _library, orientation: _orientationes[asset.ub_identifier] ?? .up)
        displayer.delegate = self
    }
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // try fetch cell
        // try fetch asset
        guard let asset = _source.asset(at: indexPath), let displayer = cell as? BrowserDetailCell else {
            return
        }
        displayer.endDisplay(with: asset, in: _library)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return view.frame.size
    }
    
}


// add indicator view display support
extension BrowserDetailController: IndicatorViewDataSource, IndicatorViewDelegate {
    
    func numberOfSections(in indicator: IndicatorView) -> Int {
        return _source.numberOfSections
    }
    
    func indicator(_ indicator: IndicatorView, numberOfItemsInSection section: Int) -> Int {
        return _source.numberOfItems(inSection: section)
    }
    
    func indicator(_ indicator: IndicatorView, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let asset = _source.asset(at: indexPath)
        return .init(width: asset?.ub_pixelWidth ?? 0, height: asset?.ub_pixelHeight ?? 0)
    }
    
    func indicator(_ indicator: IndicatorView, cellForItemAt indexPath: IndexPath) -> IndicatorViewCell {
        logger.trace?.write(indexPath)
        return indicator.dequeueReusableCell(withReuseIdentifier: "ASSET-IMAGE", for: indexPath)
    }
    
    
    func indicator(_ indicator: IndicatorView, willDisplay cell: IndicatorViewCell, forItemAt indexPath: IndexPath) {
        logger.trace?.write(indexPath)
        
        guard let asset = _source.asset(at: indexPath) else {
            return
        }
        
        let size = CGSize(width: 20, height: 38).ub_fitWithScreen
        let options = DataSourceOptions()
        
        if let imageView = cell.contentView as? UIImageView {
            imageView.contentMode = .scaleAspectFill
            //imageView.image = container.item(at: indexPath).image
            
            //imageView.ub_setImage(nil, animated: false)
            imageView.image = nil
            _library.ub_requestImage(for: asset, size: size, mode: .aspectFill, options: options) { image, info in
                imageView.image = image
                //imageView.ub_setImage(image, animated: true)
            }
        }
        
        // set default background color
        cell.contentView.backgroundColor = .ub_init(hex: 0xf0f0f0)
    }
    
    func indicatorWillBeginDragging(_ indicator: IndicatorView) {
        logger.trace?.write()
        
        collectionView?.isScrollEnabled = false
        interactiveDismissGestureRecognizer.isEnabled = false
    }
    func indicatorDidEndDragging(_ indicator: IndicatorView) {
        logger.trace?.write()
        
        collectionView?.isScrollEnabled = true
        interactiveDismissGestureRecognizer.isEnabled = true
    }

    func indicator(_ indicator: IndicatorView, didSelectItemAt indexPath: IndexPath) {
        logger.trace?.write(indexPath)
        
//        guard !isInteractiving else {
//            return // 正在交互
//        }
        
        // index path is changed
        guard indexPath != _itemIndexPath else {
            return
        }
        
        _updateCurrentItem(at: indexPath)
        
        _performWithoutContentOffsetChange {
            // prevent possible animations
            UIView.performWithoutAnimation {
                collectionView?.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            }
        }
    }
}

// add item rotation support
extension BrowserDetailController: DetailControllerItemRotationDelegate {
    
    /// item should rotation
    func detailController(_ detailController: Any, shouldBeginRotationing asset: Asset) -> Bool {
        logger.debug?.write(asset.ub_identifier)
        // allow
        return true
    }
    
    /// item did rotation
    func detailController(_ detailController: Any, didEndRotationing asset: Asset, at orientation: UIImageOrientation) {
        logger.debug?.write(asset.ub_identifier, "is landscape: \(orientation.ub_isLandscape)")
        // save
        _orientationes[asset.ub_identifier] = orientation
    }
}

// add dismiss gesture recognizer support
extension BrowserDetailController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // only processing interactive dismiss gesture recognizer
        guard interactiveDismissGestureRecognizer == gestureRecognizer else {
            return true // ignore
        }
        
        // detect the direction of gestures => up or down
        let velocity = interactiveDismissGestureRecognizer.velocity(in: collectionView)
        guard fabs(velocity.x / velocity.y) < 1.5 else {
            return false
        }
        guard let cell = collectionView?.visibleCells.last as? BrowserDetailCell else {
            return false
        }
        
        // check this gesture event can not trigger bounces
        let point = interactiveDismissGestureRecognizer.location(in: cell.ub_contentView?.superview)
        guard (point.y - view.frame.height) <= 0 else {
            return false
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // only processing interactive dismiss gesture recognizer
        guard interactiveDismissGestureRecognizer == gestureRecognizer else {
            return false // ignore
        }
        
        // if it has started to interact, it is the exclusive mode
        guard !_transitionIsInteractiving else {
            return false
        }
        guard let panGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        
        // only allow canvas view gestures can operate
        guard let view = panGestureRecognizer.view, view.superview is CanvasView else {
            return false
        }
        return true
    }
    
}

