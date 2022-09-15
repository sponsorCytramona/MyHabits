//
//  Settings.swift
//  MyHabits
//
//  Created by Max Klimakhovich on 10/09/2022.
//

import Foundation

struct Settings {
    // MARK: Properties
    static var shared = Settings()
    
    let currentUser = User(id: "activeUser", name: "Alina Klimakhovich", color: nil, bio: nil)
    
    private let defaults = UserDefaults.standard
    
    enum Setting {
        static let favoriteHabits = "favoriteHabits"
        
        static let followerUserIDs = "followerUserIDs"
    }
    
    var favoriteHabits: [Habit] {
        get {
            return unarchiveJSON(key: Setting.favoriteHabits) ?? []
        } set {
            archiveJSON(value: newValue, key: Setting.favoriteHabits)
        }
    }
    
    var followedUserIDs: [String] {
        get {
            return unarchiveJSON(key: Setting.followerUserIDs) ?? []
        } set {
            archiveJSON(value: newValue, key: Setting.followerUserIDs)
        }
    }
    
    
    
    // MARK: Methods
    private func archiveJSON<T: Encodable>(value: T, key: String) {
        let data = try! JSONEncoder().encode(value)
        let string = String(data: data, encoding: .utf8)
        defaults.set(string, forKey: key)
    }
    
    
    
    private func unarchiveJSON<T: Decodable>(key: String) -> T? {
        guard let string = defaults.string(forKey: key),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return try! JSONDecoder().decode(T.self, from: data)
    }
    
    
    
    mutating func toggleFavorites(_ habit: Habit) {
        var favorites = favoriteHabits
        
        if favorites.contains(habit) {
            favorites = favorites.filter { $0 != habit }
        } else {
            favorites.append(habit)
        }
        
        favoriteHabits = favorites
    }
    
    
    
    mutating func toggleFollowed(user: User) {
        var updated = followedUserIDs
        
        if updated.contains(user.id) {
            updated = updated.filter{ $0 != user.id }
        } else {
            updated.append(user.id)
        }
        
        followedUserIDs = updated
    }
}
