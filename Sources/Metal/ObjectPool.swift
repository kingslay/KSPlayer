//
//  bjectPool.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import Foundation
class ObjectPool {
    private let semaphore = DispatchSemaphore(value: 1)
    private var pool = [String: ContiguousArray<Any>]()
    static let share = ObjectPool()
    private init() {}

    func object<P: Any>(class _: P.Type, key: String, initFunc: () -> P) -> P {
        semaphore.wait()
        var array = pool[key]
        var object = array?.last as? P
        if object != nil {
            array?.removeLast()
            pool[key] = array
        } else {
            object = initFunc()
        }
        semaphore.signal()
        return object!
    }

    func comeback<P: Any>(item: P, key: String) {
        semaphore.wait()
        if var array = pool[key] {
            array.append(item)
            pool[key] = array
        } else {
            var array = ContiguousArray<Any>()
            array.append(item)
            pool[key] = array
        }
        semaphore.signal()
    }

    func removeAll() {
        semaphore.wait()
        pool.removeAll()
        semaphore.signal()
    }

    func removeValue(forKey: String) {
        semaphore.wait()
        pool.keys.filter { $0.hasPrefix(forKey) }.forEach { key in
            pool.removeValue(forKey: key)
        }
        semaphore.signal()
    }
}
