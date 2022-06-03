import Foundation
import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(activityItems: activityItems, applicationActivities: applicationActivities, isPresented: $isPresented)
    }

    func updateUIViewController(_ controller: UIViewControllerType, context: Context) {
        controller.activityItems = activityItems
        controller.applicationActivities = applicationActivities
        controller.isPresented = $isPresented
        controller.update()
    }

    public class Controller: UIViewController {
        var activityItems: [Any] = []
        var applicationActivities: [UIActivity]? = nil
        var isPresented: Binding<Bool>

        private var presentedActivityView: UIActivityViewController?

        init(activityItems: [Any], applicationActivities: [UIActivity]?, isPresented: Binding<Bool>) {
            self.activityItems = activityItems
            self.applicationActivities = applicationActivities
            self.isPresented = isPresented
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            update()
        }

        func update() {
            let isPresented = presentedViewController != nil && presentedViewController == presentedActivityView
            if isPresented != self.isPresented.wrappedValue {
                if !isPresented {
                    let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)

                    controller.completionWithItemsHandler = { (_, _, _, _) in self.isPresented.wrappedValue = false }
                    controller.popoverPresentationController?.sourceView = view

                    presentedActivityView = controller
                    present(controller, animated: true)
                } else {
                    presentedActivityView?.dismiss(animated: true)
                    presentedActivityView = nil
                }
            }
        }
    }
}

class Activity: UIActivity {
    let title: String
    let image: UIImage?
    let action: () -> Void

    init(title: String, image: UIImage?, action: @escaping () -> Void) {
        self.title = title
        self.image = image
        self.action = action
        super.init()
    }

    override var activityTitle: String? { title }
    override var activityImage: UIImage? { image }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

    override func perform() {
        action()
    }
}
