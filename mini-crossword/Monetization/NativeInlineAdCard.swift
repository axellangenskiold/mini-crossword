import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds

struct NativeInlineAdCard: View {
    var body: some View {
        NativeInlineAdRepresentable()
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(0.20), radius: 10, x: 0, y: 6)
    }
}

private struct NativeInlineAdRepresentable: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InlineNativeAdContainerView {
        let view = InlineNativeAdContainerView()
        context.coordinator.attach(view: view)
        return view
    }

    func updateUIView(_ uiView: InlineNativeAdContainerView, context: Context) {
        context.coordinator.attach(view: uiView)
    }

    final class Coordinator: NSObject, AdLoaderDelegate, NativeAdLoaderDelegate {
        private weak var view: InlineNativeAdContainerView?
        private var adLoader: AdLoader?
        private var isLoading: Bool = false
        private var hasLoadedAd: Bool = false

        func attach(view: InlineNativeAdContainerView) {
            self.view = view
            loadIfNeeded()
        }

        private func loadIfNeeded() {
            guard !isLoading else { return }
            guard !hasLoadedAd else { return }
            guard let rootViewController = rootViewController() else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.loadIfNeeded()
                }
                return
            }

            isLoading = true
            AdMobManager.startIfNeeded()
            let loader = AdLoader(
                adUnitID: AdMobConfiguration.nativeAdUnitId,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: nil
            )
            adLoader = loader
            loader.delegate = self
            loader.load(Request())
        }

        private func rootViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            return scenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            isLoading = false
            hasLoadedAd = true
            view?.apply(nativeAd: nativeAd)
        }

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            isLoading = false
            hasLoadedAd = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.loadIfNeeded()
            }
        }
    }
}

private final class InlineNativeAdContainerView: NativeAdView {
    private let gradientLayer = CAGradientLayer()

    private let badgeLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func apply(nativeAd: NativeAd) {
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil

        let ctaText = nativeAd.callToAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        ctaButton.setTitle((ctaText?.isEmpty == false ? ctaText : "Open"), for: .normal)
        ctaButton.isHidden = false

        headlineView = headlineLabel
        bodyView = bodyLabel
        callToActionView = ctaButton
        callToActionView?.isUserInteractionEnabled = false

        self.nativeAd = nativeAd
    }

    private func setupUI() {
        layer.cornerRadius = 16
        clipsToBounds = true

        gradientLayer.colors = [
            UIColor(hex: 0x0F6B63).cgColor,
            UIColor(hex: 0x0F6B63, alpha: 0.75).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "Sponsored"
        badgeLabel.font = UIFont(name: "Avenir Next Condensed", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        badgeLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        badgeLabel.letterSpacing(0.8)

        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.text = "Mini Crossword Partner"
        headlineLabel.font = UIFont(name: "Avenir Next Condensed", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        headlineLabel.textColor = .white
        headlineLabel.numberOfLines = 1

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = "Discover something new while you play."
        bodyLabel.font = UIFont(name: "Avenir Next Condensed", size: 15) ?? .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        bodyLabel.numberOfLines = 1

        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.setTitle("Open", for: .normal)
        ctaButton.titleLabel?.font = UIFont(name: "Avenir Next Condensed", size: 16) ?? .systemFont(ofSize: 16, weight: .bold)
        ctaButton.setTitleColor(UIColor(hex: 0x0F6B63), for: .normal)
        ctaButton.backgroundColor = UIColor.white
        ctaButton.layer.cornerRadius = 10
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        ctaButton.clipsToBounds = true

        addSubview(badgeLabel)
        addSubview(headlineLabel)
        addSubview(bodyLabel)
        addSubview(ctaButton)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            headlineLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headlineLabel.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 2),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -10),

            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 1),
            bodyLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -10),

            ctaButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            ctaButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            ctaButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
        ])
    }
}

private extension UILabel {
    func letterSpacing(_ value: CGFloat) {
        guard let text else { return }
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.kern, value: value, range: NSRange(location: 0, length: attributed.length))
        attributedText = attributed
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#else
struct NativeInlineAdCard: View {
    var body: some View {
        EmptyView()
    }
}
#endif
