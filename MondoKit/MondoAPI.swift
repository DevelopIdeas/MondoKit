//
//  MondoAPI.swift
//  MondoKit
//
//  Created by Mike Pollard on 21/01/2016.
//  Copyright © 2016 Mike Pollard. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON


internal struct AuthData {
    
    let createdAt = NSDate()
    let userId : String
    let accessToken : String
    let expiresIn : Int
    let refreshToken : String?
    var expiresAt : NSDate {
        return createdAt.dateByAddingTimeInterval(NSTimeInterval(expiresIn))
    }
}

/**
 A Swift wrapper around the Mondo API at https://api.getmondo.co.uk/
 
 This is a singleton, use `MondAPI.instance` to play with it and call `MondAPI.instance.initialiseWithClientId(:clientSecret)`
 before you do anything else.
 
 Once you've done that grab a `UIViewController` using `newAuthViewController` and present it to allow user authentication.
 
 Then go ahead and play with:
 
 - `listAccounts`
 - `getBalanceForAccount`
 - `listTransactionsForAccount`
 
 */
public class MondoAPI {
    
    internal static let APIRoot = "https://api.getmondo.co.uk/"
    
    /// The only one you'll ever need!
    public static let instance = MondoAPI()
    
    internal var clientId : String?
    internal var clientSecret : String?
    
    internal var authData : AuthData?
    
    private var initialised : Bool {
        
        return clientId != nil && clientSecret != nil
    }
    
    private init() { }
    
    /**
     Initializes the MondoAPI instance with the specified clientId & clientSecret.
     
     You need to do this before using the MondAPI.
     
     ie call `MondAPI.instance.initialiseWithClientId(:clientSecret)` in `applicationDidFinishLaunchingWithOptions`
     
     */
    public func initialiseWithClientId(clientId : String, clientSecret : String) {
        
        assert(!initialised, "MondoAPI.instance already initialised!")
        
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
    
    /**
     Creates and returns a `UIViewController` that manages authentication with Mondo.
     
     Present this and wait for the callback.
     
     - parameter onCompletion:     The callback closure called to let you know how the authentication went.
     */
    public func newAuthViewController(onCompletion completion : (success : Bool, error : ErrorType?) -> Void) -> UIViewController {
        
        assert(initialised, "MondoAPI.instance not initialised!")
        
        return OAuthViewController(mondoApi: self, onCompletion: completion)
    }
    
    // MARK: Pagination
    
    /**
    A struct to encapsulte the Pagination parameters used by the Mondo API for cursor based pagination.
    */
    public struct Pagination {
        
        public enum Constraint {
            case Date(NSDate)
            case Id(String)
            
            private var headerValue : String {
                switch self {
                case .Date(let date):
                    return date.toJsonDateTime
                case .Id(let id):
                    return id
                }
            }
        }
        
        let limit : Int?
        let since : Constraint?
        let before : NSDate?
        
        public init(limit: Int? = nil, since: Constraint? = nil, before: NSDate?) {
            self.limit = limit
            self.since = since
            self.before = before
        }
        
        private var parameters : [String : String] {
            var parameters = [String:String]()
            if let limit = limit {
                parameters["limit"] = String(limit)
            }
            if let since = since {
                parameters["since"] = since.headerValue
            }
            if let before = before {
                parameters["before"] = before.toJsonDateTime
            }
            return parameters
        }
    }
    
    
    // MARK: internal and private helpers
    
    internal func dispatchCompletion(completion: ()->Void) {
        
        dispatch_async(dispatch_get_main_queue(), completion)
    }
    
    private func errorFromResponse(response: Alamofire.Response<AnyObject, NSError>) -> NSError {
        
        switch response.result {
            
        case .Success(let value):
            
            let json = JSON(value)
            let message = json["message"].string
            return NSError(domain: "MondoAPI", code: response.response?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey:message ?? ""])
            
        case .Failure(let error):
            return error
        }
    }
}

// MARK: listAccounts

extension MondoAPI {
    
    /**
     Calls https://api.getmondo.co.uk/accounts and calls the completion closure with
     either an `[MondoAccount]` or an `ErrorType`
     
     - parameter completion:
    */
    public func listAccounts(completion: (mondoAccounts: [MondoAccount]?, error: ErrorType?) -> Void) {
        
        assert(initialised, "MondoAPI.instance not initialised!")
        
        if let authData = authData {
            
            Alamofire.request(.GET, MondoAPI.APIRoot+"accounts", headers: ["Authorization":"Bearer " + authData.accessToken]).responseJSON { response in
                
                var mondoAccounts : [MondoAccount]?
                var anyError : ErrorType?
                
                defer {
                    self.dispatchCompletion() {
                        completion(mondoAccounts: mondoAccounts, error: anyError)
                    }
                }
                
                guard let status = response.response?.statusCode where status == 200 else {
                    
                    debugPrint(response)
                    anyError = self.errorFromResponse(response)
                    return
                }
                
                switch response.result {
                    
                case .Success(let value):
                    
                    debugPrint(value)
                    
                    mondoAccounts = [MondoAccount]()
                    
                    let json = JSON(value)
                    if let accounts = json["accounts"].array {
                        for accountJson in accounts {
                            do {
                                let mondoAccount = try MondoAccount(json: accountJson)
                                mondoAccounts!.append(mondoAccount)
                            }
                            catch {
                                debugPrint("Could not create MondoAccount from \(accountJson) \n Error: \(error)")
                            }
                        }
                    }
                    
                case .Failure(let error):
                    
                    debugPrint(error)
                }
            }
        }
    }
}

// MARK: getBalanceForAccount

extension MondoAPI {
    
    /**
     Calls https://api.getmondo.co.uk/balance and calls the completion closure with
     either an `MondoAccountBalance` or an `ErrorType`
     
     - parameter account:       an account from which to get the accountId
     - parameter completion:
     */
    public func getBalanceForAccount(account: MondoAccount, completion: (balance: MondoAccountBalance?, error: ErrorType?) -> Void) {
        
        assert(initialised, "MondoAPI.instance not initialised!")
        
        if let authData = authData {
            
            Alamofire.request(.GET, MondoAPI.APIRoot+"balance", parameters: ["account_id" : account.accountId], headers: ["Authorization":"Bearer " + authData.accessToken]).responseJSON { response in
                
                var balance : MondoAccountBalance?
                var anyError : ErrorType?
                
                defer {
                    self.dispatchCompletion() {
                        completion(balance: balance, error: anyError)
                    }
                }
                
                guard let status = response.response?.statusCode where status == 200 else {
                    
                    debugPrint(response)
                    anyError = self.errorFromResponse(response)
                    return
                }
                
                switch response.result {
                    
                case .Success(let value):
                    debugPrint(value)
                    
                    let json = JSON(value)
                    do {
                        balance = try MondoAccountBalance(json: json)
                    }
                    catch {
                        debugPrint("Could not create MondoAccountBalance from \(json) \n Error: \(error)")
                        anyError = error
                    }
                    
                case .Failure(let error):
                    debugPrint(error)
                }
            }
        }
    }
}

// MARK: listTransactionsForAccount

extension MondoAPI {
    
    /**
     Calls https://api.getmondo.co.uk/transactions and calls the completion closure with
     either an `[MondoTransaction]` or an `ErrorType`
     
     - parameter account:       an account from which to get the accountId
     - parameter expand:        what to pass as expand[] parameter. eg. merchant. `nil` by default.
     - parameter pagination:    the pagination parameters. `nil` by default.
     - parameter completion:
     */
    public func listTransactionsForAccount(account: MondoAccount, expand: String? = nil, pagination: Pagination? = nil, completion: (transactions: [MondoTransaction]?, error: ErrorType?) -> Void) {
        
        assert(initialised, "MondoAPI.instance not initialised!")
        
        if let authData = authData {
            
            var parameters = ["account_id" : account.accountId]
            if let expand = expand {
                parameters["expand[]"] = expand
            }
            
            if let pagination = pagination {
                pagination.parameters.forEach { parameters.updateValue($1, forKey: $0) }
            }
            
            Alamofire.request(.GET, MondoAPI.APIRoot+"transactions", parameters: parameters, headers: ["Authorization":"Bearer " + authData.accessToken]).responseJSON { response in
                
                var transactions : [MondoTransaction]?
                var anyError : ErrorType?
                
                defer {
                    self.dispatchCompletion() {
                        completion(transactions: transactions, error: anyError)
                    }
                }
                
                guard let status = response.response?.statusCode where status == 200 else {
                    
                    debugPrint(response)
                    anyError = self.errorFromResponse(response)
                    return
                }
                
                switch response.result {
                    
                case .Success(let value):
                    debugPrint(value)
                    
                    let json = JSON(value)
                    do {
                        transactions = try json["transactions"].decodeAsArray()
                    }
                    catch {
                        debugPrint("Could not create MondoTransactions from \(json) \n Error: \(error)")
                        anyError = error
                    }
                    
                case .Failure(let error):
                    debugPrint(error)
                    anyError = error
                }
            }
        }
    }
}