//
//  ObjectQueue.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/9.
//

import Foundation

public class CircularBuffer<Item: ObjectQueueItem> {
    private var _buffer = ContiguousArray<Item?>()
//    private let semaphore = DispatchSemaphore(value: 0)
    private let condition = NSCondition()
    private var headIndex = UInt(0)
    private var tailIndex = UInt(0)
    private let expanding: Bool
    private let sorted: Bool
    private var destoryed = false
    @inline(__always) private var _count: Int { Int(tailIndex &- headIndex) }
    public var count: Int {
        condition.lock()
        defer { condition.unlock() }
        return _count
    }
    public var maxCount: Int
    private var mask: UInt

    public init(initialCapacity: Int = 256, sorted: Bool = false, expanding: Bool = true) {
        self.expanding = expanding
        self.sorted = sorted
        let capacity = initialCapacity.nextPowerOf2()
        self._buffer = ContiguousArray<Item?>(repeating: nil, count: capacity)
        maxCount = capacity
        mask = UInt(maxCount - 1)
        assert(_buffer.count == capacity)
    }

    public func append(_ value: Item) {
        condition.lock()
        defer { condition.unlock() }
        if destoryed {
            return
        }
        let currenIndex = Int(tailIndex & mask)
        _buffer[currenIndex] = value
        if sorted {
            // 不用sort进行排序，这个比较高效
            var index = tailIndex
            while index > headIndex {
                guard let item = _buffer[Int((index - 1) & mask)] else {
                    assertionFailure("value is nil of index: \((index - 1) & mask) headIndex: \(headIndex), tailIndex: \(tailIndex)")
                    break
                }
                if item.position < value.position {
                    break
                }
                index -= 1
            }
            if tailIndex != index {
                _buffer.swapAt(Int(index & mask), currenIndex)
            }
        }
        tailIndex &+= 1
        if _count == maxCount {
            if expanding {
                // No more room left for another append so grow the buffer now.
                _doubleCapacity()
            } else {
                condition.wait()
            }
        } else {
            // 只有数据了。就signal。因为有可能这是最后的数据了。
            if _count == 1 {
                condition.signal()
            }
        }
    }
    public func first(sync: Bool = false, where predicate: ((Item) -> Bool)? = nil) -> Item? {
        condition.lock()
        defer { condition.unlock() }
        if destoryed {
            return nil
        }
        if headIndex == tailIndex {
            if sync {
                condition.wait()
                if destoryed || headIndex == tailIndex {
                    return nil
                }
            } else {
                return nil
            }
        }
        let index = Int(headIndex & mask)
        guard let item = _buffer[index] else {
            assertionFailure("value is nil of index: \(index) headIndex: \(headIndex), tailIndex: \(tailIndex)")
            return nil
        }
        if let predicate = predicate, !predicate(item) {
            return nil
        } else {
            headIndex &+= 1
            _buffer[index] = nil
            if _count == maxCount >> 1 {
                condition.signal()
            }
            return item
        }
    }
    public func search(where predicate: (Item) -> Bool) -> Item? {
        condition.lock()
        defer { condition.unlock() }
        for i in (headIndex..<tailIndex) {
            if let item = _buffer[Int(i)] {
                if predicate(item) {
                    headIndex = i
                    return item
                }
            } else {
                assertionFailure("value is nil of index: \(i) headIndex: \(headIndex), tailIndex: \(tailIndex)")
                return nil
            }
        }
        return nil
    }
    public func flush() {
        condition.lock()
        defer { condition.unlock() }
        headIndex = 0
        tailIndex = 0
        (0..<maxCount).forEach { _buffer[$0] = nil }
        condition.signal()
    }

    public func shutdown() {
        destoryed = true
        flush()
    }

    private func _doubleCapacity() {
        var newBacking: ContiguousArray<Item?> = []
        let newCapacity = maxCount << 1 // Double the storage.
        precondition(newCapacity > 0, "Can't double capacity of \(_buffer.count)")
        assert(newCapacity % 2 == 0)
        newBacking.reserveCapacity(newCapacity)
        let head = Int(headIndex & mask)
        newBacking.append(contentsOf: _buffer[head..<maxCount])
        if head > 0 {
            newBacking.append(contentsOf: _buffer[0..<head])
        }
        let repeatitionCount = newCapacity &- newBacking.count
        newBacking.append(contentsOf: repeatElement(nil, count: repeatitionCount))
        headIndex = 0
        tailIndex = UInt(newBacking.count &- repeatitionCount)
        _buffer = newBacking
        maxCount = newCapacity
        mask = UInt(maxCount - 1)
    }
}
extension FixedWidthInteger {
    /// Returns the next power of two.
    @inline(__always) func nextPowerOf2() -> Self {
        guard self != 0 else {
            return 1
        }
        return 1 << (Self.bitWidth - (self - 1).leadingZeroBitCount)
    }
}
