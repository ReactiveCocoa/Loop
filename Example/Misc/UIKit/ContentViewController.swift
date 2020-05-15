import UIKit

open class ContentViewController<Content: UIView & NibLoadable>: UIViewController {
    private(set) lazy var contentView = Content.loadFromNib()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func loadView() {
        view = contentView
    }
}
