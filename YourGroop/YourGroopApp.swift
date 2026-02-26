import SwiftUI

@main
struct YourGroopApp: App {
    @State private var appModel: AppModel
    @State private var router = AppRouter()

    init() {
        let repository = InMemoryGroopRepository(apiClient: MockAPIClient())
        _appModel = State(initialValue: AppModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appModel)
                .environment(router)
                .task {
                    let autoSignIn = ProcessInfo.processInfo.arguments.contains("UITEST_AUTOSIGNIN")
                    await appModel.bootstrap(autoSignIn: autoSignIn)
                }
                .onOpenURL { url in
                    if let route = DeepLinkParser.route(from: url) {
                        router.navigate(to: route)
                    }
                }
        }
    }
}
