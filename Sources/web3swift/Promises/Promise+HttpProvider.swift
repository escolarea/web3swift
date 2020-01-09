//  web3swift
//
//  Created by Alex Vlasov.
//  Copyright © 2018 Alex Vlasov. All rights reserved.
//

import Foundation
import PromiseKit

extension Web3HttpProvider {
    
    private static var promiseMapping: [URLSessionTask: (promise: Promise<Data>, resolver: Resolver<Data>)] = [:]
    var pendingPromises: [URLSessionTask: (promise: Promise<Data>, resolver: Resolver<Data>)] {
        get {return Web3HttpProvider.self.promiseMapping}
    }
    
    static func post(_ request: JSONRPCrequest, providerURL: URL, queue: DispatchQueue = .main, session: URLSession) -> Promise<JSONRPCresponse> {
        let rp = Promise<Data>.pending()
        var task: URLSessionTask? = nil
        queue.async {
            do {
                let encoder = JSONEncoder()
                let requestData = try encoder.encode(request)
                var urlRequest = URLRequest(url: providerURL, cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                urlRequest.httpBody = requestData
//                let debugValue = try JSONSerialization.jsonObject(with: requestData, options: JSONSerialization.ReadingOptions(rawValue: 0))
//                print(debugValue)
//                let debugString = String(data: requestData, encoding: .utf8)
//                print(debugString)
                task = session.dataTask(with: urlRequest){ (data, response, error) in
                    guard error == nil else {
                        rp.resolver.reject(error!)
                        return
                    }
                    guard data != nil else {
                        rp.resolver.reject(Web3Error.nodeError(desc: "Node response is empty"))
                        return
                    }
                    rp.resolver.fulfill(data!)
                }
                task?.resume()
                if let currentTask = task {
                    promiseMapping[currentTask] = rp
                }
            } catch {
                rp.resolver.reject(error)
            }
        }
        return rp.promise.ensure(on: queue) {
                task = nil
            }.map(on: queue){ (data: Data) throws -> JSONRPCresponse in
                let parsedResponse = try JSONDecoder().decode(JSONRPCresponse.self, from: data)
                if parsedResponse.error != nil {
                    throw Web3Error.nodeError(desc: "Received an error message from node\n" + String(describing: parsedResponse.error!))
                }
                return parsedResponse
            }
        }
    
    static func post(_ request: JSONRPCrequestBatch, providerURL: URL, queue: DispatchQueue = .main, session: URLSession) -> Promise<JSONRPCresponseBatch> {
        let rp = Promise<Data>.pending()
        var task: URLSessionTask? = nil
        queue.async {
            do {
                let encoder = JSONEncoder()
                let requestData = try encoder.encode(request)
                var urlRequest = URLRequest(url: providerURL, cachePolicy: URLRequest.CachePolicy.reloadIgnoringCacheData)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                urlRequest.httpBody = requestData
//                let debugValue = try JSONSerialization.jsonObject(with: requestData, options: JSONSerialization.ReadingOptions(rawValue: 0))
//                print(debugValue)
//                let debugString = String(data: requestData, encoding: .utf8)
//                print(debugString)
                task = session.dataTask(with: urlRequest){ (data, response, error) in
                    guard error == nil else {
                        rp.resolver.reject(error!)
                        return
                    }
                    guard data != nil, data!.count != 0 else {
                        rp.resolver.reject(Web3Error.nodeError(desc: "Node response is empty"))
                        return
                    }
                    rp.resolver.fulfill(data!)
                }
                task?.resume()
                if let currentTask = task {
                    promiseMapping[currentTask] = rp
                }
            } catch {
                rp.resolver.reject(error)
            }
        }
        return rp.promise.ensure(on: queue) {
            task = nil
            }.map(on: queue){ (data: Data) throws -> JSONRPCresponseBatch in
//                let debugValue = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
//                print(debugValue)
                let parsedResponse = try JSONDecoder().decode(JSONRPCresponseBatch.self, from: data)
                return parsedResponse
        }
    }
    
    public func rejectPromise(for task: URLSessionTask, with errorDescription:String? = nil) {
        guard let promise = self.pendingPromises[task] else { return }
        promise.resolver.reject(Web3Error.securityError(desc: errorDescription ?? "Promise Rejected From Delegate"))
        task.cancel()
    }
    
    public func sendAsync(_ request: JSONRPCrequest, queue: DispatchQueue = .main) -> Promise<JSONRPCresponse> {
        if request.method == nil {
            return Promise(error: Web3Error.nodeError(desc: "RPC method is nill"))
        }
        
        return Web3HttpProvider.post(request, providerURL: self.url, queue: queue, session: self.session)
    }
    
    public func sendAsync(_ requests: JSONRPCrequestBatch, queue: DispatchQueue = .main) -> Promise<JSONRPCresponseBatch> {
        return Web3HttpProvider.post(requests, providerURL: self.url, queue: queue, session: self.session)
    }
}

