//
//  VertrauenspersonRegistrierung.swift
//  AfterLife
//
//  Created by René Engeler on 26.06.2026.
//


import SwiftUI

struct VertrauenspersonRegistrierung: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image("Icon1_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)

                Text("VertrauenspersonRegistrierung")
                    .font(.title2.bold())

                Text("Diese Ansicht wird im nächsten Schritt aufgebaut.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    VertrauenspersonRegistrierung()
}
