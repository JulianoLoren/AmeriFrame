import SwiftUI
import PhotosUI

struct EditorView: View {
    @StateObject private var model = EditorModel()
    @AppStorage("language") private var language = "vi"
    @AppStorage("theme") private var theme = "system"
    @State private var items: [PhotosPickerItem] = []
    @State private var png = true
    @State private var width = "1"
    @State private var height = "1"
    @State private var category = "all"
    @State private var drag: (index: Int, photo: Photo, box: CGRect)?
    private var vi: Bool { language == "vi" }
    private func t(_ vi: String, _ en: String) -> String { self.vi ? vi : en }
    private var selected: Bool { model.collage.photos.indices.contains(model.selected) }
    private let ratios: [(String, Double)] = [("1:1", 1), ("4:5", 0.8), ("3:2", 1.5), ("9:16", 9.0/16), ("16:9", 16.0/9)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Ghép khoảnh khắc của bạn.", "Bring your moments together.")).font(.largeTitle.bold())
                        Text(t("Ảnh chỉ ở trên thiết bị · Không watermark", "On-device processing · No watermark")).font(.subheadline).foregroundStyle(.secondary)
                    }
                    preview
                    photoControls
                    ratioControls
                    layoutControls
                    adjustmentControls
                    exportControls
                }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .navigationTitle("Mosaic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(t("Ngôn ngữ", "Language"), selection: $language) { Text("Tiếng Việt").tag("vi"); Text("English").tag("en") }
                        Picker(t("Giao diện", "Appearance"), selection: $theme) {
                            Text(t("Hệ thống", "System")).tag("system")
                            Text(t("Sáng", "Light")).tag("light")
                            Text(t("Tối", "Dark")).tag("dark")
                        }
                    } label: { Image(systemName: "gearshape").accessibilityLabel(t("Cài đặt", "Settings")) }
                }
            }
            .disabled(model.busy)
            .overlay { if model.busy { ProgressView(t("Đang xử lý…", "Processing…")).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .alert(t("Thông báo", "Notice"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
            .sheet(isPresented: Binding(get: { model.shareURL != nil }, set: { if !$0 { model.shareURL = nil } })) {
                if let url = model.shareURL { ShareSheet(url: url) }
            }
        }
        .preferredColorScheme(theme == "system" ? nil : theme == "dark" ? .dark : .light)
        .onChange(of: items) { _, new in Task { await model.load(new, vi: vi); items = [] } }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("BẢN XEM TRƯỚC", "LIVE PREVIEW")).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(model.collage.outputSize.width)) × \(Int(model.collage.outputSize.height))").font(.caption.monospacedDigit())
            }.foregroundStyle(.secondary)
            if model.collage.photos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(t("Mọi câu chuyện bắt đầu bằng một bức ảnh.", "Every story starts with a photo.")).multilineTextAlignment(.center)
                    photoPicker
                }.frame(maxWidth: .infinity).frame(height: 260).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            } else {
                GeometryReader { proxy in
                    let size = proxy.size
                    CollagePreview(collage: model.collage, selected: model.selected)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            if drag == nil {
                                let cells = model.collage.geometry(size).cells
                                guard let index = cells.firstIndex(where: { $0.contains(value.startLocation) }) else { return }
                                model.selected = index; drag = (index, model.collage.photos[index], cells[index].boundingBoxOfPath)
                            }
                            guard let drag else { return }
                            let place = model.collage.placement(drag.photo, in: drag.box)
                            let dx = place.width - drag.box.width, dy = place.height - drag.box.height
                            model.collage.photos[drag.index].x = dx > 0 ? min(1, max(0, drag.photo.x - value.translation.width / dx)) : 0.5
                            model.collage.photos[drag.index].y = dy > 0 ? min(1, max(0, drag.photo.y - value.translation.height / dy)) : 0.5
                        }.onEnded { _ in drag = nil })
                        .accessibilityLabel(t("Khung ghép ảnh", "Photo collage"))
                        .accessibilityHint(t("Chọn ảnh bên dưới để điều chỉnh vị trí và zoom.", "Select a photo below to adjust position and zoom."))
                }.aspectRatio(model.collage.ratio, contentMode: .fit)
                Text(t("Chạm để chọn · Kéo để căn ảnh", "Tap to select · Drag to crop")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var photoPicker: some View {
        PhotosPicker(selection: $items, maxSelectionCount: max(1, 24 - model.collage.photos.count), matching: .images) {
            Label(t("Thêm ảnh", "Add photos"), systemImage: "plus")
        }.buttonStyle(.borderedProminent).disabled(model.collage.photos.count >= 24)
    }
    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(t("Ảnh của bạn", "Your photos")).font(.headline); Spacer(); Text("\(model.collage.photos.count)/24").foregroundStyle(.secondary); photoPicker }
            Text(t("Tối đa 30 MB/ảnh · Phiên chỉnh sửa không lưu sau khi đóng app", "Up to 30 MB/photo · Editing session is not saved after closing the app")).font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(model.collage.photos.enumerated()), id: \.element.id) { index, photo in
                        Button { model.selected = index } label: {
                            Image(uiImage: photo.image).resizable().scaledToFill().frame(width: 64, height: 64).clipped()
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(index == model.selected ? Color.accentColor : .clear, lineWidth: 3))
                        }.accessibilityLabel("\(t("Ảnh", "Photo")) \(index + 1)").accessibilityAddTraits(index == model.selected ? .isSelected : [])
                    }
                }.padding(3)
            }
            if selected {
                HStack {
                    Button { model.move(-1) } label: { Label(t("Trước", "Previous"), systemImage: "arrow.left") }.disabled(model.selected == 0)
                    Button { model.move(1) } label: { Label(t("Sau", "Next"), systemImage: "arrow.right") }.disabled(model.selected == model.collage.photos.count - 1)
                    Spacer()
                    Button(role: .destructive) {
                        model.remove()
                    } label: { Image(systemName: "trash").accessibilityLabel(t("Xóa ảnh", "Remove photo")) }
                }.buttonStyle(.bordered).font(.caption)
            }
        }
    }
    private var ratioControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Tỷ lệ", "Ratio")).font(.headline)
            ScrollView(.horizontal) {
                HStack { ForEach(ratios, id: \.0) { label, value in
                    Button(label) { model.collage.ratio = value; model.resetCrops() }
                        .buttonStyle(.bordered).tint(abs(model.collage.ratio-value) < 0.0001 ? .accentColor : .secondary)
                } }
            }
            HStack {
                TextField(t("Rộng", "Width"), text: $width).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityLabel(t("Rộng", "Width"))
                Text(":")
                TextField(t("Cao", "Height"), text: $height).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityLabel(t("Cao", "Height"))
                Button(t("Áp dụng", "Apply")) {
                    guard let w = Double(width.replacingOccurrences(of: ",", with: ".")), let h = Double(height.replacingOccurrences(of: ",", with: ".")),
                          (1...100).contains(w), (1...100).contains(h), (0.2...5).contains(w/h) else {
                        model.error = t("Nhập hai số 1–100, tỷ lệ từ 1:5 đến 5:1.", "Enter values from 1–100, with a ratio from 1:5 to 5:1."); return
                    }
                    model.collage.ratio = w/h; model.resetCrops()
                }.buttonStyle(.bordered)
            }
        }
    }
    private var layoutControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Bố cục", "Layout")).font(.headline)
            Picker(t("Nhóm bố cục", "Layout category"), selection: $category) {
                Text(t("Tất cả", "All")).tag("all"); Text(t("Cổ điển", "Classic")).tag("classic"); Text(t("Sáng tạo", "Creative")).tag("creative")
            }.pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                ForEach(GeometryBridge.layouts().filter { category == "all" || $0["category"] == category }, id: \.["id"]) { item in
                    Button {
                        model.collage.layout = item["id"]!; model.resetCrops()
                    } label: {
                        VStack(spacing: 6) {
                            Canvas { context, size in
                                var sample = Collage(); sample.layout = item["id"]!; sample.ratio = model.collage.ratio; sample.border = 90
                                sample.photos = Array(repeating: Photo(image: UIImage()), count: max(4, model.collage.photos.count))
                                for path in sample.geometry(size).cells { context.fill(Path(path), with: .foreground) }
                            }.frame(height: 48)
                            Text(item[language] ?? "").font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                        }.padding(8).background(model.collage.layout == item["id"] ? Color.accentColor.opacity(0.14) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityAddTraits(model.collage.layout == item["id"] ? .isSelected : [])
                }
            }
        }
    }
    private var adjustmentControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Tinh chỉnh", "Adjust")).font(.headline)
            if selected {
                Text("\(t("Ảnh", "Photo")) \(model.selected + 1) · \(Int(model.collage.photos[model.selected].zoom * 100))%")
                Slider(value: cropBinding(\.zoom), in: 1...4).accessibilityLabel(t("Zoom ảnh", "Photo zoom"))
                Text(t("Vị trí ngang", "Horizontal position")).font(.caption)
                Slider(value: cropBinding(\.x), in: 0...1).accessibilityLabel(t("Vị trí ngang", "Horizontal position"))
                Text(t("Vị trí dọc", "Vertical position")).font(.caption)
                Slider(value: cropBinding(\.y), in: 0...1).accessibilityLabel(t("Vị trí dọc", "Vertical position"))
                Button(t("Đặt lại ảnh", "Reset photo")) {
                    model.collage.photos[model.selected].x = 0.5; model.collage.photos[model.selected].y = 0.5; model.collage.photos[model.selected].zoom = 1
                }
            }
            HStack { Text(t("Độ dày khung", "Frame thickness")); Spacer(); Text("\(Int(model.collage.border)) px").monospacedDigit() }
            Slider(value: $model.collage.border, in: 0...120).accessibilityLabel(t("Độ dày khung", "Frame thickness"))
            Text(t("Khung tự giảm độ dày khi cần để giữ đủ ảnh.", "Thickness is reduced when needed to keep all photos visible.")).font(.caption).foregroundStyle(.secondary)
            ColorPicker(t("Màu khung", "Frame color"), selection: Binding(get: { Color(uiColor: model.collage.color) }, set: { model.collage.color = UIColor($0) }), supportsOpacity: false)
        }
    }
    private func cropBinding(_ key: WritableKeyPath<Photo, Double>) -> Binding<Double> {
        Binding(get: { selected ? model.collage.photos[model.selected][keyPath: key] : 1 }, set: { if selected { model.collage.photos[model.selected][keyPath: key] = $0 } })
    }
    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Xuất ảnh", "Export")).font(.headline)
            Picker(t("Định dạng", "Format"), selection: $png) { Text("PNG").tag(true); Text("JPG").tag(false) }.pickerStyle(.segmented)
            Button { Task { await model.export(png: png, vi: vi) } } label: {
                Label(t("Xuất và chia sẻ ảnh 4K", "Export and share 4K image"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.collage.photos.isEmpty)
        }
    }
}
