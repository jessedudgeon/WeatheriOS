//
//  ContentView.swift
//  Shared
//
//  Created by Jesse Dudgeon on 7/22/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "cloud.moon.bolt")
                    .font(.largeTitle)
                Text("24º")
                    .font(.largeTitle)
            }
            Text("Storming bruh.\nDon't go out there")
                .font(.body)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
