import XCTest
import Combine

func first__ignoreOutput__flatMap_Empty__Append<P, Q>(fooPublisher: P, barPublisher: Q) -> AnyPublisher<P.Output, Never>
    where P: Publisher, Q: Publisher,
    P.Output == Q.Output,
    P.Failure == Never,
    Q.Failure == Never
{

    return fooPublisher
        .first()
        .ignoreOutput()
        .flatMap { _ in Empty<P.Output, Never>() }
        .append(barPublisher)
        .eraseToAnyPublisher()
}


func first__filter_excludeAll__append<P, Q>(fooPublisher: P, barPublisher: Q) -> AnyPublisher<P.Output, Never>
    where P: Publisher, Q: Publisher,
    P.Output == Q.Output,
    P.Failure == Never,
    Q.Failure == Never
{
    
    return fooPublisher
            .first()
            .filter { _ in false } // drop all outputs
            .append(barPublisher)
            .eraseToAnyPublisher()
    
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

typealias FruitPublisher = AnyPublisher<Fruit, Never>
typealias FooThenBar = (FruitPublisher, FruitPublisher) -> FruitPublisher


final class CombineAppendDifferentOutputTests: XCTestCase {
    
    func test___function___first__ignoreOutput__flatMap_Empty__Append() throws {
        try doTest(first__ignoreOutput__flatMap_Empty__Append)
    }
    
    func test___function____first__filter_excludeAll__append() throws {
        try doTest(first__filter_excludeAll__append)
    }
    
    static var allTests = [
        ("test___function___first__ignoreOutput__flatMap_Empty__Append", test___function___first__ignoreOutput__flatMap_Empty__Append),
        ("test___function____first__filter_excludeAll__append", test___function____first__filter_excludeAll__append),
        
    ]
}

private extension CombineAppendDifferentOutputTests {
    
    func doTest(_ fooThenBarMethod: FooThenBar) throws {
        // GIVEN
        // Two publishers `foo` (🍌) and `bar` (🍏)
        let bananaSubject = PassthroughSubject<Banana, Never>()
        let appleSubject = PassthroughSubject<Apple, Never>()
        
        var outputtedFruits = [Fruit]()
        let expectation = XCTestExpectation(description: self.debugDescription)
        
        let cancellable = fooThenBarMethod(
            bananaSubject.map { $0 as Fruit }.eraseToAnyPublisher(),
            appleSubject.map { $0 as Fruit }.eraseToAnyPublisher()
        )
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { outputtedFruits.append($0) }
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
}
