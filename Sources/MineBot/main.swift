import SwiftUI

@main
struct MineBotApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

}

struct ContentView: View {

    var body: some View {

        VStack(spacing: 20) {

            Text("MineBot")
                .font(.largeTitle)

            Text("Running successfully")

        }
        .padding()

    }

}
