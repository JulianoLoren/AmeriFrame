import SwiftUI

struct EditorView: View {
    @StateObject private var model = EditorModel()
    @AppStorage("language") private var language = "vi"
    @AppStorage("theme") private var theme = "system"
    @State private var png = true
    @State private var width = "1"
    @State private var height = "1"
    @State private var category = "all"
    private var vi: Bool { language == "vi" }
    private func t(_ v: String, _ e: String) -> String { vi ? v : e }
    private var selected: Bool { model.collage.photos.indices.contains(model.selected) }
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(t("Ghép khoảnh khắc của bạn.", "Bring your moments together.")).font(.title.bold())
                    Text(t("Ảnh chỉ ở trên thiết bị · Không watermark", "On-device processing · No watermark")).font(.caption).foregroundStyle(.secondary)
                    photoControls
                    ratioControls
                    layoutControls
                    adjustControls
                    exportControls
                }.padding(20)
            }.frame(minWidth: 320, idealWidth: 360, maxWidth: 430)
            VStack(spacing: 12) {
                HStack { Text(t("BẢN XEM TRƯỚC", "LIVE PREVIEW")); Spacer(); Text("\(Int(model.collage.outputSize.width)) × \(Int(model.collage.outputSize.height)) px") }.font(.caption).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    let w = min(proxy.size.width, proxy.size.height * model.collage.ratio)
                    let size = CGSize(width: w, height: w/model.collage.ratio)
                    ZStack {
                        if model.collage.photos.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 52))
                                Text(t("Thêm hoặc kéo ảnh vào đây", "Add photos or drop them here")).font(.title2)
                                Button(t("Thêm ảnh", "Add photos")) { model.choosePhotos(vi: vi) }.buttonStyle(.borderedProminent)
                            }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            CollagePreview(collage: model.collage, selected: model.selected, enabled: !model.busy) { index, photo in
                                guard !model.busy, model.collage.photos.indices.contains(index), model.collage.photos[index].id == photo.id else { return }
                                model.selected = index; model.collage.photos[index] = photo
                            }
                            .frame(width: size.width, height: size.height)
                        }
                    }.frame(width: proxy.size.width, height: proxy.size.height)
                }
                Text(t("Kéo để căn ảnh · Lăn chuột / Chụm hai ngón để zoom", "Drag to crop · Scroll / Pinch to zoom")).font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(minWidth: 440).background(Color(nsColor: .underPageBackgroundColor))
        }
        .dropDestination(for: URL.self) { urls, _ in Task { await model.load(urls, vi: vi) }; return !model.busy }
        .navigationTitle("Mosaic")
        .toolbar {
            Button { model.choosePhotos(vi: vi) } label: { Label(t("Thêm ảnh", "Add photos"), systemImage: "plus") }.keyboardShortcut("o")
            Button { model.save(png: png, vi: vi) } label: { Label(t("Xuất ảnh", "Export"), systemImage: "square.and.arrow.up") }.keyboardShortcut("s").disabled(model.collage.photos.isEmpty)
            Picker(t("Ngôn ngữ", "Language"), selection: $language) { Text("VI").tag("vi"); Text("EN").tag("en") }.frame(width: 90)
            Picker(t("Giao diện", "Theme"), selection: $theme) { Text(t("Hệ thống", "System")).tag("system"); Text(t("Sáng", "Light")).tag("light"); Text(t("Tối", "Dark")).tag("dark") }.frame(width: 145)
        }
        .disabled(model.busy)
        .overlay { if model.busy { ProgressView(t("Đang xử lý…", "Processing…")).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .alert(t("Thông báo", "Notice"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
        .preferredColorScheme(theme == "system" ? nil : theme == "dark" ? .dark : .light)
    }
    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(t("Ảnh của bạn", "Your photos")).font(.headline); Spacer(); Text("\(model.collage.photos.count)/24") }
            Button(t("Thêm ảnh…", "Add photos…")) { model.choosePhotos(vi: vi) }.disabled(model.collage.photos.count >= 24)
            Text(t("Tối đa 30 MB/ảnh · Phiên chỉnh sửa không lưu khi đóng app", "Up to 30 MB/photo · Sessions are not restored after closing")).font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack { ForEach(Array(model.collage.photos.enumerated()), id: \.element.id) { i, p in
                    Button { model.selected = i } label: {
                        Image(decorative: p.image, scale: 1).resizable().scaledToFill().frame(width: 58, height: 58).clipped()
                            .overlay(Rectangle().stroke(i == model.selected ? Color.accentColor : .clear, lineWidth: 3))
                    }.buttonStyle(.plain).help(p.name).accessibilityLabel("\(t("Ảnh", "Photo")) \(i+1)")
                } }.padding(3)
            }
            if selected { HStack {
                Button("←") { model.move(-1) }.disabled(model.selected == 0).help(t("Đổi với ảnh trước", "Swap with previous"))
                Button("→") { model.move(1) }.disabled(model.selected == model.collage.photos.count-1).help(t("Đổi với ảnh sau", "Swap with next"))
                Spacer(); Button(t("Xóa ảnh", "Remove photo"), role: .destructive) { model.remove() }
            } }
        }
    }
    private var ratioControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider(); Text(t("Tỷ lệ", "Ratio")).font(.headline)
            HStack { ForEach(["1:1", "4:5", "3:2", "9:16", "16:9"], id: \.self) { label in
                Button(label) { let v = label.split(separator: ":").map { Double($0)! }; model.collage.ratio = v[0]/v[1]; model.resetCrops() }
            } }
            HStack {
                TextField(t("Rộng", "Width"), text: $width); Text(":"); TextField(t("Cao", "Height"), text: $height)
                Button(t("Áp dụng", "Apply")) {
                    guard let w = Double(width.replacingOccurrences(of: ",", with: ".")), let h = Double(height.replacingOccurrences(of: ",", with: ".")), (1...100).contains(w), (1...100).contains(h), (0.2...5).contains(w/h) else {
                        model.message = t("Nhập số 1–100, tỷ lệ từ 1:5 đến 5:1.", "Enter 1–100, with a ratio from 1:5 to 5:1."); return
                    }
                    model.collage.ratio = w/h; model.resetCrops()
                }
            }
        }
    }
    private var layoutControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider(); Text(t("Bố cục", "Layout")).font(.headline)
            Picker(t("Nhóm", "Category"), selection: $category) { Text(t("Tất cả", "All")).tag("all"); Text(t("Cổ điển", "Classic")).tag("classic"); Text(t("Sáng tạo", "Creative")).tag("creative") }.pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))]) {
                ForEach(GeometryBridge.layouts().filter { category == "all" || $0["category"] == category }, id: \.["id"]) { item in
                    Button { model.collage.layout = item["id"]!; model.resetCrops() } label: {
                        VStack {
                            Canvas { context, size in
                                var sample = model.collage; sample.layout = item["id"]!; sample.border = 70
                                for path in sample.geometry(size, count: max(4, model.collage.photos.count)) { context.fill(Path(path), with: .foreground) }
                            }.frame(height: 40)
                            Text(item[language] ?? "").font(.caption).lineLimit(1)
                        }.padding(7).background(model.collage.layout == item["id"] ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var adjustControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider(); Text(t("Tinh chỉnh", "Adjust")).font(.headline)
            if selected {
                Text("\(t("Ảnh", "Photo")) \(model.selected+1) · \(Int(model.collage.photos[model.selected].zoom*100))%")
                Slider(value: crop(\.zoom), in: 1...4) { Text(t("Zoom ảnh", "Photo zoom")) }
                Slider(value: crop(\.x), in: 0...1) { Text(t("Ngang", "Horizontal")) }
                Slider(value: crop(\.y), in: 0...1) { Text(t("Dọc", "Vertical")) }
                Button(t("Đặt lại ảnh", "Reset photo")) { model.collage.photos[model.selected].x = 0.5; model.collage.photos[model.selected].y = 0.5; model.collage.photos[model.selected].zoom = 1 }
            }
            Text("\(t("Độ dày khung", "Frame thickness")): \(Int(model.collage.border)) px")
            Slider(value: $model.collage.border, in: 0...120)
            Text(t("Độ dày tự giảm khi cần để giữ đủ ảnh.", "Thickness is reduced when needed to keep every photo visible.")).font(.caption).foregroundStyle(.secondary)
            ColorPicker(t("Màu khung", "Frame color"), selection: Binding(get: { Color(nsColor: model.collage.color) }, set: { model.collage.color = NSColor($0) }), supportsOpacity: false)
        }
    }
    private func crop(_ key: WritableKeyPath<Photo, Double>) -> Binding<Double> {
        Binding(get: { selected ? model.collage.photos[model.selected][keyPath: key] : 1 }, set: { if selected { model.collage.photos[model.selected][keyPath: key] = $0 } })
    }
    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider(); Picker(t("Định dạng", "Format"), selection: $png) { Text("PNG").tag(true); Text("JPG").tag(false) }.pickerStyle(.segmented)
            Button(t("Lưu ảnh 4K…", "Save 4K image…")) { model.save(png: png, vi: vi) }.buttonStyle(.borderedProminent).disabled(model.collage.photos.isEmpty)
            if let url = model.lastExport {
                HStack { Button(t("Hiện trong Finder", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }; ShareLink(item: url) }
            }
        }
    }
}
