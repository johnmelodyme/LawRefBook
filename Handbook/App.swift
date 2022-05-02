import SwiftUI
import CoreSpotlight
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        application.registerForRemoteNotifications()
        print("registerForRemoteNotifications")
        
        return true
    }
    
}

@main
struct MainApp: App {
    
    @UIApplicationDelegateAdaptor
    private var appDelegate: AppDelegate


    @State
    var showNewPage = false

    @AppStorage("lastVersion")
    var lastVersion: String?

    @AppStorage("launchTimes")
    var launchTime: Int = 0
    
    private(set) var moc = Persistence.shared.container.viewContext

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                WelcomeView()
            }
            .sheet(isPresented: $showNewPage) {
                WhatNewView()
            }
            .environment(\.managedObjectContext, moc)
            .phoneOnlyStackNavigationView()
            .task {
                self.checkVersionUpdate()
                self.immigrateFavLaws()
                LawDatabase.shared.connect()
            }
        }
    }

    private func checkVersionUpdate(){
        let curVersion = UIApplication.appVersion
        if lastVersion == nil || lastVersion != curVersion {
//            showNewPage.toggle()
            lastVersion = curVersion
            SpotlightHelper.shared.createIndexes()
        }
    }
    
    private func immigrateFavLaws() {
        if LawProvider.shared.favoriteUUID.isEmpty {
           return
        }
        LawProvider.shared.queue.async {
            LawProvider.shared.favoriteUUID.enumerated().forEach { (i, val) in
                
                let req = FavLaw.fetchRequest()
                req.predicate = NSPredicate(format: "id == %@", val.uuidString)
                var flag = false
                if let arr = try? moc.fetch(req), !arr.isEmpty {
                    flag = true
                }
                if !flag {
                    let law = FavLaw(context: moc)
                    law.id = val
                    law.favAt = Date.now
                    do {
                        try moc.save()
                        DispatchQueue.main.async {
                            if let idx = LawProvider.shared.favoriteUUID.firstIndex(of: val) {
                                LawProvider.shared.favoriteUUID.remove(at: idx)
                            }
                        }
                    }catch{
                        print("\(val) 保存失败")
                    }
                }
            }
        }
    }

    private func checkRunTimes(){
        if launchTime == 4 {
            AppStoreReviewManager.requestReviewIfAppropriate()
        }
        launchTime += 1;
    }

}
