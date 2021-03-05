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
        let object = array?.popLast() as? P ?? initFunc()
        pool[key] = array
        semaphore.signal()
        return object
    }

    func comeback<P: Any>(item: P, key: String) {
        semaphore.wait()
        var array = pool[key, default: ContiguousArray<Any>()]
        array.append(item)
        pool[key] = array
        semaphore.signal()
    }

    func removeAll() {
        semaphore.wait()
        pool.removeAll()
        semaphore.signal()
    }

    func removeValue(forKey: String) {
        semaphore.wait()
        for key in pool.keys.filter({ $0.hasPrefix(forKey) }) {
            pool.removeValue(forKey: key)
        }
        semaphore.signal()
    }
}
