import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CombineAppendDifferentOutputTests.allTests),
    ]
}
#endif
