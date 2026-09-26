import ServiceManagement
import SwiftUI

/// メニューバーのアイコンを押したときに開くパネル
struct MenuView: View {
    let controller: FilterController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if controller.isAvailable {
                ForEach(controller.displays) { display in
                    DisplaySection(controller: controller, display: display)
                    Divider()
                }
            } else {
                Text("This version of macOS isn’t supported (required system functions weren’t found).")
                    .foregroundStyle(.secondary)
                Divider()
            }
            HStack {
                Spacer()
                AppMenu()
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// 右下の歯車メニュー(ログイン時に開く・About・終了など、ディスプレイ以外のアプリ全体の項目)
private struct AppMenu: View {
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Menu {
            Toggle("Open at Login", isOn: Binding(get: { opensAtLogin }, set: { setOpensAtLogin($0) }))
            Divider()
            Button("About Display Colour Filter") { showAbout() }
            Button("Quit Display Colour Filter") { NSApp.terminate(nil) }
        } label: {
            Label("Settings", systemImage: "gearshape").labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onAppear { opensAtLogin = SMAppService.mainApp.status == .enabled }
    }

    /// システム設定の「ログイン項目」に登録・解除する
    private func setOpensAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        // 失敗したときはチェックを実際の状態に戻すだけ
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
        opensAtLogin = service.status == .enabled
        // システム設定で許可が必要な状態なら、その画面を開く
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    /// 標準の About パネルを出す(アイコン・バージョン・著作権は Info.plist から)。リポジトリへのリンクを添える
    private func showAbout() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let url = Config.repositoryURL
        let credits = NSAttributedString(string: (url.host() ?? "") + url.path(), attributes: [
            .link: url,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: paragraph,
        ])
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

/// ディスプレイ1台ぶんの設定欄
private struct DisplaySection: View {
    let controller: FilterController
    let display: ConnectedDisplay

    var body: some View {
        let setting = controller.setting(for: display)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.name).font(.headline)
                Spacer()
                Toggle(display.name, isOn: binding(\.isEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if setting.isEnabled {
                Picker("Filter", selection: binding(\.type)) {
                    ForEach(FilterType.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Intensity") {
                    Slider(value: binding(\.intensity), in: Config.intensityRange)
                }
                if setting.type == .colorTint {
                    LabeledContent("Hue") {
                        Slider(value: binding(\.hue), in: 0...1)
                    }
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<DisplaySetting, Value>) -> Binding<Value> {
        Binding(
            get: { controller.setting(for: display)[keyPath: keyPath] },
            set: { newValue in controller.update(display) { $0[keyPath: keyPath] = newValue } }
        )
    }
}
