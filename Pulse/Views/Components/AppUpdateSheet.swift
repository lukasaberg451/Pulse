import SwiftUI

struct AppUpdateSheet: View {
    let latestVersion: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.appAccent)

            Text("Update Available")
                .font(.title2.bold())
                .foregroundStyle(Color.appText)

            Text("A new version (\(latestVersion)) of Pulse is available. Update now to get the latest features and improvements.")
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
                    Text("Update Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Later")
                        .font(.subheadline)
                        .foregroundStyle(Color.appText.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}
