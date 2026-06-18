import SwiftUI

struct Logout: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Du wurdest ausgeloggt")
                .font(.title)
                .fontWeight(.bold)

            Text("Melde dich erneut an, um deine Daten wieder aufzurufen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Logout")
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        Logout()
    }
}
