//
//  main.swift
//  TextParser
//
//  Created by Rahan Benabid on 25/6/2024.
//

import Foundation
import NaturalLanguage
import ArgumentParser

@main
struct App: ParsableCommand {
    
    @Argument(help: "The text you want to analyze")
    var input: [String]
    
    @Option(help: "The maximum number of alternatives to suggest")
    var maximumAlternatives = 10
    
    @Option(help: "The distance of our words, better be around 0.9")
    var farAway = 0.8
    
    // Set our flags
    @Flag(name: .shortAndLong, help: "Show detected language.")
    var detectLanguage = false
    
    @Flag(name: .shortAndLong, help: "Print how positive or negative the input is.")
    var sentimentAnalysis = false
    
    @Flag(name: .shortAndLong, help: "Show the stem form of each word in the input.")
    var lemmatize = false
    
    @Flag(name: .shortAndLong, help: "Show the alternative words for each word in the input.")
    var alternatives = false
    
    @Flag(name: .shortAndLong, help: "Print names of people, places, and organizations in the input.")
    var names = false
    
    @Flag(name: .shortAndLong, help: "Detect only the names in the input.")
    var mame = false
    
    @Flag(name: .shortAndLong, help: "Detect only the places in the input.")
    var place = false
    
    @Flag(name: .shortAndLong, help: "Detect only the organizations in the input.")
    var organization = false
    
    @Flag(name: .shortAndLong, help: "Enables all the flags.")
    var everything = false
    
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "analyse", abstract: "Analyses input text using a range of natural language approaches.")
    }
    
    var text: String {
        input.joined(separator: " ")
    }
    
    mutating func run() {
        if everything {
            detectLanguage = true
            sentimentAnalysis = true
            lemmatize = true
            alternatives = true
            names = true
            mame = true
            organization = true
            place = true
        }
        
        print()
        print(text)
        
        // Detect language
        if detectLanguage {
            let language = NLLanguageRecognizer.dominantLanguage(for: text) ?? .undetermined
            print()
            print("Detected language: \(language.rawValue)")
        }
        
        // Sentiment analysis
        if sentimentAnalysis  {
            print()
            let sentiment = sentiment(for: text)
            print("Sentiment analysis: \(sentiment)")
        }
        
        // Lemmatization
        if lemmatize {
            let lemmas = lemmatize(string: text)
            print()
            print("Found the following lemma:")
            print("\t", lemmas.formatted(.list(type: .and)))
        }
        
        // Alternative words
        if alternatives {
            print()
            print("Found the following alternatives:")
            let lemmas = lemmatize(string: text)
            for word in lemmas {
                let embeddingResults = embedding(for: word)
                print("\n", embeddingResults.formatted(.list(type: .and)))
            }
        }
        
        // Named entity recognition
        if names || place || mame || organization {
            let entities = entities(for: text)
            print()
            print("Found the following entities:")
            for entity in entities {
                print("\t", entity)
            }
        }
    }
    
    func sentiment(for string: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = string
        let (sentiment, _) = tagger.tag(at: string.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }
    
    func embedding(for word: String) -> [String] {
        var results = [String]()
        let language = NLLanguageRecognizer.dominantLanguage(for: text) ?? .undetermined
        
        if let embedding = NLEmbedding.wordEmbedding(for: language) {
            let similarWords = embedding.neighbors(for: word, maximumCount: maximumAlternatives)
            
            results.append("\nSimilar words to '\(word)':")
            
            for (similarWord, similarityScore) in similarWords {
                if similarityScore > farAway {
                    results.append("\n\t- \(similarWord) (Similarity: \(similarityScore))")
                }
            }
        } else {
            results.append("No embedding found for the word '\(word)'.")
        }
        
        return results
    }
    
    func lemmatize(string: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = string
        
        var results = [String]()
        
        tagger.enumerateTags(in: string.startIndex..<string.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let stemForm = tag?.rawValue ?? String(string[range]).trimmingCharacters(in: .whitespaces)
            
            if !stemForm.isEmpty {
                results.append(stemForm)
            }
            
            return true
        }
        return results
    }
    
    func entities(for string: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = string
        var results = [String]()
        
        tagger.enumerateTags(in: string.startIndex..<string.endIndex, unit: .word, scheme: .nameType, options: .joinNames) { tag, range in
            guard let tag = tag else { return true }
            
            let match = String(string[range])
            
            switch tag {
            case .organizationName:
                if organization { results.append("Organization: \(match)") }
            case .personalName:
                if mame { results.append("Person: \(match)") }
            case .placeName:
                if place { results.append("Place: \(match)") }
            default:
                break
            }
            return true
        }
        
        return results
    }
}
