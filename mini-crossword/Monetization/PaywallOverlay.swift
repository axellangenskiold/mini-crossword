import SwiftUI

struct PaywallOverlay: View {
    let title: String
    let message: String
    let premiumPrice: String
    let isProcessing: Bool
    let errorMessage: String?
    let onWatchAd: () -> Void
    let onGoPremium: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(6)
                            .background(Theme.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text(title)
                    .font(Theme.titleFont(size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)

                Text(message)
                    .font(Theme.bodyFont(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(action: onWatchAd) {
                        Text(isProcessing ? "Loading..." : "Watch ad to unlock")
                            .font(Theme.bodyFont(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isProcessing)

                    Button(action: onGoPremium) {
                        Text("Go Premium \(premiumPrice)")
                            .font(Theme.bodyFont(size: 16))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.ink.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .disabled(isProcessing)
                }

                Button(action: onRestore) {
                    Text("Restore purchases")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(Theme.bodyFont(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.12), radius: 18, x: 0, y: 8)
            .padding(24)
        }
    }
}
