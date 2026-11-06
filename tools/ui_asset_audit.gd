extends SceneTree
## Auditoria dos PNGs de runtime do UI v5 (prompt de QA).
## Uso: --headless --path . -s tools/ui_asset_audit.gd -- [pasta_do_pacote_v4]
## Para cada PNG: RGBA, cantos transparentes, nenhum pixel visível encostado na
## borda (objeto truncado), margem transparente, tamanho igual ao QA_UI_v5.json
## e número de "ilhas" opacas (fragmentos de peças vizinhas). Com a pasta da v4,
## mede o ganho de largura visível dos três CTAs.

const QA_JSON := "res://docs/references/ui-v5/QA_UI_v5.json"
const CTAS := ["button_cta_green_large.png", "button_cta_orange_large.png", "button_cta_blue_large.png"]

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var v4_dir := args[0] if args.size() > 0 else ""
    var expected := {}
    var qa_text := FileAccess.get_file_as_string(QA_JSON)
    var qa: Variant = JSON.parse_string(qa_text)
    if qa is Array:
        for entry in qa:
            expected[String(entry["file"]).get_file()] = entry
    for path in _runtime_pngs():
        _audit(path, expected)
    if not v4_dir.is_empty():
        for file in CTAS:
            var v5 := _visible_rect(_load_image("res://assets/ui/components/" + file))
            var v4 := _visible_rect(Image.load_from_file(v4_dir.path_join("assets/ui/components/" + file)))
            var gain := (float(v5.size.x) / float(v4.size.x) - 1.0) * 100.0
            var height_change := (float(v5.size.y) / float(v4.size.y) - 1.0) * 100.0
            var ok := absf(gain - 30.0) <= 2.0 and absf(height_change) <= 2.0
            print("CTA_WIDTH %s %s v4_visible=%dx%d v5_visible=%dx%d gain=%.1f%% altura=%.1f%%" % ["OK  " if ok else "FAIL", file, v4.size.x, v4.size.y, v5.size.x, v5.size.y, gain, height_change])
            if not ok:
                failures.append("%s ganho de largura %.1f%%" % [file, gain])
    if failures.is_empty():
        print("UI_ASSET_AUDIT_OK files=%d" % _runtime_pngs().size())
        quit(0)
    else:
        for failure in failures:
            print("UI_ASSET_AUDIT_FAIL ", failure)
        quit(1)

func _runtime_pngs() -> Array[String]:
    var files: Array[String] = []
    for dir in ["res://assets/ui/hud", "res://assets/ui/icons", "res://assets/ui/components", "res://assets/currency"]:
        for file in DirAccess.get_files_at(dir):
            if file.ends_with(".png"):
                files.append(dir + "/" + file)
    return files

func _load_image(path: String) -> Image:
    return Image.load_from_file(ProjectSettings.globalize_path(path))

func _visible_rect(image: Image) -> Rect2i:
    var min_p := Vector2i(image.get_width(), image.get_height())
    var max_p := Vector2i(-1, -1)
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x, y).a > 0.1:
                min_p = Vector2i(mini(min_p.x, x), mini(min_p.y, y))
                max_p = Vector2i(maxi(max_p.x, x), maxi(max_p.y, y))
    return Rect2i(min_p, max_p - min_p + Vector2i.ONE)

func _audit(path: String, expected: Dictionary) -> void:
    var file := path.get_file()
    var image := _load_image(path)
    var problems: Array[String] = []
    var w := image.get_width()
    var h := image.get_height()
    if image.get_format() != Image.FORMAT_RGBA8:
        image.convert(Image.FORMAT_RGBA8)
        if not image.detect_alpha():
            problems.append("sem canal alfa")
    for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
        if image.get_pixelv(corner).a > 0.02:
            problems.append("canto %s opaco" % corner)
            break
    var edge_hits := 0
    for x in w:
        if image.get_pixel(x, 0).a > 0.1 or image.get_pixel(x, h - 1).a > 0.1:
            edge_hits += 1
    for y in h:
        if image.get_pixel(0, y).a > 0.1 or image.get_pixel(w - 1, y).a > 0.1:
            edge_hits += 1
    if edge_hits > 0:
        problems.append("%d pixels visíveis na borda (truncado)" % edge_hits)
    var visible := _visible_rect(image)
    var margin := mini(mini(visible.position.x, visible.position.y), mini(w - visible.end.x, h - visible.end.y))
    if expected.has(file):
        var size: Array = expected[file]["final_png_size"]
        if int(size[0]) != w or int(size[1]) != h:
            problems.append("tamanho %dx%d difere do QA_UI_v5.json %sx%s" % [w, h, size[0], size[1]])
    var islands := _islands(image)
    var status := "OK  " if problems.is_empty() else "FAIL"
    print("ASSET %s %s %dx%d visível=%dx%d margem=%dpx ilhas=%s %s" % [status, path.trim_prefix("res://"), w, h, visible.size.x, visible.size.y, margin, islands, "; ".join(problems)])
    if not problems.is_empty():
        failures.append("%s: %s" % [file, "; ".join(problems)])

## Ilhas opacas (alfa > 0.5) com área >= 0,5% da imagem, em grade reduzida (4 px).
func _islands(image: Image) -> int:
    var step := 4
    var gw := image.get_width() / step
    var gh := image.get_height() / step
    var seen := PackedByteArray()
    seen.resize(gw * gh)
    var count := 0
    var min_cells := maxi(4, int(gw * gh * 0.005))
    for gy in gh:
        for gx in gw:
            var index := gy * gw + gx
            if seen[index] == 1 or image.get_pixel(gx * step, gy * step).a <= 0.5:
                continue
            var stack := [Vector2i(gx, gy)]
            seen[index] = 1
            var cells := 0
            while not stack.is_empty():
                var p: Vector2i = stack.pop_back()
                cells += 1
                for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var q: Vector2i = p + d
                    if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh:
                        continue
                    var qi := q.y * gw + q.x
                    if seen[qi] == 0 and image.get_pixel(q.x * step, q.y * step).a > 0.5:
                        seen[qi] = 1
                        stack.append(q)
            if cells >= min_cells:
                count += 1
    return count
