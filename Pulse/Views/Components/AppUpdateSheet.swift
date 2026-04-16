import SwiftUI

struct AppUpdateSheet: View {
    let latestVersion: String
    let isForced: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isForced ? "exclamationmark.arrow.circlepath" : "arrow.down.app.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.appAccent)

            Text(isForced ? String(localized: "Update Required") : String(localized: "Update Available"))
                .font(.title2.bold())
                .foregroundStyle(Color.appText)

            Text(isForced
                 ? String(localized: "Your version of Pulse is no longer supported. Please update to continue using the app.")
                 : String(localized: "A new version (\(latestVersion)) of Pulse is available. Update now to get the latest features and improvements."))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appText.opacity(0.7))
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    if let url = AppUpdateChecker.shared.appStoreURL as URL? {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Update Now", comment: "App update button")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if !isForced {
                    Button {
                        dismiss()
                    } label: {
                        Text("Later", comment: "Dismiss update button")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(isForced ? .hidden : .visible)
        .presentationBackground(Color.appBackground)
        .interactiveDismissDisabled(isForced)
    }
}
