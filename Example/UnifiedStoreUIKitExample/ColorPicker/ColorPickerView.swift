import UIKit
import Loop

final class ColorPickerViewController: ContentViewController<ColorPickerView> {
    private let store: Loop<ColorPicker.State, ColorPicker.Event>

    init(store: Loop<ColorPicker.State, ColorPicker.Event>) {
        self.store = store
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        store.context.startWithValues(contentView.render)
        contentView.didSelect.action = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

final class ColorPickerView: UIView, NibLoadable {
    @IBOutlet var stackView: UIStackView!
    let didTapButton = CommandWith<UIColor>()
    let didSelect = Command()

    func render(context: Context<ColorPicker.State, ColorPicker.Event>) {
        zip(stackView.arrangedSubviews, context.colors).forEach { (view, color) in
            view.backgroundColor = color
        }
        didTapButton.action = { color in
            context.send(event: .didPick(color))
        }
    }

    @IBAction func didTapButton(sender: UIButton) {
        didTapButton.action(sender.backgroundColor ?? .clear)
        didSelect.action()
    }
}
