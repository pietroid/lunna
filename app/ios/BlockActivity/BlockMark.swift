import SwiftUI

extension BlockPalette {
  /// The brand this extension was built for: `LunnaBrand` in its
  /// Info.plist, set per flavor (`BRAND_ID`).
  static let current: BlockPalette =
    Bundle.main.object(forInfoDictionaryKey: "LunnaBrand") as? String == "focus"
    ? .focus : .lunna

  /// The brand's mark, from the extension's asset catalogue.
  var markImage: Image { Image(mark) }
}
