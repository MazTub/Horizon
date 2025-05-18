//
//  UserEntity+CoreDataProperties.swift
//  Weekend Horizon
//
//  Created by Thomas Mazhar-Elstub on 09/05/2025.
//
//

import Foundation
import CoreData


extension UserEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var recordIDValue: String?
    @NSManaged public var email: String?
    @NSManaged public var displayName: String?
    @NSManaged public var avatarFull: Data?
    @NSManaged public var avatarThumb: Data?
    @NSManaged public var timezone: String?
    @NSManaged public var events: NSSet?

}

// MARK: Generated accessors for events
extension UserEntity {

    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: EventEntity)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: EventEntity)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)

}

extension UserEntity : Identifiable {

}
