import SwiftUI
import UIKit

extension Color {

    // PairFund Brand Colors
    static let maincolor = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let background = Color(red: 0.96, green: 0.95, blue: 0.92)

    // Cream Accent
    static let subcolor1 = Color(red: 0.98, green: 0.94, blue: 0.85)
}

extension View {
    /// Returnキーを「完了」にしてキーボードを閉じる
    func dismissOnSubmit() -> some View {
        submitLabel(.done)
            .onSubmit {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }

    /// キーボード上部に「閉じる」ボタンを追加する
    func dismissKeyboardToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundStyle(Color.maincolor)
                }
            }
        }
    }
}
