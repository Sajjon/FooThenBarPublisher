import XCTest
import Combine

protocol BaseForAndThen {}
extension Publishers.IgnoreOutput: BaseForAndThen {}
extension Combine.Future: BaseForAndThen {}

extension Publisher where Self: BaseForAndThen, Self.Failure == Never {
    func andThen<Then>(_ thenPublisher: Then) -> AnyPublisher<Then.Output, Never> where Then: Publisher, Then.Failure == Failure {
        return
            flatMap { _ in Empty<Then.Output, Never>(completeImmediately: true) } // same as `init()`
                .append(thenPublisher)
                .eraseToAnyPublisher()
    }
}

protocol Fruit {
    var price: Int { get }
}

typealias 🍌 = Banana
struct Banana: Fruit {
    let price: Int
}

typealias 🍏 = Apple
struct Apple: Fruit {
    let price: Int
}

final class CombineAppendDifferentOutputTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    func testFirst() throws {
        try doTest { bananaPublisher, applePublisher in
            bananaPublisher.first().ignoreOutput().andThen(applePublisher)
        }
    }
    
    func testFuture() throws {
        var cancellable: Cancellable?
        try doTest { bananaPublisher, applePublisher in
            
            let futureBanana = Future<🍌, Never> { promise in
                cancellable = bananaPublisher.sink(
                    receiveCompletion: { _ in },
                    receiveValue: { value in promise(.success(value)) }
                )
            }
            
            return futureBanana.andThen(applePublisher)
        }
        
        XCTAssertNotNil(cancellable)
    }
    
    static var allTests = [
        ("testFirst", testFirst),
        ("testFuture", testFuture),
        
    ]
}

private extension CombineAppendDifferentOutputTests {
    
    func doTest(_ line: UInt = #line, _ fooThenBarMethod: (AnyPublisher<🍌, Never>, AnyPublisher<🍏, Never>) -> AnyPublisher<🍏, Never>) throws {
        // GIVEN
        // Two publishers `foo` (🍌) and `bar` (🍏)
        let bananaSubject = PassthroughSubject<Banana, Never>()
        let appleSubject = PassthroughSubject<Apple, Never>()
        
        var outputtedFruits = [Fruit]()
        let expectation = XCTestExpectation(description: self.debugDescription)
        
        let cancellable = fooThenBarMethod(
            bananaSubject.eraseToAnyPublisher(),
            appleSubject.eraseToAnyPublisher()
            )
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { outputtedFruits.append($0 as Fruit) }
        )
        
        // WHEN
        // a send apples and bananas to the respective subjects and a `finish` completion to `appleSubject` (`bar`)
        appleSubject.send(🍏(price: 1))
        bananaSubject.send(🍌(price: 2))
        appleSubject.send(🍏(price: 3))
        bananaSubject.send(🍌(price: 4))
        appleSubject.send(🍏(price: 5))
        
        appleSubject.send(completion: .finished)
        
        wait(for: [expectation], timeout: 0.1)
        
        // THEN
        // A: I the output contains no banana (since the bananaSubject publisher's output is ignored)
        // and
        // B: Exactly two apples, more specifically the two last, since when the first Apple (with price 1) is sent, we have not yet received the first (needed and triggering) banana.
        let expectedFruitCount = 2
        XCTAssertEqual(outputtedFruits.count, expectedFruitCount, line: line)
        XCTAssertTrue(outputtedFruits.allSatisfy({ $0 is 🍏 }), line: line)
        let apples = outputtedFruits.compactMap { $0 as? 🍏 }
        XCTAssertEqual(apples.count, expectedFruitCount, line: line)
        let firstApple = try XCTUnwrap(apples.first)
        let lastApple = try XCTUnwrap(apples.last)
        XCTAssertEqual(firstApple.price, 3, line: line)
        XCTAssertEqual(lastApple.price, 5, line: line)
        XCTAssertNotNil(cancellable, line: line)
    }
}
