import SwiftUI

struct Deleted: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Schade, dass Du gehen :(")
                .font(.title)
                .fontWeight(.bold)

            Text("Das Profil und die Daten wurden vollständig gelöscht.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Profil gelöscht")
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        Deleted()
    }
}
