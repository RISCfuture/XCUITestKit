/// Something a set of SwiftData models needs from a CloudKit schema that the schema lacks.
public enum SchemaGap: Sendable, Equatable, CustomStringConvertible {

  /// A model with no record type.
  case missingRecordType(String)

  /// A model property with no field in its record type.
  case missingField(recordType: String, field: String)

  /// A field whose type differs from the one the model property maps to.
  case typeMismatch(recordType: String, field: String, expected: String, actual: String)

  public var description: String {
    switch self {
      case .missingRecordType(let recordType):
        "Record type \(recordType) is missing."
      case let .missingField(recordType, field):
        "\(recordType) is missing field \(field)."
      case let .typeMismatch(recordType, field, expected, actual):
        "\(recordType).\(field) is \(actual), but the model needs \(expected)."
    }
  }
}
