
import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

enum PairUsersFormMode {
    case setup
    case edit

    var title: String {
        switch self {
        case .setup:
            return "最初に2人を登録"
        case .edit:
            return "プロフィールを編集"
        }
    }

    var subtitle: String {
        switch self {
        case .setup:
            return "ユーザー名とアイコン画像を設定しましょう"
        case .edit:
            return "ユーザー名とアイコン画像を変更できます"
        }
    }

    var actionTitle: String {
        switch self {
        case .setup:
            return "登録して利用を開始する"
        case .edit:
            return "保存する"
        }
    }

    var footerText: String {
        switch self {
        case .setup:
            return "※ ユーザー名、画像は後から変更できます"
        case .edit:
            return "※ 変更内容はいつでも更新できます"
        }
    }
}

/// ログイン後に「2人分のユーザー名 + 画像」を設定する画面
struct PairUsersSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: PairUsersFormMode

    /// 完了時に呼び出したい場合に使う（後でRoot側から注入する想定）
    var onComplete: (_ user1: PairUserDraft, _ user2: PairUserDraft) -> Void = { _, _ in }

    @State private var user1Name: String
    @State private var user2Name: String

    @State private var user1PhotoItem: PhotosPickerItem?
    @State private var user2PhotoItem: PhotosPickerItem?

    @State private var user1ImageData: Data?
    @State private var user2ImageData: Data?

    private var canContinue: Bool {
        !user1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !user2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    init(
        mode: PairUsersFormMode = .setup,
        user1: PairUserDraft = PairUserDraft(name: "", imageData: nil),
        user2: PairUserDraft = PairUserDraft(name: "", imageData: nil),
        onComplete: @escaping (_ user1: PairUserDraft, _ user2: PairUserDraft) -> Void = { _, _ in }
    ) {
        self.mode = mode
        self.onComplete = onComplete
        _user1Name = State(initialValue: user1.name)
        _user2Name = State(initialValue: user2.name)
        _user1ImageData = State(initialValue: user1.imageData)
        _user2ImageData = State(initialValue: user2.imageData)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.background.ignoresSafeArea()

            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text(mode.title)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(Color.maincolor)
                    
                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.maincolor.opacity(0.7))
                }
                .padding(.top, 8)
                
                PairUserCard(
                    userKey: .user1,
                    title: "ユーザー1",
                    defaultAssetName: "poodle",
                    name: $user1Name,
                    photoItem: $user1PhotoItem,
                    imageData: $user1ImageData
                )
                
                PairUserCard(
                    userKey: .user2,
                    title: "ユーザー2",
                    defaultAssetName: "pome",
                    name: $user2Name,
                    photoItem: $user2PhotoItem,
                    imageData: $user2ImageData
                )
                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.maincolor.opacity(0.6))
                        Text("プロフィール画像はこの端末にのみ保存されます。")
                            .font(.caption)
                            .foregroundStyle(Color.maincolor.opacity(0.6))
                    }
                    .padding(.horizontal, 4)

                    Button {
                        errorMessage = nil
                        Task {
                            await saveAndContinue()
                        }
                    } label: {
                        Text(mode.actionTitle)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canContinue ? Color.maincolor : Color.maincolor.opacity(0.35))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canContinue || isSaving)
                    .padding(.top, 8)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Text(mode.footerText)
                        .font(.footnote)
                        .foregroundStyle(Color.maincolor.opacity(0.7))
                        .padding(.bottom, 12)
                    Spacer(minLength: 0)
                }
            }
            .padding()
        }
        .dismissKeyboardToolbar()
        .task {
            // 編集モードのみ：既存データをロード
            if mode == .edit {
                await loadExistingProfile()
            }
        }
    }

    // MARK: - 既存プロフィールの読み込み（編集モード用）

    @MainActor
    private func loadExistingProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // ユーザー名を Firestore から取得
        let db = Firestore.firestore()
        if let doc = try? await db.collection("users").document(uid)
            .collection("pair_profile").document("main").getDocument(),
           let data = doc.data() {
            let name1 = (data["user1Name"] as? String) ?? ""
            let name2 = (data["user2Name"] as? String) ?? ""
            if user1Name.isEmpty { user1Name = name1 }
            if user2Name.isEmpty { user2Name = name2 }
        }

        // アバター画像をローカルから取得
        if user1ImageData == nil, let img = LocalAvatarStore.loadAvatar(for: .user1) {
            user1ImageData = img.jpegData(compressionQuality: 0.9)
        }
        if user2ImageData == nil, let img = LocalAvatarStore.loadAvatar(for: .user2) {
            user2ImageData = img.jpegData(compressionQuality: 0.9)
        }
    }
}

struct PairUserDraft: Equatable {
    var name: String
    var imageData: Data?
}

/// WAGMEALと同じ：PhotosPickerで選んだUIImageをCropperに渡すためのpayload
private struct ImageCropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct PairUserCard: View {
    let userKey: PairLocalUserKey
    let title: String
    let defaultAssetName: String
    @Binding var name: String
    @Binding var photoItem: PhotosPickerItem?
    @Binding var imageData: Data?

    // WAGMEALと同じ導線
    @State private var showPhotoPicker: Bool = false
    @State private var cropPayload: ImageCropPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.maincolor)

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    // アイコン（タップで写真選択）
                    ZStack {
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(defaultAssetName)
                                .resizable()
                                .scaledToFill()

                            // 初期アイコンの上に半透明の白い丸を被せる
                            Circle()
                                .fill(Color.white.opacity(0.8))

                            // ＋マーク（背景なし）
                            Image(systemName: "plus")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.maincolor.opacity(0.5))
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipped()
                    .background(
                        defaultAssetName == "poodle"
                        ? Color.gray
                        : defaultAssetName == "pome"
                            ? Color.subcolor1
                            : Color.background
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.maincolor.opacity(0.35), lineWidth: 1)
                    )
                    .contentShape(Circle())
                    .onTapGesture { showPhotoPicker = true }
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $photoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    )

                    if imageData != nil {
                        Button {
                            // 選択済み画像を削除
                            imageData = nil
                            photoItem = nil
                            cropPayload = nil
                            showPhotoPicker = false
                            LocalAvatarStore.deleteAvatar(for: userKey)
                        } label: {
                            Text("削除")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 10) {
                    TextField("ユーザー名", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .dismissOnSubmit()

                    Text("アイコンをタップして写真を登録")
                        .font(.caption)
                        .foregroundStyle(Color.maincolor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.background)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.maincolor.opacity(0.12), lineWidth: 1)
        )
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        // 同じ画像を選び直した時に再表示が安定するよう、いったんnilにする
                        cropPayload = nil
                        cropPayload = ImageCropPayload(image: img)
                    }
                }
            }
        }
        // ✅ WAGMEALと同じ：fullScreenCoverでCropperを表示
        .fullScreenCover(item: $cropPayload) { payload in
            CircularImageCropperView(
                image: payload.image,
                onCancel: { cropPayload = nil },
                onCropped: { cropped in
                    imageData = cropped.jpegData(compressionQuality: 0.9)
                    cropPayload = nil
                }
            )
        }
    }
}

// MARK: - Circular Cropper

/// 写真のどこを丸アイコンにするか指定できる簡易Cropper
private struct CircularImageCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onCropped: (UIImage) -> Void

    // 表示上の操作値
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // UIパラメータ
    private let cropDiameter: CGFloat = 280
    private let outputSize: CGFloat = 512

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack {
                        // 画像（円の下に表示）
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cropDiameter, height: cropDiameter)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipped()

                        // 半透明マスク（外側を暗く）
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .mask(
                                Rectangle()
                                    .overlay(
                                        Circle()
                                            .frame(width: cropDiameter, height: cropDiameter)
                                            .blendMode(.destinationOut)
                                    )
                                    .compositingGroup()
                            )
                            .frame(width: cropDiameter, height: cropDiameter)

                        // 円枠
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: cropDiameter, height: cropDiameter)
                    }
                    .frame(width: cropDiameter, height: cropDiameter)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, min(4.0, lastScale * value))
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )

                    Text("指で拡大・移動して、丸アイコンにしたい範囲を合わせてください")
                        .font(.footnote)
                        .foregroundStyle(Color.maincolor.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } label: {
                            Text("リセット")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.maincolor.opacity(0.25), lineWidth: 1)
                                )
                                .cornerRadius(12)
                        }

                        Button {
                            let cropped = renderCroppedImage()
                            onCropped(cropped)
                        } label: {
                            Text("完了")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.maincolor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("画像を調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
            }
        }
    }

    /// 表示中のscale/offsetをもとに、正方形(512x512)で書き出し
    private func renderCroppedImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))

        // 画像をcrop枠(=outputSize)にAspectFillで合わせる基本倍率
        let baseScale = max(outputSize / image.size.width, outputSize / image.size.height)
        let totalScale = baseScale * scale

        // UI上のoffset(cropDiameter基準)を出力サイズにスケール変換
        let offsetScale = outputSize / cropDiameter
        let outOffset = CGPoint(
            x: offset.width * offsetScale,
            y: offset.height * offsetScale
        )

        return renderer.image { _ in
            let drawSize = CGSize(width: image.size.width * totalScale, height: image.size.height * totalScale)
            let origin = CGPoint(
                x: (outputSize - drawSize.width) / 2 + outOffset.x,
                y: (outputSize - drawSize.height) / 2 + outOffset.y
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

#Preview("Setup") {
    PairUsersSetupView(mode: .setup)
}

#Preview("Edit") {
    PairUsersSetupView(
        mode: .edit,
        user1: PairUserDraft(name: "たくみ", imageData: nil),
        user2: PairUserDraft(name: "あや", imageData: nil)
    )
}

//# MARK: - Local Avatar Store (images are saved inside the app)

enum PairLocalUserKey: String {
    case user1
    case user2
}

enum LocalAvatarStore {
    private static func fileURL(for key: PairLocalUserKey) throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("pair_avatar_\(key.rawValue).jpg")
    }

    static func saveAvatar(data: Data, for key: PairLocalUserKey) throws {
        let url = try fileURL(for: key)
        try data.write(to: url, options: [.atomic])
    }

    static func loadAvatar(for key: PairLocalUserKey) -> UIImage? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent("pair_avatar_\(key.rawValue).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func deleteAvatar(for key: PairLocalUserKey) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("pair_avatar_\(key.rawValue).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Firestore Store (names only)

enum FirestorePairUserStore {
    /// users/{uid}/pair_profile/main に user1Name/user2Name を保存
    static func saveNames(uid: String, user1Name: String, user2Name: String) async throws {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
            .collection("pair_profile").document("main")

        let data: [String: Any] = [
            "user1Name": user1Name,
            "user2Name": user2Name,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setData(data, merge: true) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    /// users/{uid}/categories に初期カテゴリを作成（未作成時のみ）
    static func createDefaultCategoriesIfNeeded(uid: String) async throws {
        let db = Firestore.firestore()
        let categoriesRef = db.collection("users").document(uid)
            .collection("categories")

        let snapshot = try await categoriesRef.limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }

        let defaults = ["未分類", "日用品", "交通費", "レジャー", "食費"]
        let batch = db.batch()

        for (index, name) in defaults.enumerated() {
            let doc = categoriesRef.document()
            batch.setData([
                "name": name,
                "order": index,
                "isDefault": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: doc)
        }

        try await batch.commit()
    }
}


// MARK: - Save and Continue Helper

extension PairUsersSetupView {

    @MainActor
    private func saveAndContinue() async {
        guard canContinue else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報が取得できませんでした"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmed1 = user1Name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed2 = user2Name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 画像はローカル（アプリ内）に保存
        //    - 画像未選択の場合は保存しない（デフォルト画像はAssets表示のまま）
        do {
            if let data = user1ImageData {
                try LocalAvatarStore.saveAvatar(data: data, for: .user1)
            }
            if let data = user2ImageData {
                try LocalAvatarStore.saveAvatar(data: data, for: .user2)
            }
        } catch {
            errorMessage = "画像の保存に失敗しました: \(error.localizedDescription)"
            return
        }

        // 2) Firebaseにはユーザー名だけ保存
        do {
            try await FirestorePairUserStore.saveNames(uid: uid, user1Name: trimmed1, user2Name: trimmed2)
        } catch {
            errorMessage = "ユーザー名の保存に失敗しました: \(error.localizedDescription)"
            return
        }

        // 3) 初回セットアップ時のみ、デフォルトカテゴリを作成
        if mode == .setup {
            do {
                try await FirestorePairUserStore.createDefaultCategoriesIfNeeded(uid: uid)
            } catch {
                errorMessage = "初期カテゴリの作成に失敗しました: \(error.localizedDescription)"
                return
            }
        }

        // 4) 次の導線へ
        let u1 = PairUserDraft(name: trimmed1, imageData: user1ImageData)
        let u2 = PairUserDraft(name: trimmed2, imageData: user2ImageData)
        onComplete(u1, u2)

        // 編集モードは保存後に画面を閉じる
        if mode == .edit {
            dismiss()
        }
    }
}
