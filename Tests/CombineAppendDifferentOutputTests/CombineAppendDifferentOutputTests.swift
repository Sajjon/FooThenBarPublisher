import XCTest
import Combine

extension Publishers.IgnoreOutput where Upstream.Failure == Never {
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
    
    func test___function___first__ignoreOutput__flatMap_Empty__Append() throws {
        // GIVEN
        // Two publishers `foo` (🍌) and `bar` (🍏)
        let bananaSubject = PassthroughSubject<Banana, Never>()
        let appleSubject = PassthroughSubject<Apple, Never>()
        
        var outputtedFruits = [Fruit]()
        let expectation = XCTestExpectation(description: self.debugDescription)
        
        let applesAfterFirstBanana = bananaSubject.first().ignoreOutput().andThen(appleSubject)
        
        let cancellable = applesAfterFirstBanana.sink(
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
        XCTAssertEqual(outputtedFruits.count, expectedFruitCount)
        XCTAssertTrue(outputtedFruits.allSatisfy({ $0 is 🍏 }))
        let apples = outputtedFruits.compactMap { $0 as? 🍏 }
        XCTAssertEqual(apples.count, expectedFruitCount)
        let firstApple = try XCTUnwrap(apples.first)
        let lastApple = try XCTUnwrap(apples.last)
        XCTAssertEqual(firstApple.price, 3)
        XCTAssertEqual(lastApple.price, 5)
        XCTAssertNotNil(cancellable)
    }
    
    static var allTests = [
        ("test___function___first__ignoreOutput__flatMap_Empty__Append", test___function___first__ignoreOutput__flatMap_Empty__Append),
        
    ]
}

