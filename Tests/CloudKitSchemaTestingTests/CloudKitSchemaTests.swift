import Foundation
import SwiftData
import Testing

@testable import CloudKitSchemaTesting

@Model
final class Bird {
  var name = ""
  var wingspan = 0.0
  var isBanded = false
  var sighted = Date.now
  var identifier = UUID()
  var photo: Data?
  var nest: Nest?

  init() {}
}

@Model
final class Nest {
  var height = 0
  @Relationship(inverse: \Bird.nest)
  var birds: [Bird]? = []

  init() {}
}

private let fullSchema = """
  DEFINE SCHEMA

      RECORD TYPE CD_Bird (
          CD_entityName      STRING QUERYABLE SEARCHABLE SORTABLE,
          CD_identifier      STRING QUERYABLE SEARCHABLE SORTABLE,
          CD_isBanded        INT64 QUERYABLE SORTABLE,
          CD_name            STRING QUERYABLE SEARCHABLE SORTABLE,
          CD_name_ckAsset    ASSET,
          CD_nest            STRING QUERYABLE SEARCHABLE SORTABLE,
          CD_photo           BYTES QUERYABLE SORTABLE,
          CD_sighted         TIMESTAMP QUERYABLE SORTABLE,
          CD_wingspan        DOUBLE QUERYABLE SORTABLE,
          "___createTime"    TIMESTAMP,
          "___recordID"      REFERENCE,
          GRANT WRITE TO "_creator",
          GRANT READ TO "_world"
      );

      RECORD TYPE CD_Nest (
          CD_height          INT64 QUERYABLE SORTABLE,
          "___recordID"      REFERENCE,
          GRANT READ TO "_world"
      );

      RECORD TYPE Users (
          "___createTime" TIMESTAMP,
          roles           LIST<INT64>,
          GRANT READ TO "_world"
      );
  """

@Suite("CloudKitSchema")
struct CloudKitSchemaTests {
  @Test("parses record types and fields, without system fields or grants")
  func parse() {
    let schema = CloudKitSchema(ckdb: fullSchema)
    #expect(schema.recordTypes.keys.sorted() == ["CD_Bird", "CD_Nest", "Users"])
    #expect(schema.recordTypes["CD_Nest"] == ["CD_height": "INT64"])
    #expect(schema.recordTypes["Users"] == ["roles": "LIST<INT64>"])
    #expect(schema.recordTypes["CD_Bird"]?["CD_name_ckAsset"] == "ASSET")
  }

  @Test("finds no gaps in a schema that covers every model property")
  func covered() {
    #expect(CloudKitSchema(ckdb: fullSchema).gaps(for: [Bird.self, Nest.self]).isEmpty)
  }

  @Test("reports missing record types, missing fields, and type mismatches")
  func gaps() {
    let schema = CloudKitSchema(
      ckdb:
        fullSchema
        .replacing(#/\s+CD_photo .*\n/#, with: "\n")
        .replacing("CD_wingspan        DOUBLE", with: "CD_wingspan        INT64")
        .replacing("RECORD TYPE CD_Nest", with: "RECORD TYPE CD_Burrow")
    )
    #expect(
      schema.gaps(for: [Bird.self, Nest.self]) == [
        .missingField(recordType: "CD_Bird", field: "CD_photo"),
        .typeMismatch(
          recordType: "CD_Bird",
          field: "CD_wingspan",
          expected: "DOUBLE",
          actual: "INT64"
        ),
        .missingRecordType("CD_Nest")
      ]
    )
  }
}
