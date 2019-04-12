//
//  ObjectQueue.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import Foundation
public final class ObjectQueue<Item: ObjectQueueItem> {
    private let condition = NSCondition()
    private var destoryed = false
    private var objects = [Item]()
    private var puttingObject: Item?
    private var currentIndex = 0
    public let maxCount: Int
    // 视频有可能不是按顺序解码。所以一定要排序下，不然画面会来回抖动
    private let sortObjects: Bool
    //    public var duration: Int64 = 0
    //    public var size: Int64 = 0
    public var count: Int {
        condition.lock()
        let count = objects.count
        condition.unlock()
        return count
    }

    public init(maxCount: Int = Int.max, sortObjects: Bool = false) {
        self.maxCount = maxCount
        self.sortObjects = sortObjects
    }

    func putObjectSync(object: Item) {
        guard !destoryed else { return }
        condition.lock()
        while objects.count >= maxCount {
            puttingObject = object
            condition.wait()
            if destoryed || puttingObject == nil {
                condition.unlock()
                return
            }
            puttingObject = nil
        }

        if sortObjects {
            // 不用sort进行排序，这个比较高效
            var index = objects.count - 1
            while index >= 0 {
                if objects[index].position < object.position {
                    break
                }
                index -= 1
            }
            objects.insert(object, at: index + 1)
        } else {
            objects.append(object)
        }
        //            duration += object.duration
        //            size += object.size
        // 只有数据了。就signal。因为有可能这是最后的数据了。
        if objects.count == 1 {
            condition.signal()
        }
        condition.unlock()
    }

    func getObjectSync() -> Item? {
        condition.lock()
        if destoryed {
            condition.unlock()
            return nil
        }
        if objects.isEmpty {
            condition.wait()
            if destoryed || objects.isEmpty {
                condition.unlock()
                return nil
            }
        }
        let object = getObject()
        condition.unlock()
        return object
    }

    func getObjectAsync(where predicate: ((Item) -> Bool)?) -> Item? {
        condition.lock()
        guard !destoryed, let first = objects.first else {
            condition.unlock()
            return nil
        }
        var object: Item?
        if let predicate = predicate {
            if predicate(first) {
                object = getObject()
            }
        } else {
            object = getObject()
        }
        condition.unlock()
        return object
    }

    private func getObject() -> Item {
        let object = objects.removeFirst()
        if maxCount != Int.max, objects.count == maxCount >> 1 {
            condition.signal()
        }
//        if objects.isEmpty {
//            duration = 0
//            size = 0
//        } else {
//            duration = max(duration - object.duration, 0)
//            size = max(size - object.size, 0)
//        }
        return object
    }

    public func search(where predicate: (Item) -> Bool) -> Item? {
        condition.lock()
        defer {
            condition.unlock()
        }
        if objects.count > currentIndex {
            let item = objects[currentIndex]
            if predicate(item) {
                return item
            }
        }
        if let index = objects.firstIndex(where: predicate) {
            currentIndex = index
            return objects[index]
        } else {
            return nil
        }
    }

    public func forEach(_ body: (Item) -> Void) {
        condition.lock()
        defer {
            condition.unlock()
        }
        objects.forEach(body)
    }

    func flush() {
        condition.lock()
        objects.removeAll()
        currentIndex = 0
//        size = 0
//        duration = 0
        puttingObject = nil
        condition.signal()
        condition.unlock()
    }

    func shutdown() {
        destoryed = true
        flush()
    }
}

extension ObjectQueue {
    public var isEmpty: Bool {
        return count == 0
    }
}
