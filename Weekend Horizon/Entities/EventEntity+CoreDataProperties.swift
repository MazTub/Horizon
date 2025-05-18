//
//  EventEntity+CoreDataProperties.swift
//  Weekend Horizon
//
//  Created by Thomas Mazhar-Elstub on 09/05/2025.
//
//

import Foundation
import CoreData


extension EventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EventEntity> {
        return NSFetchRequest<EventEntity>(entityName: "EventEntity")
    }

    @NSManaged public var recordIDValue: String?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var eventType: String?
    @NSManaged public var location: String?
    @NSManaged public var eventDescription: String?
    @NSManaged public var dayMask: Int16
    @NSManaged public var userRef: UserEntity?
    @NSManaged public var reminderConfig: ReminderConfigEntity?

}

extension EventEntity : Identifiable {

}
