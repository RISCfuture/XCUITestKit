public import Foundation

/**
 The record types and fields of a CloudKit container schema, read from the `.ckdb` text that
 `xcrun cktool export-schema` writes.

 Only the parts an app's models can depend on are kept: each record type's name and its fields'
 names and types. Permission grants are dropped, as are CloudKit's own `___` system fields, which
 every record type carries.
 */
public struct CloudKitSchema: Sendable, Equatable {

  /// Field types by field name, by record type name — e.g.
  /// `["CD_Note": ["CD_title": "STRING"]]`.
  public let recordTypes: [String: [String: String]]

  /**
   Parses the text of a `.ckdb` export.

   - Parameter ckdb: The schema, in the format `cktool export-schema` writes.
   */
  public init(ckdb: String) {
    var recordTypes = [String: [String: String]]()
    var current: String?

    for line in ckdb.split(whereSeparator: \.isNewline) {
      if let match = line.wholeMatch(of: #/\s*RECORD TYPE\s+"?([^"\s(]+)"?\s*\(\s*/#) {
        current = String(match.1)
        recordTypes[String(match.1)] = [:]
      } else if line.wholeMatch(of: #/\s*\);\s*/#) != nil {
        current = nil
      } else if let recordType = current,
        let match = line.wholeMatch(of: #/\s*"?(\w+)"?\s+([A-Z0-9<>]+).*/#),
        !match.1.hasPrefix("___"),
        match.1 != "GRANT"
      {
        recordTypes[recordType, default: [:]][String(match.1)] = String(match.2)
      }
    }

    self.recordTypes = recordTypes
  }

  /**
   Reads and parses a `.ckdb` export.

   - Parameter url: The location of the exported schema.
   - Throws: An error if the file can't be read.
   */
  public init(contentsOf url: URL) throws {
    self.init(ckdb: try String(contentsOf: url, encoding: .utf8))
  }
}
