import Foundation

/// Interprets data made up of a set of raw values.
public final class DataParser {

    public enum Error: Swift.Error {
        case outOfBounds
    }

    public private(set) var currentIndex: Int

    let data: Data

    public init(data: Data) {
        self.data = data
        self.currentIndex = data.startIndex
    }

    public func checkValue<T: Equatable>(expect: T) throws -> Bool {
        let x = try parseData(ofType: T.self)
        return x == expect
    }
    public func checkValue<T: Equatable>(expect: Array<T>) throws -> Bool {
        let x = try parseData(ofType: T.self, count: expect.count)
        return x == expect
    }

    public func parseData<T>(ofType type: T.Type, count: Int) throws -> Array<T> {
        var temp = Array<T>()
        for _ in 0..<count {
            let x = try parseData(ofType: type)
            temp.append(x)
        }
        return temp
    }
    public func parseData<T>(ofType: T.Type) throws -> T {
        let storageSize = MemoryLayout<T>.stride
        let endIndex = currentIndex + storageSize
        if endIndex <= data.endIndex {
            let temp = Data(data[currentIndex..<endIndex])
            currentIndex = endIndex
            return withUnsafePointer(to: temp) { pointer in
                pointer.withMemoryRebound(to: T.self, capacity: 1) {
                    return $0.pointee
                }
            }
        }
        throw Error.outOfBounds
    }
}