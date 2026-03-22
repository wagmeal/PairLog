//
//  UserProfile.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/13.
//
import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String? // FirestoreのdocumentID（= Firebase Authのuid）
    let username: String
    let email: String
    let createdAt: Date
    var agreedTermsVersion: Int?
    var agreedAt: Date?
}
