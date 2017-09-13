//
//  BrowserCollectionController.swift
//  Ubiquity
//
//  Created by sagesse on 16/03/2017.
//  Copyright © 2017 SAGESSE. All rights reserved.
//

import UIKit

/// the asset list in album
internal class BrowserAlbumController: UICollectionViewController, Controller, ExceptionHandling, ChangeObserver, TransitioningDataSource, DetailControllerItemUpdateDelegate, UICollectionViewDelegateFlowLayout {
    
    required init(container: Container, source: Source, sender: Any?) {
        // setup init data
        self.source = source
        self.container = container
        
        // continue init the UI
        super.init(collectionViewLayout: BrowserAlbumLayout())
        
        // if not configure title
        // the title will follow data source change
        super.title = source.title
        
        // if the navigation bar disable translucent will have an error offset, enabled `extendedLayoutIncludesOpaqueBars` can solve the problem 
        self.extendedLayoutIncludesOpaqueBars = true
        self.automaticallyAdjustsScrollViewInsets = true
        
        // add change observer for library
        self.container.addChangeObserver(self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // clear all cache request when destroyed
        _clearCachingAssets()
        
        // cancel listen change
        container.removeChangeObserver(self)
    }
    
    override var title: String? {
        willSet {
            _cachedTitle = newValue
        }
    }
    
    /// Specifies whether the view controller prefers the header view to be hidden or shown.
    open var prefersHeaderViewHidden: Bool {
        return !source.collectionTypes.contains(.moment)
    }
    
    /// Specifies whether the view controller prefers the footer view to be hidden or shown.
    open var prefersFooterViewHidden: Bool {
        return false
    }
    
    override func loadView() {
        super.loadView()
        
        // the collectionView must king of `BrowserAlbumView`
        object_setClass(collectionView, BrowserAlbumView.self)
        
        // setup controller
        view.backgroundColor = .white
        
        // setup next page back item
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .done, target: nil, action: nil)
        
        // the header view is enabled?
        if !prefersHeaderViewHidden {
            
            // generate header view
            let headerView = NavigationHeaderView(frame: .init(x: 0, y: 0, width: view.frame.width, height: 48))
            
            // config
            headerView.effect = UIBlurEffect(style: .extraLight)
            headerView.layer.zPosition = -0.5
            headerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_hanleHeader(_:))))
            
            // link to screen
            _headerView = headerView
        }
        
        // the footer view is enabled?
        if !prefersFooterViewHidden {
            
            // generate footer view
            let footerView = NavigationFooterView()
            
            // config
            footerView.frame = .init(x: 0, y: 0, width: collectionView?.frame.width ?? 0, height: 48)
            footerView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            footerView.alpha = 0
            
            // add to view
            collectionView?.addSubview(footerView)
            
            // link to screen
            _footerView = footerView
        }
        
        // setup colleciton view
        collectionView?.backgroundColor = .white
        collectionView?.alwaysBounceVertical = true
        collectionView?.register(NavigationHeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "HEADER")
        
        // fetch all register cell for albums.
        container.factory(with: .albums).contents.forEach {
            // forward to collection view
            collectionView?.register($1, forCellWithReuseIdentifier: $0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // delay exec, order to prevent the view not initialized
        DispatchQueue.main.async {
            // initialize controller with container and source
            self.ub_initialize(with: self.container, source: self.source)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // check
        let size = collectionViewLayout.collectionViewContentSize
        guard size != _cachedSize, prepared else {
            return
        }
        
        // bounds is change?
        if _cachedSize?.width != size.width {
            _updateHeaderCaches()
        }
        
        // update view
        _updateFooterView()
        _updateHeaderView()
        
        // update cache
        _cachedSize = size
    }
    
    // MARK: Collection View Scroll
    
    /// The collectionView did scroll
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // the library is prepared?
        guard prepared else {
            return
        }
        
        // if isTracking is true, is a draging
        if scrollView.isTracking {
            // on draging, update target content offset
           _targetContentOffset = scrollView.contentOffset
        }
        
        // update all for content offset did change
        _updateHeaderView()
        _updateCachingAssets()
    }
    
    /// The scroll view can scroll to top?
    override func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // update target content offset
        _targetContentOffset = .init(x: -scrollView.contentInset.left, y: -scrollView.contentInset.top)
        
        // if transitions animation is started, can't scroll
        return !transitioning
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // update target content offset
        _targetContentOffset = scrollView.contentOffset
    }
    
    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // update target content offset
        _targetContentOffset = targetContentOffset.move()
    }
    
    // MARK: Collection View Configure
    
    /// Returns the section numbers
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // without authorization, shows blank
        guard authorized else {
            return 0
        }
        return source.numberOfCollections
    }
    
    /// Return the items number in section
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // without authorization, shows blank
        guard authorized else {
            return 0
        }
        return source.numberOfAssets(inCollection: section)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // generate the reuse identifier
        let type = source.asset(at: indexPath)?.ub_type ?? .unknown
        
        // generate cell for media type
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ub_identifier(with: type), for: indexPath)
        
        // the zPosition of cell must be below header view
        cell.layer.zPosition = -1
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // generate the view for kind
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HEADER", for: indexPath)
        
        // the zPosition of header view must be below scroll indicator
        view.layer.zPosition = -0.75
        
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // collectionViewLayout must king of `UICollectionViewFlowLayout`
        guard let collectionViewLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        
        return collectionViewLayout.itemSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        // collectionViewLayout must king of `UICollectionViewFlowLayout`
        guard let collectionViewLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        var edg = UIEdgeInsets(top: collectionViewLayout.minimumLineSpacing, left: 0, bottom: 0, right: 0)

        if #available(iOS 11.0, *) {
            edg.left = collectionView.safeAreaInsets.left
            edg.right = collectionView.safeAreaInsets.right
        }
        
        // in header, top is 4
        if !prefersHeaderViewHidden {
            edg.top = 4
        }
        
        // if the section is empty, don't inset
        if collectionView.numberOfItems(inSection: section) == 0 {
            edg.top = 0
            edg.bottom = 0
        }
        
        // in first section, top is 4
        if section == 0 {
            edg.top = 4
        }
        
        // in last section, bottom is 4
        if section == collectionView.numberOfSections - 1 {
            edg.bottom = 4
        }
        
        return edg
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // if the section is empty, ignore
        // if the source can't allows show header, ignore
        guard !prefersHeaderViewHidden && collectionView.numberOfItems(inSection: section) != 0 else {
            return .zero
        }
        
        return .init(width: 0, height: 48)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // the cell must king of `Displayable`
        guard let displayer = cell as? Displayable, let asset = source.asset(at: indexPath), prepared else {
            return
        }
        
        // show asset with container and orientation
        displayer.willDisplay(with: asset, container: container, orientation: .up)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // the cell must king of `Displayable`
        guard let displayer = cell as? Displayable, prepared else {
            return
        }
        
        displayer.endDisplay(with: container)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        // the view must king of `NavigationHeaderView`
        guard let view = view as? NavigationHeaderView else {
            return
        }
        
        // update data
        view.parent = _headerView
        view.section = indexPath.section
    }
    override func collectionView(_ collectionView: UICollectionView, didEndDisplayingSupplementaryView view: UICollectionReusableView, forElementOfKind elementKind: String, at indexPath: IndexPath) {
        // the view must king of `NavigationHeaderView`
        guard let view = view as? NavigationHeaderView else {
            return
        }
        
        // clear data
        view.parent = nil
        view.section = nil
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        logger.debug?.write("show detail with: \(indexPath)")
        
        // try generate detail controller for factory
        let controller = container.instantiateViewController(with: .detail, source: source, sender: indexPath)
        
        // can't use animator?
        if let controller = controller as? BrowserDetailController {
            
            controller.animator = Animator(source: self, destination: controller)
            controller.updateDelegate = self
        }
        
        // show next page
        show(controller, sender: indexPath)
    }
    
    // MARK: Animatable Transitioning
    
    /// Returns transitioning view.
    func ub_transitionView(using animator: Animator, for operation: Animator.Operation) -> TransitioningView? {
        // the indexPath must be set
        guard let indexPath = animator.indexPath else {
            return nil
        }
        logger.trace?.write()
        
        // fetch cell at index path
        return collectionView?.cellForItem(at: indexPath) as? TransitioningView
    }
    
    /// Return a Boolean value that indicates whether users allows transition.
    func ub_transitionShouldStart(using animator: Animator, for operation: Animator.Operation) -> Bool {
        logger.trace?.write()
        return true
    }
    
    /// Return A Boolean value that indicates whether users allows interactive animation transition.
    func ub_transitionShouldStartInteractive(using animator: Animator, for operation: Animator.Operation) -> Bool {
        logger.trace?.write()
        return false
    }
    
    /// Transitions the context has been prepared.
    func ub_transitionDidPrepare(using animator: Animator, context: TransitioningContext) {
        // the indexPath & collectionView must be set
        guard let collectionView = collectionView, let indexPath = animator.indexPath  else {
            return
        }
        logger.trace?.write()
        
        // check the index path is displaying
        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            // no, scroll to the cell at index path
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            
            // must call the layoutIfNeeded method, otherwise cell may not create
            collectionView.layoutIfNeeded()
        }
        
        // the cell must exist, otherwise it is not show
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        
        // if it is to, reset cell boundary
        if context.ub_operation == .pop || context.ub_operation == .dismiss {
            let frame = cell.convert(cell.bounds, to: view)
            let height = view.frame.height - topLayoutGuide.length - bottomLayoutGuide.length
            
            let y1 = -topLayoutGuide.length + frame.minY - (_headerView?.frame.height ?? 0)
            let y2 = -topLayoutGuide.length + frame.maxY
            
            // reset content offset if needed
            if y2 > height {
                // bottom over boundary, reset to y2(bottom)
                collectionView.contentOffset.y += y2 - height
            } else if y1 < 0 {
                // top over boundary, rest to y1(top)
                collectionView.contentOffset.y += y1
            }
        }
        cell.isHidden = true
        
        // current transitions animation is started
        transitioning = true
    }
    
    /// Transitions the animation will end.
    func ub_transitionWillEnd(using animator: Animator, context: TransitioningContext, transitionCompleted: Bool) {
        // the indexPath must be set & only process for disappear
        guard let indexPath = animator.indexPath, context.ub_operation.disappear else {
            return
        }
        logger.trace?.write(transitionCompleted)
        
        // the cell must exist, otherwise it is not show
        guard let cell = collectionView?.cellForItem(at: indexPath), let snapshotView = context.ub_snapshotView else {
            return
        }
        
        // generate a new snapshot view for transtion animation end
        let newSnapshotView = snapshotView.snapshotView(afterScreenUpdates: false)
        
        // config the new snapshot view
        newSnapshotView?.transform = snapshotView.transform
        newSnapshotView?.bounds = .init(origin: .zero, size: snapshotView.bounds.size)
        newSnapshotView?.center = .init(x: snapshotView.bounds.midX, y: snapshotView.bounds.midY)
        newSnapshotView.map {
            cell.addSubview($0)
        }
        
        // add animation for new snapshot view hidden
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            newSnapshotView?.alpha = 0
        }, completion: { _ in
            newSnapshotView?.removeFromSuperview()
        })
    }
    
    /// Transitions the animation has been end.
    func ub_transitionDidEnd(using animator: Animator, transitionCompleted: Bool) {
        // the cell must exist, otherwise it is not show
        guard let indexPath = animator.indexPath, let cell = collectionView?.cellForItem(at: indexPath) else {
            return
        }
        logger.trace?.write(transitionCompleted)
        
        // restore
        cell.isHidden = false
        
        // current transitions animation is end
        transitioning = false
    }
    
    // MARK: Library Change Notification
    
    /// Tells your observer that a set of changes has occurred in the Photos library.
    func library(_ library: Library, didChange change: Change) {
        // if the library no authorized, ignore all change
        guard authorized else {
            return
        }
        // fetch the source change
        guard let details = source.changeDetails(forAssets: change) else {
            return // no change
        }
        logger.trace?.write()
        
        // change notifications may be made on a background queue.
        // re-dispatch to the main queue to update the UI.
        DispatchQueue.main.async {
            // progressing
            self.library(library, didChange: change, details: details)
        }
    }
    
    /// Tells your observer that a set of changes has occurred in the Photos library.
    func library(_ library: Library, didChange change: Change, details: SourceChangeDetails) {
        // collectionView must be set
        guard let collectionView = collectionView, let newSource = details.after else {
            return
        }
        // keep the new fetch result for future use.
        let oldSource = self.source
        source = newSource
        
        // source did change, must update header cache
        defer {
            _updateHeaderCaches()
            _updateHeaderView()
        }
        
        // update collection asset count change
        guard newSource.numberOfAssets != 0 else {
            // new data source is empty, reload all data and reset error info
            self.ub_execption(with: container, source: newSource, error: Exception.notData, animated: true)
            self.collectionView?.reloadData()
            return
        }
        
        // the library is prepared
        self.prepared = true
        self.ub_execption(with: container, source: newSource, error: nil, animated: true)
        
        // the old source is empty?
        guard oldSource.numberOfAssets != 0 else {
            // old source is empty, reload all data
            self.collectionView?.reloadData()
            return
        }
        
        // the aset has any change?
        guard details.hasItemChanges else {
            return
        }
        
        // whether the change will support incremental updating?
        guard details.hasIncrementalChanges else {
            // does not support, forced to update all the data
            self.collectionView?.reloadData()
            return
        }

        // update collection
        collectionView.performBatchUpdates({
            
            // For indexes to make sense, updates must be in this order:
            // delete, insert, reload, move
            
            details.deleteSections.map { collectionView.deleteSections($0) }
            details.insertSections.map { collectionView.insertSections($0) }
            details.reloadSections.map { collectionView.reloadSections($0) }
            
            details.moveSections?.forEach { from, to in
                collectionView.moveSection(from, toSection: to)
            }
            
            details.removeItems.map { collectionView.deleteItems(at: $0) }
            details.insertItems.map { collectionView.insertItems(at: $0) }
            details.reloadItems.map { collectionView.reloadItems(at: $0) }
            
            details.moveItems?.forEach { from, to in
                collectionView.moveItem(at: from, to: to)
            }
            
        }, completion: nil)
    }
    
    // MARK: Extended
    
    /// Call before request authorization
    open func container(_ container: Container, willAuthorization source: Source) {
        logger.trace?.write()
    }
    
    /// Call after completion of request authorization
    open func container(_ container: Container, didAuthorization source: Source, error: Error?) {
        // the error message has been processed by the ExceptionHandling
        guard error == nil else {
            return
        }
        logger.trace?.write(error ?? "")
        
        // the library authorized successed
        authorized = true
    }
    
    /// Call before request load
    open func container(_ container: Container, willLoad source: Source) {
        logger.trace?.write()
    }
    
    /// Call after completion of load
    open func container(_ container: Container, didLoad source: Source, error: Error?) {
        // the error message has been processed by the ExceptionHandling
        guard let collectionView = collectionView, error == nil else {
            return
        }
        logger.trace?.write(error ?? "")
        
        // check for assets count
        guard source.numberOfAssets != 0 else {
            // count is zero, no data
            ub_execption(with: container, source: source, error: Exception.notData, animated: true)
            return
        }
        
        // refresh UI
        self.source = source
        self.collectionView?.reloadData()
        
        // scroll after update footer
        _updateFooterView()
        
        // scroll to init position if needed
        if source.collectionSubtypes.contains(.smartAlbumUserLibrary) || source.collectionTypes.contains(.moment) {
            // if the contentOffset over boundary
            let size = collectionViewLayout.collectionViewContentSize
            let bottom = collectionView.contentInset.bottom - _footerViewInset.bottom
            
            // reset vaild contentOffset in collectionView internal
            collectionView.contentOffset.y = size.height - (collectionView.frame.height - bottom)
        }
        
        // the library is prepared
        prepared = true
        
        _targetContentOffset = collectionView.contentOffset
        
        // update content offset
        scrollViewDidScroll(collectionView)
    }
    
    // MARK: Detail Display Notification
    
    /// Display item will change
    func detailController(_ detailController: Any, willShowItem indexPath: IndexPath) {
        // if is, this suggests that are displaying
        if collectionView?.indexPathsForVisibleItems.contains(indexPath) ?? false {
            return
        }
        logger.debug?.write("over screen, scroll to \(indexPath)")
        
        // the indexPath is valid?
        guard indexPath.section < source.numberOfCollections && indexPath.item < source.numberOfAssets(inCollection: indexPath.section) else {
            return
        }

        // no displaying, scroll to item
        collectionView?.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collectionView?.layoutIfNeeded()
    }
    
    /// Display item did change
    func detailController(_ detailController: Any, didShowItem indexPath: IndexPath) {
    }
    
    // MARK: Assets Cache
    
    /// Fetch assets in rect
    private func _assetsOfCaching(in rect: CGRect) -> [Asset] {
        return collectionViewLayout.layoutAttributesForElements(in: rect)?.flatMap {
            guard $0.representedElementCategory == .cell else {
                return nil
            }
            return source.asset(at: $0.indexPath)
        } ?? []
    }
    
    /// Fetch change details
    private func _changeDetails(_ new: [CGRect], _ old: [CGRect]) -> (added: [CGRect], removed: [CGRect]) {
        // calculates the area after subtracting the two rect
        func _subtract(_ r1: CGRect, _ r2: CGRect) -> [CGRect] {
            // if not intersect, do not calculate
            guard r1.intersects(r2) else {
                return [r1]
            }
            var result = [CGRect]()
            
            if r2.minY > r1.minY {
                result.append(.init(x: r1.minX, y: r1.minY, width: r1.width, height: r2.minY - r1.minY))
            }
            if r1.maxY > r2.maxY {
                result.append(.init(x: r1.minX, y: r2.maxY, width: r1.width, height: r1.maxY - r2.maxY))
            }
            
            return result
        }
        // union all rectangles
        func _union(_ rects: [CGRect]) -> [CGRect] {
            
            var result = [CGRect]()
            // must sort, otherwise there will be break rect
            rects.sorted(by: { $0.minY < $1.minY }).forEach { rect in
                // is intersects?
                guard let last = result.last, last.intersects(rect) else {
                    result.append(rect)
                    return
                }
                result[result.count - 1] = last.union(rect)
            }
            
            return result
        }
        // intersection all rectangles
        func _intersection(_ rects: [CGRect]) -> [CGRect] {
            
            var result = [CGRect]()
            // must sort, otherwise there will be break rect
            rects.sorted(by: { $0.minY < $1.minY }).forEach { rect in
                // is intersects?
                guard let last = result.last, last.intersects(rect) else {
                    result.append(rect)
                    return
                }
                result[result.count - 1] = last.intersection(rect)
            }
            
            return result
        }
        
        // step1: merge
        let newRects = _union(new)
        let oldRects = _union(old)
        
        // step2: split
        return (
            newRects.flatMap { new in
                _intersection(oldRects.flatMap { old in
                    _subtract(new, old)
                })
            },
            oldRects.flatMap { old in
                _intersection(newRects.flatMap { new in
                    _subtract(old, new)
                })
            }
        )
    }
    
    /// Clear all cached assets
    private func _clearCachingAssets() {
        // stop cache all
        container.stopCachingImagesForAllAssets()
        
        // reset
        _previousPreheatRect = .zero
    }

    /// Update all cached assets with content offset
    private func _updateCachingAssets() {
        // collectionView must be set
        guard let collectionView = collectionView, prepared else {
            return
        }
        
        // The preheat window is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let targetVisibleRect = CGRect(origin: _targetContentOffset, size: collectionView.bounds.size)
        
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        let targetPreheatRect = targetVisibleRect.insetBy(dx: 0, dy: -0.5 * targetVisibleRect.height)

        var changes = [(new: CGRect, old: CGRect)]()
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - _previousPreheatRect.midY)
        if delta > view.bounds.height / 3 {
            // need change
            changes.append((preheatRect, _previousPreheatRect))
            // Store the preheat rect to compare against in the future.
            _previousPreheatRect = preheatRect
        }
        
        // Update only if the taget visible area is significantly different from the last preheated area.
        let targetDelta = abs(targetPreheatRect.midY - _previousTargetPreheatRect.midY)
        if targetDelta > view.bounds.height / 3 {
            // need change
            changes.append((targetPreheatRect, _previousTargetPreheatRect))
            // Store the preheat rect to compare against in the future.
            _previousTargetPreheatRect = targetPreheatRect
        }
        
        // is change?
        guard !changes.isEmpty else {
            return
        }
        //logger.debug?.write("preheatRect is change: \(changes)")
        
        // Compute the assets to start caching and to stop caching.
        let details = _changeDetails(changes.map { $0.new }, changes.map { $0.old })
        
        let added = details.added.flatMap { _assetsOfCaching(in: $0) }
        let removed = details.removed.flatMap { _assetsOfCaching(in: $0) }.filter { asset in
            return !added.contains {
                return $0 === asset
            }
        }
        
        // Update the assets the PHCachingImageManager is caching.
        container.startCachingImages(for: added, size: BrowserAlbumLayout.thumbnailItemSize, mode: .aspectFill, options: nil)
        container.stopCachingImages(for: removed, size: BrowserAlbumLayout.thumbnailItemSize, mode: .aspectFill, options: nil)
    }
    
    // MARK: Show header & footer view
    
    /// Returns header at offset
    private func _header(at offset: CGFloat) -> (Int, CGFloat)? {
        // header layouts must be set
        guard let headers = _headers, !headers.isEmpty else {
            return nil
        }
        
        // the distance from the next setion
        var distance = CGFloat.greatestFiniteMagnitude
        
        // backward: fetch first -n or 0
        var start = min(_header, headers.count - 1)
        while start >= 0 {
            // the section has header view?
            guard let rect = headers[start] else {
                start -= 1
                continue
            }
            // is -n or 0?
            guard (rect.minY - offset) < 0 else {
                start -= 1
                continue
            }
            break
        }
        
        // is over hide
        guard start >= 0 else {
            return nil
        }
        
        // forward: fetch first +n or inf
        var end = start
        while end < headers.count {
            // the section has header view?
            guard let rect = headers[end] else {
                end += 1
                continue
            }
            // is +n
            guard (rect.minY - offset) > 0 else {
                start = end
                end += 1
                continue
            }
            distance = (rect.minY - offset)
            break
        }
        
        // cache for optimize search speed
        _header = start
        
        // success
        return (start, distance)
    }
    
    /// Update header view & layout
    private func _updateHeaderView() {
        // collection view must be set
        guard let collectionView = collectionView, let headerView = _headerView else {
            return
        }
        
        // fetch current section
        var offset = collectionView.contentOffset.y + collectionView.contentInset.top
        
        // in iOS11, if activated `safeAreaInsets`, need to subtraction the area
        if #available(iOS 11.0, *) {
            offset += collectionView.safeAreaInsets.top
        }
        
        guard let (section, distance) = _header(at: offset) else {
            headerView.section = nil
            headerView.removeFromSuperview()
            return
        }
        
        // if header layout is nil, no header view
        guard var header = _headers?[section] else {
            headerView.section = nil
            headerView.removeFromSuperview()
            return
        }
        
        // update position
        header.origin.y = offset + min(distance - header.height, 0)
        
        // header view position is chnage?
        if headerView.frame != header {
            headerView.frame = header
        }
        
        // the header view section is change?
        if headerView.section != section {
            headerView.section = section
        }
        
        // the header view need show?
        if headerView.superview == nil {
            collectionView.insertSubview(headerView, at: 0)
        }
    }
    
    /// Update header view caches
    private func _updateHeaderCaches() {
        // collection view must be set
        guard let collectionView = collectionView, _headerView != nil else {
            return
        }
        
        // fetch all header layout attributes
        _headers = (0 ..< collectionView.numberOfSections).map {
            collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionElementKindSectionHeader, at: .init(item: 0, section: $0))?.frame
        }
        
        // cache is change, must update header view
        _updateHeaderView()
    }
    
    /// Update footer view & layout
    private func _updateFooterView() {
        // collection view must be set
        guard let collectionView = collectionView, let footerView = _footerView else {
            return
        }
        
        // the content size is change?
        let contentSize = collectionViewLayout.collectionViewContentSize
        
        var nframe = footerView.frame
        nframe.origin.y = contentSize.height + 0
        nframe.size.width = view.bounds.width
        
        // footer view position is change?
        if footerView.frame != nframe {
            footerView.frame = nframe
        }
        
        // calculates the height of the current minimum display
        let top = collectionView.contentInset.top - _footerViewInset.top
        let bottom = collectionView.contentInset.bottom - _footerViewInset.bottom
        let visableHeight = view.frame.height - top - bottom
        guard visableHeight < contentSize.height else {
            // too small to hide footer view
            _footerView?.alpha = 0
            _footerViewInset.bottom = 0
            return
        }
        
        // if status has change
        if footerView.alpha != 1 {
            // too large to show footer view & update content insets
            _footerView?.alpha = 1
            _footerViewInset.bottom = footerView.frame.height
        }
    }
    
    /// Tap header view
    fileprivate dynamic func _hanleHeader(_ sender: Any) {
        // the section must be set
        guard let section = _headerView?.section, let frame = _headers?[section] else {
            return
        }
        logger.debug?.write(frame, section)
        
        // scroll to header start position
        collectionView?.scrollRectToVisible(frame, animated: true)
    }
    
    
    // MARK: Property
    
    
    // library status
    private(set) var prepared: Bool = false
    private(set) var authorized: Bool = false
    private(set) var transitioning: Bool = false
    
    private(set) var container: Container
    private(set) var source: Source {
        willSet {
            // update header view & footer view
            _headerView?.source = newValue
            _footerView?.source = newValue
            
            // only when in did not set the title will be updated
            super.title = _cachedTitle ?? newValue.title
        }
    }
    
    // Minimum interval between each item allowed
    static var minimumItemSpacing: CGFloat {
        set { return BrowserAlbumLayout.minimumItemSpacing = newValue }
        get { return BrowserAlbumLayout.minimumItemSpacing }
    }
    
    // Minimum size of each item allowed
    static var minimumItemSize: CGSize  {
        set { return BrowserAlbumLayout.minimumItemSize = newValue }
        get { return BrowserAlbumLayout.minimumItemSize }
    }
    
    // MARK: Ivar
    
    // cache
    private var _targetContentOffset: CGPoint = .zero
    private var _previousPreheatRect: CGRect = .zero
    private var _previousTargetPreheatRect: CGRect = .zero
    
    // footer
    private var _footerView: NavigationFooterView?
    private var _footerViewInset: UIEdgeInsets = .zero {
        willSet {
            // collectionView must be set
            guard let collectionView = collectionView, newValue != _footerViewInset else {
                return
            }
            var edg = collectionView.contentInset
            
            edg.top += newValue.top - _footerViewInset.top
            edg.left += newValue.left - _footerViewInset.left
            edg.right += newValue.right - _footerViewInset.right
            edg.bottom += newValue.bottom - _footerViewInset.bottom
            
            collectionView.contentInset = edg
        }
    }
    
    // header
    private var _header: Int = 0
    private var _headers: [CGRect?]?
    private var _headerView: NavigationHeaderView?
    
    private var _cachedSize: CGSize?
    private var _cachedTitle: String?
}
