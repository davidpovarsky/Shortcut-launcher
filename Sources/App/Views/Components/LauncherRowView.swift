import SwiftUI

struct LauncherRowView: View {
    let profile: LauncherProfile

    var body: some View {
        let state = profile.resolvedState()
        let style = profile.appearance.style(for: state)

        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text(state.defaultTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: style.symbolName)
                .foregroundStyle(style.tint.color)
        }
    }
}
