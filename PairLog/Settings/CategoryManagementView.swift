import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct ExpenseCategory: Identifiable, Equatable {
    let id: String
    var name: String
    var order: Int

    init(id: String = UUID().uuidString, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let name = data["name"] as? String,
              let order = data["order"] as? Int else {
            return nil
        }

        self.id = document.documentID
        self.name = name
        self.order = order
    }
}

@MainActor
final class CategoryManagementViewModel: ObservableObject {
    @Published var categories: [ExpenseCategory] = []
    @Published var newCategoryName: String = ""
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    init(categories: [ExpenseCategory] = []) {
        self.categories = categories
    }

    func startListening() {
        guard listener == nil else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "カテゴリを編集するにはログインが必要です"
            return
        }

        isLoading = true
        errorMessage = nil

        listener = db.collection("users")
            .document(uid)
            .collection("categories")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.errorMessage = "カテゴリの取得に失敗しました: \(error.localizedDescription)"
                    return
                }

                let docs = snapshot?.documents ?? []
                self.categories = docs.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let order = data["order"] as? Int else { return nil }
                    return ExpenseCategory(id: doc.documentID, name: name, order: order)
                }
                self.errorMessage = nil
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    var trimmedCategoryName: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAddCategory: Bool {
        let trimmed = trimmedCategoryName
        return !trimmed.isEmpty && !categories.contains(where: { $0.name == trimmed })
    }

    func addCategory() async {
        let name = trimmedCategoryName
        guard !name.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "カテゴリを追加するにはログインが必要です"
            return
        }
        guard !categories.contains(where: { $0.name == name }) else {
            errorMessage = "同じ名前のカテゴリは追加できません"
            return
        }

        isSaving = true
        errorMessage = nil

        let newCategory = ExpenseCategory(
            name: name,
            order: categories.count
        )

        do {
            try await db.collection("users")
                .document(uid)
                .collection("categories")
                .document(newCategory.id)
                .setData([
                    "name": newCategory.name,
                    "order": newCategory.order,
                    "isDefault": false,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            newCategoryName = ""
        } catch {
            errorMessage = "カテゴリの追加に失敗しました: \(error.localizedDescription)"
        }

        isSaving = false
    }

    func deleteCategories(at offsets: IndexSet) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "カテゴリを削除するにはログインが必要です"
            return
        }

        let targets = offsets.map { categories[$0] }
        let remaining = categories.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)

        isSaving = true
        errorMessage = nil

        do {
            let batch = db.batch()
            let collection = db.collection("users").document(uid).collection("categories")

            for category in targets {
                batch.deleteDocument(collection.document(category.id))
            }

            for (index, category) in remaining.enumerated() {
                batch.updateData([
                    "order": index,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: collection.document(category.id))
            }

            try await batch.commit()
        } catch {
            errorMessage = "カテゴリの削除に失敗しました: \(error.localizedDescription)"
        }

        isSaving = false
    }

    func moveCategories(from source: IndexSet, to destination: Int) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "カテゴリを並び替えるにはログインが必要です"
            return
        }

        var updated = categories
        updated.move(fromOffsets: source, toOffset: destination)

        isSaving = true
        errorMessage = nil

        do {
            let batch = db.batch()
            let collection = db.collection("users").document(uid).collection("categories")

            for (index, category) in updated.enumerated() {
                batch.updateData([
                    "order": index,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: collection.document(category.id))
            }

            try await batch.commit()
        } catch {
            errorMessage = "カテゴリの並び替えに失敗しました: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

struct CategoryManagementView: View {
    @StateObject private var viewModel: CategoryManagementViewModel
    @FocusState private var isTextFieldFocused: Bool

    @MainActor
    init(viewModel: CategoryManagementViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? CategoryManagementViewModel())
    }

    var body: some View {
        List {
            Section("カテゴリを追加") {
                HStack(spacing: 12) {
                    TextField("新しいカテゴリ名", text: $viewModel.newCategoryName)
                        .focused($isTextFieldFocused)
                        .foregroundStyle(Color.maincolor)
                        .dismissOnSubmit()

                    Button {
                        Task {
                            await viewModel.addCategory()
                            if viewModel.errorMessage == nil {
                                isTextFieldFocused = false
                            }
                        }
                    } label: {
                        Text("追加")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.canAddCategory ? Color.maincolor : Color.maincolor.opacity(0.35))
                            )
                    }
                    .disabled(!viewModel.canAddCategory || viewModel.isSaving)
                }
            }

            Section("登録済みカテゴリ") {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.maincolor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if viewModel.categories.isEmpty {
                    Text("カテゴリがまだありません")
                        .font(.subheadline)
                        .foregroundStyle(Color.maincolor.opacity(0.7))
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.categories) { category in
                        HStack {
                            Text(category.name)
                                .foregroundStyle(Color.maincolor)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        Task {
                            await viewModel.deleteCategories(at: offsets)
                        }
                    }
                    .onMove { source, destination in
                        Task {
                            await viewModel.moveCategories(from: source, to: destination)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("カテゴリ管理")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .foregroundStyle(Color.maincolor)
            }
        }
        .dismissKeyboardToolbar()
        .task {
            if viewModel.categories.isEmpty {
                viewModel.startListening()
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

#Preview {
    let previewCategories = RecordsMockData.categories.enumerated().map { index, name in
        ExpenseCategory(name: name, order: index)
    }

    NavigationStack {
        CategoryManagementView(
            viewModel: CategoryManagementViewModel(categories: previewCategories)
        )
    }
}
