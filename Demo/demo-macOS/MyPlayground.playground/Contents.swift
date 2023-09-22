import QuartzCore

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
let ass = #"{\alpha&H00&\t(1700,2000,\alpha&HFF&)\blur1\fsp1\fn方正兰亭特黑长_GBK\fs13\frz1.33\c&H312A17&\b1\t(65,1982,\blur4.5)\pos(142.51,66.32)}拉斯维加斯 城{\fsp0}界"#
let styleArr = ass.components(separatedBy: CharacterSet(charactersIn: "{}"))
print(styleArr)
