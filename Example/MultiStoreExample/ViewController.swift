import UIKit
import ReactiveSwift
import ReactiveCocoa
import Loop

class ViewController: UIViewController {
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var label: UILabel!
    private lazy var contentView = CounterView.loadFromNib()
    private let viewModel = Counter.ViewModel()

    override func loadView() {
        self.view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.store.context.startWithValues(contentView.render)
    }
}

extension Counter {
    final class ViewModel {
        let store: Loop<State, Event>

        init() {
            store = .init(
                initial: State(),
                reducer: Counter.reduce,
                feedbacks: []
            )
        }
    }
}
