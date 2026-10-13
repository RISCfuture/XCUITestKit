import CoreData
public import SwiftData

@available(iOS 17, macOS 14, watchOS 10, visionOS 1, *)
extension CloudKitSchema {

  /// The fields an entity's record type needs, mapped to their CloudKit types where the mapping is
  /// known, or `nil` where only the field's presence can be checked.
  private static func expectedFields(of entity: NSEntityDescription) -> [String: String?] {
    var fields = [String: String?]()
    for (name, attribute) in entity.attributesByName {
      fields["CD_\(name)"] = cloudKitType(of: attribute.attributeType)
    }
    for (name, relationship) in entity.relationshipsByName where !relationship.isToMany {
      fields["CD_\(name)"] = "STRING"
    }
    return fields
  }

  private static func cloudKitType(of type: NSAttributeType) -> String? {
    switch type {
      case .stringAttributeType, .UUIDAttributeType, .URIAttributeType: "STRING"
      case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType,
        .booleanAttributeType:
        "INT64"
      case .doubleAttributeType, .floatAttributeType: "DOUBLE"
      case .dateAttributeType: "TIMESTAMP"
      case .binaryDataAttributeType, .transformableAttributeType: "BYTES"
      default: nil
    }
  }

  /**
   What this schema lacks for `models` to sync through `NSPersistentCloudKitContainer`, which
   SwiftData's CloudKit store is built on.

   Each model is mirrored as a record type named `CD_` plus the entity name, with a `CD_`-prefixed
   field for each attribute and to-one relationship. A field the schema has but the models don't
   is not a gap: a deployed schema only ever grows.

   - Parameter models: The models the app syncs.
   - Returns: Every gap, in a stable order; empty when the schema covers the models.
   */
  public func gaps(for models: [any PersistentModel.Type]) -> [SchemaGap] {
    guard let model = NSManagedObjectModel.makeManagedObjectModel(for: models) else {
      preconditionFailure("SwiftData could not express the models as a Core Data model.")
    }
    return model.entities
      .sorted { ($0.name ?? "") < ($1.name ?? "") }
      .flatMap(gaps(for:))
  }

  private func gaps(for entity: NSEntityDescription) -> [SchemaGap] {
    let recordType = "CD_\(entity.name ?? "")"
    guard let fields = recordTypes[recordType] else { return [.missingRecordType(recordType)] }

    return Self.expectedFields(of: entity)
      .sorted { $0.key < $1.key }
      .compactMap { field, expected in
        guard let actual = fields[field] else {
          return .missingField(recordType: recordType, field: field)
        }
        guard let expected, expected != actual else { return nil }
        return .typeMismatch(
          recordType: recordType,
          field: field,
          expected: expected,
          actual: actual
        )
      }
  }
}
