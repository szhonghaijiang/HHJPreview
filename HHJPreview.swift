//
//  HHJPreview.swift
//  HHJPreview
//
//  Created by bu88 on 2018/9/3.
//  Copyright © 2018年 HHJ. All rights reserved.
//

import UIKit

enum PreviewScrollDirection {
    case left
    case right
}

/// 子视图的代理协议，主视图实现这个代理方法响应子视图点击退出
fileprivate protocol HHJSubPreviewProtocol: NSObjectProtocol {
    func tapDismiss(animationImagView: UIImageView?);
    func didDragging(alpha: CGFloat)
    func willStartDragging() -> UIImageView
    func didEndDragging()
    func longPressAtIndex(_ index: Int, imageView: UIImageView)
}

public class HHJPreview: UIView, UIScrollViewDelegate {
    fileprivate var imageViews = [SGPreviewScrollView]()
    fileprivate let scrollView = UIScrollView()
    fileprivate var currentImageView: SGPreviewScrollView!
    fileprivate let pageControl = UIPageControl()
    public var currentPageIndicatorTintColor = UIColor(red: 255.0/255.0, green: 102.0/255.0, blue: 0.0/255.0, alpha: 1.0)
    public var pageControlerTintColor = UIColor.gray
    lazy var animateImageView: UIImageView = {
        let animateImageView = UIImageView()
        animateImageView.contentMode = .scaleAspectFill;
        animateImageView.layer.masksToBounds = true;
        return animateImageView
    }()
    
    let imageCount: Int
    /// 设置数据源，finishBlock请在设置图片完成后调用
    private let dataSourceBlock: (_ imageView: UIImageView, _ index: Int, _ finishBlock:@escaping () -> Void) -> Void
    private let infiniteScrollView: Bool
    fileprivate var dismissAt: ((_ index: Int) -> UIView?)?
    fileprivate var longPressBlock: ((_ index: Int, _ imageView: UIImageView, _ finishBlock:@escaping () -> Void) -> Void)?
    fileprivate var longPressIng = false
    
    
    /// 初始化方法
    ///
    /// - Parameters:
    ///   - from: 从哪个imgeView弹出的放大图片，如果有值，则有一个放大的动画，如果传nil，则动画较为生硬
    ///   - imageCount: 要放大的图片数量
    ///   - offSet: 当前放大的是第几张图片
    ///   - dataSource: 数据源，当展示到这个图片是，会回调这个blcok，使用者需要在这个block内部为UIImageView设置图片，设置完成后请调用finishBlock
    ///   - dismissAt: 消失时，消失到哪个视图上面去，也会有一个动画
    ///   - longPressBlock: 长按的回调，在长按结束后请调用finishBlock
    public init(from: UIImageView?, imageCount: Int, offSet: Int = 0, infiniteScrollView: Bool = false,  dataSource:@escaping (_ imageView: UIImageView, _ index: Int, _ finishBlock:@escaping () -> Void) -> Void, dismissAt: ((_ index: Int) -> UIView?)?, longPressBlock: ((_ index: Int, _ imageView: UIImageView, _ finishBlock:@escaping () -> Void) -> Void)?) {
        self.dataSourceBlock = dataSource
        self.imageCount = imageCount
        self.infiniteScrollView = infiniteScrollView
        super.init(frame: UIScreen.main.bounds)
        self.dismissAt = dismissAt
        self.longPressBlock = longPressBlock
        loadSubView(from: from, offSet: offSet)
    }
    
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 初始化所有视图
    fileprivate func loadSubView(from: UIImageView?, offSet: Int = 0) {
        scrollView.frame = bounds
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.isPagingEnabled = true
        scrollView.delegate = self
        var imageViewCount = 3
        if !infiniteScrollView {
            imageViewCount = imageCount
            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width*CGFloat(offSet), y: 0)
        } else {
            
            scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
        }
        scrollView.contentSize = CGSize(width: CGFloat(imageViewCount)*scrollView.bounds.size.width, height: 0)
        for _ in 0..<imageViewCount {
            let imageView = SGPreviewScrollView(frame: scrollView.bounds)
            imageView.delegate = self
            imageViews.append(imageView)
            scrollView.addSubview(imageView)
        }
        
        pageControl.currentPage = 0;
        pageControl.pageIndicatorTintColor = pageControlerTintColor
        self.pageControl.currentPageIndicatorTintColor = currentPageIndicatorTintColor
        self.pageControl.backgroundColor = UIColor.clear
        
        var dump: UIImageView?
        var dstRect = CGRect.zero
        if let realFrom = from {
            let srcRect = realFrom.convert(realFrom.bounds, to: self)
            let dumpImageView = UIImageView()
            dump = dumpImageView
            dumpImageView.frame = srcRect
            dumpImageView.image = realFrom.image
            dumpImageView.contentMode = realFrom.contentMode
            addSubview(dumpImageView)
            var size = dumpImageView.bounds.size
            if let image = dumpImageView.image {
                size = image.size
            }
            let destRectHeight = bounds.size.width/size.width*size.height
            dstRect = CGRect(x: 0, y: (bounds.size.height-destRectHeight)*0.5, width: bounds.size.width, height: destRectHeight);
        } else {
            addSubview(scrollView)
            scrollView.alpha = 0
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions(rawValue: 7), animations: {[weak self] in
            guard let weakSelf = self else {
                return
            }
            
            weakSelf.backgroundColor = UIColor.black
            if let dumpImageView = dump {
                dumpImageView.frame = dstRect
            } else {
                weakSelf.scrollView.alpha = 1
            }
        }) { [weak self](finished) in
            guard let weakSelf = self else {
                return
            }
            
            if let dumpImageView = dump {
                dumpImageView.removeFromSuperview()
                weakSelf.addSubview(weakSelf.scrollView)
                weakSelf.addSubview(weakSelf.pageControl)
            }
        }
        
        UIApplication.shared.keyWindow?.addSubview(self)
        reloadSubView(offSet: offSet)
    }
    
    /// 当获得新的数据调用该方法刷新一下显示，第一次创建本对象时不需要调用，会自动调用
    func reloadSubView(offSet: Int = 0) {
        if imageCount <= 1 {
            scrollView.isScrollEnabled = false;
        } else {
            scrollView.isScrollEnabled = true
        }
        for (index, imageView) in imageViews.enumerated() {
            var bannerModelIndex = index-1+offSet
            if !infiniteScrollView {
                bannerModelIndex = index
            }
            if bannerModelIndex < 0 {
                bannerModelIndex = imageCount-1
            } else if (bannerModelIndex >= imageCount) {
                bannerModelIndex = 0
            }
            setImageView(imageView, forImageAt: bannerModelIndex)
            imageView.index = bannerModelIndex
            imageView.frame.origin.x = scrollView.bounds.size.width * CGFloat(index)
            if imageView.frame.origin.x == scrollView.contentOffset.x {
                currentImageView = imageView
            }
        }
        
        pageControl.numberOfPages = imageCount
        pageControl.currentPage = offSet
        let pageControlSizeHeight:CGFloat = 21
        let pageControlSize = pageControl.size(forNumberOfPages: imageCount)
        pageControl.frame = CGRect(x: (bounds.size.width-pageControlSize.width)*0.5, y: bounds.size.height-pageControlSizeHeight, width: pageControlSize.width, height: pageControlSizeHeight)
    }
    
    private func setImageView(_ imageView: SGPreviewScrollView, forImageAt index:Int) {
        dataSourceBlock(imageView.imageView, index) {[weak imageView] in
            guard let weakImageView = imageView else {
                return
            }
            weakImageView.reloadImageViewContent()
        }
    }
    
    //监听滑动事件，修改显示的各种东西
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !infiniteScrollView {
            let index = min(max(Int((scrollView.contentOffset.x+scrollView.bounds.size.width*0.5)/scrollView.bounds.size.width), 0), imageCount)
            setPageControlCurrentIndex(index: index)
            if imageViews.count > index {
                currentImageView = imageViews[index]
            }
            return
        }
        
        if scrollView.contentOffset.x > 0 && scrollView.contentOffset.x < 2*scrollView.bounds.size.width {
            return
        }
        
        
        if scrollView.contentOffset.x <= 0 {
            getCurrentIamgeView(direction:.left)
            for (_, imageView) in imageViews.enumerated() {
                if imageView.frame.origin.x-scrollView.contentOffset.x<scrollView.bounds.size.width*1.5 {
                    imageView.frame = CGRect(x: imageView.frame.origin.x + scrollView.bounds.size.width, y: imageView.frame.origin.y, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
                } else {
                    imageView.frame = CGRect(x: 0, y: imageView.frame.origin.y, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
                    var index = currentImageView.index-1
                    if index < 0 {
                        index = imageCount-1
                    }
                    imageView.index = index
                    setImageView(imageView, forImageAt: index)
                }
            }
        } else if scrollView.contentOffset.x >= 2*scrollView.bounds.size.width {
            getCurrentIamgeView(direction: .right)
            for (_, imageView) in imageViews.enumerated() {
                if scrollView.contentOffset.x-imageView.frame.origin.x<scrollView.bounds.size.width*1.5 {
                    imageView.frame = CGRect(x: imageView.frame.origin.x-scrollView.bounds.size.width, y: imageView.frame.origin.y, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
                } else {
                    imageView.frame = CGRect(x: scrollView.bounds.size.width*2, y: imageView.frame.origin.y, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
                    var index = currentImageView.index+1
                    if index >= imageCount {
                        index = 0
                    }
                    imageView.index = index
                    setImageView(imageView, forImageAt: index)
                }
            }
        }
        scrollView.contentOffset = CGPoint(x: scrollView.bounds.size.width, y: 0)
    }
    
    fileprivate func getCurrentIamgeView(direction: PreviewScrollDirection) {
        var currentImageViewX: CGFloat = 0
        if direction == .right {
            currentImageViewX = 2*scrollView.bounds.size.width
        }
        for (_, imageView) in imageViews.enumerated() {
            if (imageView.frame.origin.x == currentImageViewX) {
                currentImageView = imageView
                setPageControlCurrentIndex(index: currentImageView.index)
                break
            }
        }
    }
    
    fileprivate func setPageControlCurrentIndex(index: Int) {
        pageControl.currentPage = index
    }
}

extension HHJPreview: HHJSubPreviewProtocol {
    func tapDismiss(animationImagView: UIImageView?) {
        var dumpImageView = animationImagView
        var descRect = CGRect.zero
        if let realDismissAtBlock = dismissAt, let dismissFormView = realDismissAtBlock(currentImageView.index) {
            DispatchQueue.main.async {[weak self] in
                guard let weakSelf = self else {
                    return
                }
                descRect = dismissFormView.convert(dismissFormView.bounds, to: self)
                if dumpImageView == nil {
                    let tempDumpImageView = UIImageView()
                    tempDumpImageView.image = weakSelf.currentImageView.imageView.image
                    tempDumpImageView.contentMode = dismissFormView.contentMode
                    tempDumpImageView.clipsToBounds = true
                    dumpImageView = tempDumpImageView
                    weakSelf.addSubview(tempDumpImageView)
                    
                    let size = weakSelf.currentImageView.imageView.bounds.size
                    var fromRectHeight = weakSelf.bounds.size.width/size.width*size.height
                    if fromRectHeight.isNaN {
                        fromRectHeight = 0
                    }
                    tempDumpImageView.frame = CGRect(x: 0, y: (weakSelf.bounds.size.height-fromRectHeight)*0.5, width: weakSelf.bounds.size.width, height: fromRectHeight);
                }
                weakSelf.backgroundColor = UIColor.clear
                weakSelf.scrollView.removeFromSuperview()
                weakSelf.dimissFromDescRect(descRect, dumpImageView: dumpImageView)
            }
        } else {
            dimissFromDescRect(descRect, dumpImageView: dumpImageView)
        }
    }
    
    func dimissFromDescRect(_ descRect:CGRect, dumpImageView: UIImageView?) {
        UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions(rawValue: 7), animations: {
            if let iv = dumpImageView {
                if descRect != .zero {
                    iv.frame = descRect
                } else {
                    iv.alpha = 0
                    self.alpha = 0
                }
            } else {
                self.alpha = 0
            }
        }) { (finished) in
            if let iv = dumpImageView {
                iv.removeFromSuperview()
            }
            self.removeFromSuperview()
        }
    }
    
    func didDragging(alpha: CGFloat) {
        backgroundColor = UIColor.black.withAlphaComponent(alpha)
    }
    
    func willStartDragging() -> UIImageView {
        scrollView.isScrollEnabled = false
        return animateImageView
    }
    
    func didEndDragging() {
        if imageCount > 1 {
            scrollView.isScrollEnabled = true
        }
    }
    
    func longPressAtIndex(_ index: Int, imageView: UIImageView) {
        if longPressIng {
            return
        }
        longPressIng = true
        
        if let realLongPressBlock = longPressBlock {
            realLongPressBlock(index, imageView) {[weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.longPressIng = false
            }
        }
    }
}

class SGPreviewScrollView: UIView, UIScrollViewDelegate {
    let imageView = UIImageView()
    let scrollView = UIScrollView()
    fileprivate weak var delegate: HHJSubPreviewProtocol!
    
    /// 拖动动画相关
    var startDragging = false
    var startPoint = CGPoint.zero
    var animateImageView: UIImageView!
    var frameOfOriginalOfImageView = CGRect.zero
    var lastPoint: CGPoint = CGPoint.zero // 上一次触摸点
    var totalOffset: CGSize = CGSize.zero // 总共的拖动偏移
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        scrollView.backgroundColor = UIColor.clear
        backgroundColor = UIColor.clear
        addSubview(scrollView)
        scrollView.maximumZoomScale = 2.5;
        scrollView.minimumZoomScale = 1.0;
        scrollView.addSubview(imageView)
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(SGPreviewScrollView.longPress(_:))))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(SGPreviewScrollView.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        let ontTap = UITapGestureRecognizer(target: self, action: #selector(SGPreviewScrollView.oneTapDismiss(_:)))
        addGestureRecognizer(ontTap)
        ontTap.require(toFail: doubleTap)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadImageViewContent() {
        
        if let myImage = imageView.image {
            imageView.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: myImage.size.height*bounds.size.width/myImage.size.width)
            if imageView.bounds.height < bounds.size.height {
                imageView.frame = CGRect(x: 0, y: (bounds.size.height-imageView.bounds.size.height)*0.5, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
            } else {
                imageView.frame = CGRect(x: 0, y: 0, width: imageView.bounds.size.width, height: imageView.bounds.size.height)
            }
            scrollView.contentSize = imageView.bounds.size
        } else {
            imageView.image = nil
        }
    }
    
    var index = 0
    
    override var frame: CGRect {
        didSet {
            if bounds.equalTo(imageView.frame) == false {
                scrollView.frame = bounds
            }
        }
    }
    
    
    /// 单击退出
    @objc func oneTapDismiss(_ tap: UITapGestureRecognizer) {
        delegate.tapDismiss(animationImagView: nil)
    }
    
    
    /// 双击放大
    @objc func doubleTap(_ tap: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.contentInset = .zero
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let touchPoint = tap.location(in: imageView)
            let newZoomScale = scrollView.maximumZoomScale
            let xsize = bounds.size.width/newZoomScale
            let ysize = bounds.size.height/newZoomScale
            scrollView.zoom(to: CGRect(x: touchPoint.x-xsize*0.5, y: touchPoint.y-ysize*0.5, width: xsize, height: ysize), animated: true)
        }
    }
    
    
    /// 长按保存
    @objc func longPress(_ tap: UITapGestureRecognizer) {
        delegate.longPressAtIndex(index, imageView: imageView)
    }
    
    //MARK:-------------UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.contentInset = .zero
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        var offsetX:CGFloat = 0.0
        var offsetY:CGFloat = 0.0
        if scrollView.bounds.size.width>scrollView.contentSize.width {
            offsetX = (scrollView.bounds.size.width-scrollView.contentSize.width)*0.5
        }
        if scrollView.bounds.size.height>scrollView.contentSize.height {
            offsetY = (scrollView.bounds.size.height-scrollView.contentSize.height)*0.5
        }
        self.imageView.center = CGPoint(x: scrollView.contentSize.width*0.5+offsetX, y: scrollView.contentSize.height*0.5+offsetY)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView.panGestureRecognizer.numberOfTouches > 1 {
            return
        }
        startDragging = true
        let point = scrollView.panGestureRecognizer.location(in: self)
        lastPoint = point
        animateImageView = delegate.willStartDragging()
        animateImageView.image = imageView.image
        frameOfOriginalOfImageView = imageView.convert(imageView.bounds, to: UIApplication.shared.keyWindow)
        if frameOfOriginalOfImageView.size.width == 0 || frameOfOriginalOfImageView.size.height == 0 {
            startPoint = .zero
        } else {
            startPoint = CGPoint(x: (point.x - frameOfOriginalOfImageView.origin.x) / frameOfOriginalOfImageView.size.width, y: (point.y - frameOfOriginalOfImageView.origin.y) / frameOfOriginalOfImageView.size.height)
        }
        animateImageView.frame = frameOfOriginalOfImageView
        totalOffset = .zero
        UIApplication.shared.keyWindow?.addSubview(animateImageView)
        imageView.isHidden = true
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if animateImageView == nil {
            return
        }
        startDragging = false
        delegate.didEndDragging()
        
        if animateImageView.bounds.size.height > frameOfOriginalOfImageView.height * 0.75 {
            UIView.animate(withDuration: 0.25, animations: {[weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.animateImageView.frame = weakSelf.frameOfOriginalOfImageView
                weakSelf.delegate.didDragging(alpha: 1)
            }) {[weak self] (finished) in
                guard let _ = self else {
                    return
                }
            }
        } else {
            delegate.tapDismiss(animationImagView: animateImageView)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        imageView.isHidden = false
        if animateImageView != nil {
            animateImageView.removeFromSuperview()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0 {
            return
        }
        
        if !startDragging {
            return
        }
        
        let point = scrollView.panGestureRecognizer.location(in: self)
        let offSetX = point.x - lastPoint.x
        let offSetY = point.y - lastPoint.y
        
        totalOffset = CGSize(width: totalOffset.width+offSetX, height: totalOffset.height+offSetY)
        var scale = 1 - totalOffset.height / bounds.size.height
        scale = min(max(scale, 0), 1)
        let animationSzie = CGSize(width: frameOfOriginalOfImageView.size.width * scale, height: frameOfOriginalOfImageView.size.height * scale)
        animateImageView.frame = CGRect(x: point.x - animationSzie.width * startPoint.x, y: point.y - animationSzie.height * startPoint.y, width: animationSzie.width, height: animationSzie.height)
        lastPoint = point
        delegate.didDragging(alpha: scale)
    }
}
