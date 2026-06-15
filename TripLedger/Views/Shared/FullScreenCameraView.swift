import SwiftUI
import UIKit

/// Full screen camera view wrapper that hides status bar and navigation elements
struct FullScreenCameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController()
        viewController.selectedImage = $selectedImage
        viewController.presentationMode = presentationMode
        return viewController
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class CameraViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var selectedImage: Binding<UIImage?>?
        var presentationMode: Binding<PresentationMode>?

        override func viewDidLoad() {
            super.viewDidLoad()

            // Hide status bar
            modalPresentationCapturesStatusBarAppearance = true

            // Present camera immediately
            presentCamera()
        }

        override var prefersStatusBarHidden: Bool {
            return true
        }

        override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
            return .fade
        }

        private func presentCamera() {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.modalPresentationStyle = .fullScreen
            picker.showsCameraControls = true

            // Hide navigation bar and toolbar
            picker.navigationBar.isHidden = true
            picker.isToolbarHidden = true

            // Present immediately
            present(picker, animated: false)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                selectedImage?.wrappedValue = image
            }

            // Dismiss camera picker first
            picker.dismiss(animated: true) { [weak self] in
                // Then dismiss this wrapper
                self?.presentationMode?.wrappedValue.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Dismiss camera picker first
            picker.dismiss(animated: true) { [weak self] in
                // Then dismiss this wrapper
                self?.presentationMode?.wrappedValue.dismiss()
            }
        }
    }
}
