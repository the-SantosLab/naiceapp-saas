import SwiftUI
import WidgetKit

struct NAiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        NAiceWidget()
        NAiceLockScreenWidget()
    }
}