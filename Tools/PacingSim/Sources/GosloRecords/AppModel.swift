import Foundation

/// Linux stand-in for the app's AppModel: the tests only use it to find the bundle
/// (`Bundle(for: AppModel.self)`), where run-tests.sh copies the JSON resources.
final class AppModel {}
