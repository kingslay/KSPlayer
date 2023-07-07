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
        for _ in 0 ..< 10 {}
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

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Model")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        let publicURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("public.sqlite")
        let publicDesc = NSPersistentStoreDescription(url: publicURL)
        publicDesc.configuration = "public"
        publicDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.kintan.tracy")
        publicDesc.cloudKitContainerOptions?.databaseScope = .public
        publicDesc.setOption(true as NSObject, forKey: NSPersistentHistoryTrackingKey)
        publicDesc.setOption(true as NSObject, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let privateURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("private.sqlite")
        let privateDesc = NSPersistentStoreDescription(url: privateURL)
        privateDesc.configuration = "private"
        privateDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.kintan.tracy")
        privateDesc.setOption(true as NSObject, forKey: NSPersistentHistoryTrackingKey)
        privateDesc.setOption(true as NSObject, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [publicDesc, privateDesc]
        let persistentStoreCoordinator = container.persistentStoreCoordinator
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
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//        #if DEBUG
//        container.viewContext.mergePolicy = NSRollbackMergePolicy
//        #endif
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("Failed to pin viewContext to the current generation:\(error)")
        }
    }
}
