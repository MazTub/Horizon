//
//  ReminderConfigEntity+CoreDataProperties.swift
//  Weekend Horizon
//
//  Created by Thomas Mazhar-Elstub on 09/05/2025.
//
//

import Foundation
import CoreData


extension ReminderConfigEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReminderConfigEntity> {
        return NSFetchRequest<ReminderConfigEntity>(entityName: "ReminderConfigEntity")
    }

    @NSManaged public var recordID: String?
    @NSManaged public var offsetMinutes: Int16
    @NSManaged public var mode: String?
    @NSManaged public var eventRef: EventEntity?

}

extension ReminderConfigEntity : Identifiable {

}
