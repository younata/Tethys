import SwiftUI

struct AppIconView: View {
    private let iconChanger: AppIconChanger

    @State private var selectedIcon: AppIcon

    init(iconChanger: AppIconChanger) {
        self.iconChanger = iconChanger

        _selectedIcon = State(initialValue: iconChanger.selectedIcon)
    }

    var body: some View {
        List(AppIcon.all) { (icon: AppIcon) in
            HStack {
                Text(verbatim: icon.localizedName)
                    .padding([.leading], 20)
                    .padding([.top, .bottom], 8)
                Image(icon.imageName)
                    .frame(width: 60, height: 60)
                    .padding([.top, .bottom], 8)
                    .padding([.leading], 16)
                if icon == self.selectedIcon {
                    Image("Checkmark")
                    .padding([.trailing], 20)
                    .padding([.top, .bottom], 8)
                    .padding([.leading], 16)
                }
            }
                .gesture(TapGesture(count: 1).onEnded { _ in
                    guard icon != self.iconChanger.selectedIcon else { return }
                    self.iconChanger.selectedIcon = icon
                    self.selectedIcon = icon
                }
            )
                .accessibility(label: Text(verbatim: icon.localizedName))
                .accessibility(identifier: "AppIcon \(icon.accessibilityId)")
                .accessibility(addTraits: self.rowAccessibilityTraits(for: icon))
        }
        .navigationBarTitle(
            Text("SettingsViewController_AlternateIcons_Title"),
            displayMode: .inline
        )
    }

    private func backgroundColor(for icon: AppIcon) -> Color {
        if icon == self.selectedIcon {
            return Color(UIColor(named: "highlight")!)
        }
        return Color.clear
    }

    private func rowAccessibilityTraits(for icon: AppIcon) -> AccessibilityTraits {
        var accessibilityTraits: AccessibilityTraits = [.isButton]
        if icon == self.selectedIcon {
            accessibilityTraits.formUnion([.isSelected])
        } else {
            accessibilityTraits.formUnion([.allowsDirectInteraction])
        }
        return accessibilityTraits
    }
}

private extension AppIconChanger {
    var selectedIcon: AppIcon {
        get {
            return AppIcon(name: self.alternateIconName)!
        }
        set {
            self.setAlternateIconName(newValue.internalName) { error in
                guard let receivedError = error else { return }
                print("Error: \(receivedError)")
            }
        }
    }
}
