import SwiftUI
import Combine

enum PairTab: Int {
    case records
    case graph
}

final class PairTabRouter: ObservableObject {
    @Published var selectedTab: PairTab = .records
}

struct RootTabView: View {
    @StateObject private var tabRouter = PairTabRouter()
    @StateObject private var homeVM = HomeViewModel()
    @State private var showSettings = false

    // Re-tap refresh keys（同じタブ再タップで画面を作り直す）
    @State private var recordsReloadKey = UUID()
    @State private var graphReloadKey = UUID()

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let headerContentHeight: CGFloat = 40
            let headerHeight = headerContentHeight + topInset

            ZStack(alignment: .top) {

                VStack(spacing: 0) {

                    // メインコンテンツ
                    ZStack {
                        if homeVM.isLoading {
                            Color.background.ignoresSafeArea()
                            ProgressView()
                                .tint(Color.maincolor)
                        } else {
                            RecordsView(
                                showSettings: $showSettings,
                                user1: homeVM.user1,
                                user2: homeVM.user2,
                                records: homeVM.records
                            )
                            .id(recordsReloadKey)
                            .opacity(tabRouter.selectedTab == .records ? 1 : 0)
                            .allowsHitTesting(tabRouter.selectedTab == .records)

                            GraphView(
                                showSettings: $showSettings,
                                user1: homeVM.user1,
                                user2: homeVM.user2,
                                records: homeVM.records
                            )
                            .id(graphReloadKey)
                            .opacity(tabRouter.selectedTab == .graph ? 1 : 0)
                            .allowsHitTesting(tabRouter.selectedTab == .graph)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, headerContentHeight)

                    // カスタムタブバー（2タブ：立て替え / グラフ）
                    Divider()
                        HStack(spacing: 0) {
                            tabButton(.records, label: "立て替え", systemImage: "list.bullet")
                            tabButton(.graph, label: "グラフ", systemImage: "chart.bar.xaxis")
                        }
                        .padding(.vertical, 2)
                    
                    
                }

                // ===== 固定ヘッダー（ステータスバーまで塗りつぶし + 左上ロゴ + 右上設定ボタン）=====
                ZStack {
                    Color.background

                    VStack(spacing: 0) {
                        // ステータスバー分
                        Spacer().frame(height: topInset)

                        ZStack {
                            // 左上ロゴ
                            HStack(spacing: 0) {
                                Image("logoinvis")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                                    .padding(.leading, 12)

                                Text("PairLog")
                                    .font(.system(size: 20, weight: .semibold, design: .serif))
                                    .italic()
                                    .foregroundColor(Color.maincolor)

                                Spacer()
                            }

                            // 右上設定ボタン
                            HStack {
                                Spacer()
                                Button {
                                    showSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(Color.maincolor)
                                        .padding(10)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 6)
                            }
                        }
                        .frame(height: headerContentHeight)
                    }
                }
                .frame(height: headerHeight)
                .ignoresSafeArea(edges: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.background)
        .task {
            await homeVM.start()
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            // 設定画面を閉じたときにアバター画像を再読み込み
            homeVM.reloadAvatars()
        }) {
            SettingsView()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: PairTab, label: String, systemImage: String) -> some View {
        Button {
            if tabRouter.selectedTab == tab {
                // 🔁 同じタブをもう一度タップしたときの挙動（画面再生成）
                switch tab {
                case .records:
                    recordsReloadKey = UUID()
                case .graph:
                    graphReloadKey = UUID()
                }
            } else {
                // 違うタブを押したときは単純にタブを切り替え
                tabRouter.selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                tabRouter.selectedTab == tab
                ? Color.maincolor
                : Color.secondary
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootTabView()
}
