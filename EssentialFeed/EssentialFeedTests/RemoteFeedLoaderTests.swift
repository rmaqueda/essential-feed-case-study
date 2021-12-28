import XCTest
import EssentialFeed

final class RemoteFeedLoaderTests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()

        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestDataFromURL() {
        let url = URL(string: "http://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_requestDataFromURLTwice() {
        let url = URL(string: "http://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        sut.load() { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    func test_load_deliversError_onClientError() {
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWith: .failure(.connectivity)) {
            let error = NSError(domain: "tests", code: 0)
            client.complete(with: error)
        }
    }
    
    func test_load_deliversError_onNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        let statusCodes = [199, 201, 300, 400]
        statusCodes.enumerated().forEach { index, code in
            expect(sut, toCompleteWith: .failure(.invalidData)) {
                let json = makeItemsJSON([])
                client.complete(withStatusCode: code, data: json, at: index)
            }
        }

    }
    
    func test_load_deliversError_On200HTTResponseWithInvalidaData() {
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWith: .failure(.invalidData)) {
            let invalidJSON = Data("invalid".utf8)
            client.complete(withStatusCode: 200, data: invalidJSON)
        }
    }
    
    func test_load_deliversNoItems_On200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()

        var capturedResults = [RemoteFeedLoader.Result]()
        sut.load(completion: { capturedResults.append($0) })
        
        let emptyListJSON = Data("{\"items\":[]}".utf8)
        client.complete(withStatusCode: 200, data: emptyListJSON)
        
        XCTAssertEqual(capturedResults, [.success([])])
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() {
        let (sut, client) = makeSUT()

        let item1 = makeItem(id: UUID(), imageURL: URL(string: "http//a-url.com")!)
        let item2 = makeItem(
            id: UUID(),
            description: "a description",
            location: "a location",
            imageURL: URL(string: "http//another-url.com")!)
        
        let models = [item1.model, item2.model]
        
        expect(sut, toCompleteWith: .success(models)) {
            let jsonData = makeItemsJSON([item1.json, item2.json])
            client.complete(withStatusCode: 200, data: jsonData)
        }
        
    }
    
    // Helpers
    
    private func makeSUT(url: URL = URL(string: "http://a-given-url.com")!) -> (RemoteFeedLoader, HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        return (sut, client)
    }
    
    private func makeItem(
        id: UUID,
        description: String? = nil,
        location: String? = nil ,
        imageURL: URL) -> (model: FeedItem, json: [String: Any]) {
            let item = FeedItem(id: id, description: description, location: location, imageURL: imageURL)
            let json = [
                "id": id.uuidString,
                "image": imageURL.absoluteString,
                "description": description,
                "location": location
            ].reduce(into: [String: Any]()) { (acc, e) in
                if let value = e.value {
                    acc[e.key] = value
                }
            }
            
            return (item, json)
    }
    
    private func makeItemsJSON(_ items: [[String: Any]]) -> Data {
        let itemsJSON = ["items": items]
        return try! JSONSerialization.data(withJSONObject: itemsJSON)
    }
    
    private func expect (
        _ sut: RemoteFeedLoader,
        toCompleteWith result: RemoteFeedLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var capturedResults = [RemoteFeedLoader.Result]()
        sut.load() { capturedResults.append($0) }
        
        action()
        
        XCTAssertEqual(capturedResults, [result], file: file, line: line)
    }
    
    private class HTTPClientSpy: HTTPClient {
        var requestedURLs: [URL ] {
            messages.map { $0.url }
        }
        var messages = [(url: URL, completion:(HTTPClientResult) -> Void)]()
        
        func load(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(url: requestedURLs[index],
                                           statusCode: code,
                                           httpVersion: nil,
                                           headerFields: nil)!
            messages[index].completion(.success(data, response))
        }
    }
    
}

class HTTPClientMock {
    var load: (URL) -> HTTPClientResult = { url in
            .success(
                Data(),
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
    }
}
