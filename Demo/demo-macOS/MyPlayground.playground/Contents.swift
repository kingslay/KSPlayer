import Foundation
// 初始化
var pointer = UnsafeMutablePointer<UInt16>.allocate(capacity: 8)
pointer.initialize(repeating: 11, count: 8)
var rawPointer = UnsafeMutableRawPointer(pointer)
// 移动指针
// UnsafeRawPointer是以一个直接为单位来移动，UnsafePointer<Type>是以MemoryLayout<Type>.stride为单位来移动
pointer.advanced(by: 1)
pointer + 1
pointer += 1
rawPointer.advanced(by: 1)
rawPointer + 1
rawPointer += 1
// 取值
pointer.pointee
pointer[0]
rawPointer.load(as: UInt8.self)
rawPointer.load(fromByteOffset: 1, as: UInt8.self)
// 赋值
pointer.pointee = 12
pointer[1] = 12
rawPointer.storeBytes(of: 13, as: UInt8.self)
rawPointer.storeBytes(of: 14, toByteOffset: 1, as: UInt8.self)
// 批量赋值
var newPointer = UnsafeMutablePointer<UInt16>.allocate(capacity: 8)
newPointer.initialize(repeating: 1, count: 8)
pointer.assign(from: newPointer, count: 8)
rawPointer.copyMemory(from: newPointer, byteCount: 16)
memcpy(pointer, newPointer, 16)
memcpy(rawPointer, newPointer, 16)
// 类型转换
// OpaquePointer <-> UnsafeRawPointer
// OpaquePointer <-> UnsafePointer<Type>
// OpaquePointer <-> UnsafeMutableRawPointer
// OpaquePointer <-> UnsafeMutablePointer<Type>
//
// UnsafeRawPointer <-> UnsafeMutableRawPointer
// UnsafePointer<Type> <-> UnsafeMutablePointer<Type>
// UnsafePointer<Type> -> UnsafeRawPointer
// UnsafePointer<Type> -> UnsafeMutableRawPointer
// UnsafeMutablePointer<Type> -> UnsafeRawPointer
// UnsafeMutablePointer<Type> -> UnsafeMutableRawPointer

// UnsafeMutableRawPointer -> UnsafeMutablePointer<Type>
var uInt16Point = rawPointer.assumingMemoryBound(to: UInt16.self)
// UnsafeMutablePointer<Type1> <-> UnsafeMutablePointer<Type2>
let int32Pointer = pointer.withMemoryRebound(to: Int32.self, capacity: 1) { $0 }

// SwiftType <-> UnsafeMutableRawPointer
import AVFoundation
var player = AVPlayer()
let playerRawPointer = Unmanaged.passUnretained(player).toOpaque()
player = Unmanaged<AVPlayer>.fromOpaque(playerRawPointer).takeUnretainedValue()
// SwiftType <-> UnsafePointer<Type>
var test1 = 10
var test2 = withUnsafePointer(to: test1) { ptr -> Int in
    let mutaPoint = UnsafeMutablePointer(mutating: ptr)
    mutaPoint.pointee = 13
    return ptr.pointee + 1
}

test1
test2
// SwiftType <-> UnsafeMutablePointer<Type>
var test3 = 10
var test4 = withUnsafeMutablePointer(to: &test3) { ptr -> Int in
    ptr.pointee += 1
    return ptr.pointee
}

test3
test4
// 注销
pointer -= 1
pointer.deinitialize(count: 8)
pointer.deallocate()
rawPointer -= 1
// rawPointer.deallocate()
func pointerFunc(i: UnsafePointer<Int>) -> Int {
    i.pointee + 1
}

var test5 = 1
pointerFunc(i: &test5)
[1, 2, 3].withUnsafeBufferPointer { pointer in
    print(pointer.baseAddress!) // 得到 UnsafePointer<Int> 对象
    print(pointer.first!) // 得到起始地址指向的 Int 对象
}

var array = [4, 5, 6]
array.withUnsafeMutableBufferPointer { pointer in
    print(pointer.baseAddress!) // 得到 UnsafePointer<Int> 对象
    print(pointer.first!) // 得到起始地址指向的 Int 对象
}

var _buffer = ContiguousArray<Int?>(repeating: 1, count: 102_400)
var startTime = CACurrentMediaTime()
_buffer.removeAll(keepingCapacity: true)
_buffer.append(contentsOf: ContiguousArray<Int?>(repeating: nil, count: 102_400))
var diff = CACurrentMediaTime() - startTime
print(diff)
_buffer = ContiguousArray<Int?>(repeating: 1, count: 102_400)
startTime = CACurrentMediaTime()
(0 ..< _buffer.count).forEach { _buffer[$0] = nil }
diff = CACurrentMediaTime() - startTime
print(diff)
