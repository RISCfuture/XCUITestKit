public import Foundation
public import SwiftData
public import Testing

/// The environment variable that turns schema gaps from warnings into failures.
///
/// Set it to `1` where a gap must block, such as a release build. An Xcode test run receives it
/// only when it is passed to `xcodebuild` as `TEST_RUNNER_CLOUDKIT_SCHEMA_STRICT`.
public let cloudKitSchemaStrictEnvironmentVariableName = "CLOUDKIT_SCHEMA_STRICT"

/**
 Records an issue for each thing the CloudKit schema at `url` lacks for `models` to sync.

 Point `url` at a `.ckdb` export of the container's Production schema. Production builds can't
 add record types or fields, so a model property that isn't there never leaves the device.

 Gaps are recorded as warnings, so that a model change can be developed before its schema is
 deployed; a toolchain older than Swift 6.3 prints them instead. They are recorded as errors when
 ``cloudKitSchemaStrictEnvironmentVariableName`` is `1`. A schema file that can't be read is always
 an error.

 ```swift
 @Test func productionSchemaCoversSyncedModels() {
   expectSchema(at: schemaURL, covers: [Note.self, Tag.self])
 }
 ```

 - Parameters:
   - url: The location of the exported schema.
   - models: The models the app syncs through CloudKit.
   - sourceLocation: Where to attribute the recorded issues.
 */
@available(iOS 17, macOS 14, watchOS 10, visionOS 1, *)
public func expectSchema(
  at url: URL,
  covers models: [any PersistentModel.Type],
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let schema: CloudKitSchema
  do {
    schema = try CloudKitSchema(contentsOf: url)
  } catch {
    Issue.record(
      "Couldn't read the CloudKit schema at \(url.path): \(error)",
      sourceLocation: sourceLocation
    )
    return
  }

  for gap in schema.gaps(for: models) {
    record("CloudKit schema: \(gap)", asError: isStrict, sourceLocation: sourceLocation)
  }
}

/// Records an error, or a warning where Swift Testing has them (Swift 6.3 and later). An older
/// toolchain prints the warning instead.
private func record(_ comment: Comment, asError: Bool, sourceLocation: SourceLocation) {
  #if compiler(>=6.3)
    Issue.record(comment, severity: asError ? .error : .warning, sourceLocation: sourceLocation)
  #else
    if asError {
      Issue.record(comment, sourceLocation: sourceLocation)
    } else {
      print("warning: \(comment)")
    }
  #endif
}

private var isStrict: Bool {
  ProcessInfo.processInfo.environment[cloudKitSchemaStrictEnvironmentVariableName] == "1"
}
