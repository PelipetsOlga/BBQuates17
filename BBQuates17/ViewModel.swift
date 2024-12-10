//
//  ViewModel.swift
//  BBQuates17
//
//  Created by Olha Pelypets on 08/12/2024.
//

import Foundation

@Observable
class ViewModel {
    enum FetchStatus {
        case notStarted
        case fetching
        case success
        case failed(error: Error)
    }

    private(set) var status: FetchStatus = .notStarted
    
    private let fetcher = FetchService()
    
    var quote: Quote
    var character: Character
    
    init(){
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let quoteData = try! Data(
            contentsOf: Bundle.main.url(forResource: "samplequote", withExtension: "json")!
        )
        quote = try! decoder.decode(Quote.self, from: quoteData)
        
        let characterData = try! Data(
            contentsOf: Bundle.main.url(forResource: "samplecharacter", withExtension: "json")!
        )
        character = try! decoder.decode(Character.self, from: characterData)
    }
    
    func getData(for show: String) async {
        print ("get Data fetching")
        status = .fetching
        
        do {
            quote = try await fetcher.fetchQuote(from: show)
            print ("get Data quote=\(quote)")
            
            character = try await fetcher.fetchCharacter(quote.character)
            print ("get Data character=\(character)")
            
            character.death = try await fetcher.fetchDeath(for: character.name)
//            print ("get Data death=\(character.death)")
            
            status = .success
            print ("get Data success")
        } catch {
            print ("get Data error")
            status = .failed(error: error)
        }
    }
}