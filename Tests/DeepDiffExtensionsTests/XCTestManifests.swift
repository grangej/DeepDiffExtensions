import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DeepDiffExtensionsTests.allTests),
    ]
}
#endif
