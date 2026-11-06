import SwiftUI

extension BlockPalette {
  /// The palette the Live Activity is drawn in.
  static let current: BlockPalette = .lunna

  /// The mark, from the extension's asset catalogue.
  var markImage: Image { Image(mark) }
}
