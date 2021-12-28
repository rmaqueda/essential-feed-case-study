//
//  RemoteFeedLoader.swift
//  EssentialFeed
//
//  Created by Maqueda, Ricardo Javier on 24/12/21.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation

public enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

public protocol HTTPClient {
    func load(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}

public final class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public enum Result: Equatable {
        case success([FeedItem])
        case failure(Error)
    }
    
    private struct RootItems: Decodable {
        let items: [FeedItem]
    }

    public init(url: URL, client: HTTPClient) {
        self.client = client
        self.url = url
    }
    
    public func load(completion: @escaping (Result) -> Void) {
        client.load(from: url) { result in
            switch result {
            case let .success(data, response):
                if response.statusCode == 200,
                   let items = try? JSONDecoder().decode(RootItems.self, from: data) {
                    completion(.success(items.items))
                } else {
                    completion(.failure(.invalidData))
                }
            case .failure:
                completion(.failure(.connectivity))
            }
        }
    }
}
