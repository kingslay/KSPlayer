//
//  Persistence.swift
//  DataTest
//
//  Created by kintan on 2023/7/2.
//

import CloudKit
import CoreData
import KSPlayer
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        var urls: [String] = [
            "https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u",
            "https://iptv-org.github.io/iptv/index.m3u",
            "https://iptv-org.github.io/iptv/countries/cn.m3u",
            "https://iptv-org.github.io/iptv/countries/hk.m3u",
            "https://iptv-org.github.io/iptv/countries/tw.m3u",
            "https://iptv-org.github.io/iptv/regions/amer.m3u",
            "https://iptv-org.github.io/iptv/regions/asia.m3u",
            "https://iptv-org.github.io/iptv/regions/eur.m3u",
            "https://iptv-org.github.io/iptv/categories/education.m3u",
            "https://iptv-org.github.io/iptv/categories/movies.m3u",
            "https://iptv-org.github.io/iptv/languages/zho.m3u",
            "https://iptv-org.github.io/iptv/languages/eng.m3u",
            "https://raw.githubusercontent.com/kingslay/KSPlayer/develop/Tests/KSPlayerTests/test.m3u",
            "https://raw.githubusercontent.com/kingslay/bulaoge/main/bulaoge.m3u",
        ]
        urls.forEach { str in
            if let url = URL(string: str) {
                _ = M3UModel(context: viewContext, url: url)
            }
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer
    let viewContext: NSManagedObjectContext
    let privateStore: NSPersistentStore?
    init(inMemory: Bool = false) {
        let modelName = "Model"
        // load Data Model
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url)
        else {
            fatalError("Can't get \(modelName).momd in Bundle")
        }
        container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)
        viewContext = container.viewContext
//        viewContext = container.newBackgroundContext()
        let publicURL: URL
        let privateURL: URL
        let localURL: URL
        if inMemory {
            publicURL = URL(fileURLWithPath: "/dev/null")
            privateURL = URL(fileURLWithPath: "/dev/null")
            localURL = URL(fileURLWithPath: "/dev/null")

        } else {
            let directory = NSPersistentContainer.defaultDirectoryURL()
            KSLog("coreData directory \(directory)")
            publicURL = directory.appendingPathComponent("public.sqlite")
            privateURL = directory.appendingPathComponent("private.sqlite")
            localURL = directory.appendingPathComponent("local.sqlite")
        }
        let publicDesc = NSPersistentStoreDescription(url: publicURL)
        publicDesc.configuration = "public"
        publicDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.TracyPlayer")
        publicDesc.cloudKitContainerOptions?.databaseScope = .public
        publicDesc.setOption(true as NSObject, forKey: NSPersistentHistoryTrackingKey)
        publicDesc.setOption(true as NSObject, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let privateDesc = NSPersistentStoreDescription(url: privateURL)
        privateDesc.configuration = "private"
        privateDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.TracyPlayer")
        privateDesc.setOption(true as NSObject, forKey: NSPersistentHistoryTrackingKey)
        privateDesc.setOption(true as NSObject, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let localDesc = NSPersistentStoreDescription(url: localURL)
        localDesc.configuration = "local"
        localDesc.setOption(true as NSObject, forKey: NSPersistentHistoryTrackingKey)
        localDesc.setOption(true as NSObject, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [localDesc, privateDesc, publicDesc]
//        let persistentStoreCoordinator = container.persistentStoreCoordinator
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */

                KSLog("Unresolved error \(error), \(error.userInfo), store url \(String(describing: storeDescription.url))")
//                if let url = storeDescription.url {
//                    try? persistentStoreCoordinator.destroyPersistentStore(at: url, type: .sqlite)
//                }
            }
        }
        privateStore = container.persistentStoreCoordinator.persistentStore(for: privateURL)
        let viewContext = container.newBackgroundContext()
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//        #if DEBUG
//        viewContext.mergePolicy = NSOverwriteMergePolicy
//        #endif
        viewContext.perform {
            do {
                try viewContext.setQueryGenerationFrom(.current)
            } catch {
                fatalError("Failed to pin viewContext to the current generation:\(error)")
            }
        }
//        let privateContainer = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)
//        privateContainer.persistentStoreDescriptions = [privateDesc]
//        privateContainer.loadPersistentStores { _, _ in
//        }
//        privateContainer.viewContext.automaticallyMergesChangesFromParent = true
//        privateContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//        try? privateContainer.viewContext.setQueryGenerationFrom(.current)
    }
}
