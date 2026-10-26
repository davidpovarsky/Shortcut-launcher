import UIKit
import Intents
import IntentsUI

final class SiriPanelViewController: UIViewController, INUIHostedViewControlling {
    private let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        preferredContentSize = CGSize(width: 540, height: 460)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        label.text = "Dav Siri Panel\nRequested 540 x 460\nActual \(Int(view.bounds.width)) x \(Int(view.bounds.height))"
    }
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction,
                       interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext,
                       completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        completion(true, parameters, preferredContentSize)
    }
}
