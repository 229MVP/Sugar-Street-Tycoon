class_name MatchBoard
extends Control
## Owns the dessert grid: generation, swaps, cascades, gravity, refill, reshuffle.

signal board_stable
signal pieces_cleared(cleared_types: Dictionary, score_delta: int, cascade_index: int)
signal swap_resolved(was_valid: bool)
signal input_lock_changed(locked: bool)
signal reshuffled

const MAX_GENERATION_ATTEMPTS := 80
const MAX_RESHUFFLE_ATTEMPTS := 40

@export var piece_scene: PackedScene
@export var level_config: LevelConfig

var columns: int = 8
var rows: int = 8
var cell_size: float = 72.0

## grid[row][col] -> DessertPiece or null
var grid: Array = []

var _input_locked: bool = false
var _selected: DessertPiece = null
var _piece_types: Array[PieceType] = []
var _rng := RandomNumberGenerator.new()
var _board_origin: Vector2 = Vector2.ZERO
var _resolving: bool = false

@onready var _pieces_root: Control = $PiecesRoot
@onready var _board_background: Panel = $BoardBackground


func _ready() -> void:
	add_to_group("match_board")
	_rng.randomize()
	resized.connect(_on_resized)
	# GameController owns level start; only auto-setup if used standalone.
	if level_config != null and get_tree().get_first_node_in_group("game_controller") == null:
		call_deferred("setup_from_config", level_config)


func setup_from_config(config: LevelConfig) -> void:
	level_config = config
	if not level_config.validate():
		push_error("MatchBoard: invalid level config — aborting setup.")
		return
	columns = level_config.columns
	rows = level_config.rows
	_piece_types = level_config.piece_types.duplicate()
	_recalculate_layout()
	await generate_board()


func is_input_locked() -> bool:
	return _input_locked


func set_input_locked(locked: bool) -> void:
	if _input_locked == locked:
		return
	_input_locked = locked
	_set_pieces_input(not locked)
	input_lock_changed.emit(locked)


func get_type_grid() -> Array:
	var type_grid: Array = []
	for row in rows:
		var row_arr: Array = []
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			row_arr.append(piece.get_type_id() if piece else &"")
		type_grid.append(row_arr)
	return type_grid


func has_possible_moves() -> bool:
	return SwapValidator.has_possible_move(get_type_grid())


func print_board() -> void:
	var lines: PackedStringArray = []
	lines.append("--- Board %dx%d ---" % [columns, rows])
	for row in rows:
		var cells: PackedStringArray = []
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			cells.append(str(piece.get_type_id()) if piece else "..")
		lines.append(" ".join(cells))
	lines.append("Possible moves: %s" % str(has_possible_moves()))
	print("\n".join(lines))


func generate_board() -> void:
	set_input_locked(true)
	_clear_all_pieces()
	_init_empty_grid()
	var type_grid := _generate_valid_type_grid()
	if type_grid.is_empty():
		push_error("MatchBoard: failed to generate a valid starting board.")
		set_input_locked(false)
		return
	_spawn_pieces_from_type_grid(type_grid)
	set_input_locked(false)
	board_stable.emit()


func force_reshuffle() -> void:
	await _reshuffle_board()


## Attempt an adjacent swap. Returns true when the swap was valid and resolved.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if _input_locked or _resolving:
		return false
	if not _in_bounds(a) or not _in_bounds(b):
		return false
	if not SwapValidator.are_adjacent(a, b):
		return false
	var piece_a: DessertPiece = grid[a.y][a.x]
	var piece_b: DessertPiece = grid[b.y][b.x]
	if piece_a == null or piece_b == null:
		return false

	set_input_locked(true)
	_clear_selection()

	var type_grid := get_type_grid()
	var valid := SwapValidator.would_create_match(type_grid, a, b)

	_swap_grid_cells(a, b)
	await _animate_swap_parallel(piece_a, piece_b)

	if not valid:
		_swap_grid_cells(a, b) # restore logical grid
		await _animate_invalid_return(piece_a, piece_b)
		set_input_locked(false)
		swap_resolved.emit(false)
		return false

	swap_resolved.emit(true)
	await _resolve_cascades()
	if not has_possible_moves():
		await _reshuffle_board()
	set_input_locked(false)
	board_stable.emit()
	return true


func grid_to_world(pos: Vector2i) -> Vector2:
	## Top-left of the cell in board-local coordinates (Control pieces).
	return _board_origin + Vector2(pos.x * cell_size, pos.y * cell_size)


# ---------------------------------------------------------------------------
# Cascade resolution
# ---------------------------------------------------------------------------

func _resolve_cascades() -> void:
	_resolving = true
	var cascade_index := 0
	while true:
		var groups := MatchDetector.find_match_groups(grid, columns, rows)
		if groups.is_empty():
			break

		var tiers := MatchDetector.cell_score_tiers(groups)
		var matched_cells: Dictionary = {}
		for cell in tiers.keys():
			matched_cells[cell] = true

		var cleared_types: Dictionary = {}
		var score_delta := 0
		var multiplier := cascade_index + 1

		var pieces_to_clear: Array[DessertPiece] = []
		for cell: Vector2i in matched_cells.keys():
			var piece: DessertPiece = grid[cell.y][cell.x]
			if piece == null:
				continue
			var type_id := piece.get_type_id()
			cleared_types[type_id] = int(cleared_types.get(type_id, 0)) + 1
			var run_size: int = tiers[cell]
			score_delta += _points_for_run_size(run_size) * multiplier
			pieces_to_clear.append(piece)
			grid[cell.y][cell.x] = null

		pieces_cleared.emit(cleared_types, score_delta, cascade_index)

		var clear_duration := 0.0
		for piece in pieces_to_clear:
			clear_duration = maxf(clear_duration, piece.play_clear())
		if clear_duration > 0.0:
			await get_tree().create_timer(clear_duration).timeout
		for piece in pieces_to_clear:
			if is_instance_valid(piece):
				piece.queue_free()

		await _apply_gravity_and_refill()
		cascade_index += 1

	_resolving = false


func _apply_gravity_and_refill() -> void:
	var fall_moves := BoardGravity.apply_gravity(grid, columns, rows)
	var fall_duration := 0.0
	for move in fall_moves:
		var piece: DessertPiece = move["piece"]
		var to: Vector2i = move["to"]
		fall_duration = maxf(
			fall_duration,
			piece.move_to(grid_to_world(to), DessertPiece.ANIM_FALL, Tween.TRANS_QUAD, Tween.EASE_IN)
		)
	if fall_duration > 0.0:
		await get_tree().create_timer(fall_duration).timeout

	var empties := BoardGravity.find_empty_cells(grid, columns, rows)
	var col_spawn_index: Dictionary = {}
	var spawn_duration := 0.0
	for empty in empties:
		var pos: Vector2i = empty["pos"]
		var type := _pick_refill_type(pos)
		var piece := _create_piece(type, pos)
		grid[pos.y][pos.x] = piece
		var idx := int(col_spawn_index.get(pos.x, 0))
		col_spawn_index[pos.x] = idx + 1
		var start := grid_to_world(Vector2i(pos.x, -1 - idx))
		var end := grid_to_world(pos)
		spawn_duration = maxf(spawn_duration, piece.play_spawn_from(start, end))
	if spawn_duration > 0.0:
		await get_tree().create_timer(spawn_duration).timeout


func _points_for_run_size(run_size: int) -> int:
	if run_size >= 5:
		return 200
	if run_size == 4:
		return 150
	return 100


# ---------------------------------------------------------------------------
# Generation / reshuffle
# ---------------------------------------------------------------------------

func _reshuffle_board() -> void:
	set_input_locked(true)
	print("MatchBoard: no moves — reshuffling.")
	var ids: Array[StringName] = []
	for row in rows:
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			if piece:
				ids.append(piece.get_type_id())

	var new_grid: Array = []
	for _attempt in MAX_RESHUFFLE_ATTEMPTS:
		# Fisher-Yates via Array.shuffle
		var shuffled := ids.duplicate()
		shuffled.shuffle()
		new_grid = _ids_to_type_grid(shuffled)
		if SwapValidator.has_any_match(new_grid):
			new_grid = []
			continue
		if SwapValidator.has_possible_move(new_grid):
			break
		new_grid = []

	if new_grid.is_empty():
		push_warning("MatchBoard: reshuffle of existing pieces failed; regenerating.")
		new_grid = _generate_valid_type_grid()

	for row in rows:
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				continue
			var type_id: StringName = new_grid[row][col]
			var type := _find_piece_type(type_id)
			piece.setup(type, Vector2i(col, row), cell_size)
			piece.scale = Vector2.ONE * 0.7
			var tween := piece.create_tween()
			tween.tween_property(piece, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.18).timeout
	reshuffled.emit()
	print("MatchBoard: reshuffle complete. Moves exist: %s" % str(has_possible_moves()))


func _generate_valid_type_grid() -> Array:
	for _attempt in MAX_GENERATION_ATTEMPTS:
		var type_grid := _fill_random_without_matches()
		if SwapValidator.has_possible_move(type_grid):
			return type_grid
	push_warning("MatchBoard: generation exceeded attempts; forcing board with moves.")
	for _i in 200:
		var type_grid := _fill_random_without_matches()
		if SwapValidator.has_possible_move(type_grid):
			return type_grid
	return []


func _fill_random_without_matches() -> Array:
	var type_grid: Array = []
	for row in rows:
		var row_arr: Array = []
		for col in columns:
			var forbidden: Array[StringName] = []
			if col >= 2 and row_arr[col - 1] == row_arr[col - 2]:
				forbidden.append(row_arr[col - 1])
			if row >= 2 and type_grid[row - 1][col] == type_grid[row - 2][col]:
				forbidden.append(type_grid[row - 1][col])
			row_arr.append(_random_piece_id_excluding(forbidden))
		type_grid.append(row_arr)
	return type_grid


func _pick_refill_type(pos: Vector2i) -> PieceType:
	var forbidden: Array[StringName] = []
	if pos.x >= 2:
		var left1: DessertPiece = grid[pos.y][pos.x - 1]
		var left2: DessertPiece = grid[pos.y][pos.x - 2]
		if left1 and left2 and left1.get_type_id() == left2.get_type_id():
			forbidden.append(left1.get_type_id())
	if pos.y <= rows - 3:
		var down1: DessertPiece = grid[pos.y + 1][pos.x]
		var down2: DessertPiece = grid[pos.y + 2][pos.x]
		if down1 and down2 and down1.get_type_id() == down2.get_type_id():
			forbidden.append(down1.get_type_id())
	return _find_piece_type(_random_piece_id_excluding(forbidden))


func _spawn_pieces_from_type_grid(type_grid: Array) -> void:
	for row in rows:
		for col in columns:
			var type_id: StringName = type_grid[row][col]
			var piece := _create_piece(_find_piece_type(type_id), Vector2i(col, row))
			piece.position = grid_to_world(Vector2i(col, row))
			grid[row][col] = piece


# ---------------------------------------------------------------------------
# Piece factory / helpers
# ---------------------------------------------------------------------------

func _create_piece(type: PieceType, pos: Vector2i) -> DessertPiece:
	var piece: DessertPiece
	if piece_scene != null:
		piece = piece_scene.instantiate() as DessertPiece
	else:
		piece = _make_runtime_piece()
	_pieces_root.add_child(piece)
	piece.setup(type, pos, cell_size)
	piece.selected.connect(_on_piece_selected)
	piece.drag_released.connect(_on_piece_drag_released)
	piece.input_enabled = not _input_locked
	return piece


func _make_runtime_piece() -> DessertPiece:
	var piece := DessertPiece.new()
	var sprite := TextureRect.new()
	sprite.name = "TextureRect"
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.add_child(sprite)
	var label := Label.new()
	label.name = "FallbackLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	piece.add_child(label)
	return piece


func _on_piece_selected(piece: DessertPiece) -> void:
	if _input_locked or _resolving:
		return
	if _selected == null:
		_selected = piece
		piece.set_selected(true)
		return
	if _selected == piece:
		return
	var a: Vector2i = _selected.grid_pos
	var b: Vector2i = piece.grid_pos
	if SwapValidator.are_adjacent(a, b):
		var from: Vector2i = a
		var to: Vector2i = b
		_clear_selection()
		try_swap(from, to)
	else:
		_selected.set_selected(false)
		_selected = piece
		piece.set_selected(true)


func _on_piece_drag_released(piece: DessertPiece, direction: Vector2i) -> void:
	if _input_locked or _resolving:
		return
	var target := piece.grid_pos + direction
	if not _in_bounds(target):
		return
	_clear_selection()
	try_swap(piece.grid_pos, target)


func _clear_selection() -> void:
	if _selected:
		_selected.set_selected(false)
		_selected = null


func _swap_grid_cells(a: Vector2i, b: Vector2i) -> void:
	var piece_a: DessertPiece = grid[a.y][a.x]
	var piece_b: DessertPiece = grid[b.y][b.x]
	grid[a.y][a.x] = piece_b
	grid[b.y][b.x] = piece_a
	if piece_a:
		piece_a.grid_pos = b
	if piece_b:
		piece_b.grid_pos = a


func _animate_swap_parallel(piece_a: DessertPiece, piece_b: DessertPiece) -> void:
	piece_a.move_to(grid_to_world(piece_a.grid_pos), DessertPiece.ANIM_SWAP, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	piece_b.move_to(grid_to_world(piece_b.grid_pos), DessertPiece.ANIM_SWAP, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await get_tree().create_timer(DessertPiece.ANIM_SWAP).timeout


func _animate_invalid_return(piece_a: DessertPiece, piece_b: DessertPiece) -> void:
	piece_a.move_to(grid_to_world(piece_a.grid_pos), DessertPiece.ANIM_INVALID, Tween.TRANS_BACK, Tween.EASE_OUT)
	piece_b.move_to(grid_to_world(piece_b.grid_pos), DessertPiece.ANIM_INVALID, Tween.TRANS_BACK, Tween.EASE_OUT)
	await get_tree().create_timer(DessertPiece.ANIM_INVALID).timeout


func _clear_all_pieces() -> void:
	if _pieces_root:
		for child in _pieces_root.get_children():
			child.queue_free()
	grid.clear()
	_selected = null


func _init_empty_grid() -> void:
	grid.clear()
	for _row in rows:
		var row_arr: Array = []
		row_arr.resize(columns)
		row_arr.fill(null)
		grid.append(row_arr)


func _ids_to_type_grid(ids: Array) -> Array:
	var type_grid: Array = []
	var i := 0
	for _row in rows:
		var row_arr: Array = []
		for _col in columns:
			row_arr.append(ids[i])
			i += 1
		type_grid.append(row_arr)
	return type_grid


func _find_piece_type(type_id: StringName) -> PieceType:
	for piece_type in _piece_types:
		if piece_type != null and piece_type.id == type_id:
			return piece_type
	push_error("MatchBoard: unknown piece type '%s'" % str(type_id))
	return _piece_types[0] if not _piece_types.is_empty() else null


func _random_piece_type() -> PieceType:
	return _piece_types[_rng.randi_range(0, _piece_types.size() - 1)]


func _random_piece_id_excluding(forbidden: Array[StringName]) -> StringName:
	var options: Array[PieceType] = []
	for piece_type in _piece_types:
		if piece_type == null:
			continue
		if forbidden.has(piece_type.id):
			continue
		options.append(piece_type)
	if options.is_empty():
		return _random_piece_type().id
	return options[_rng.randi_range(0, options.size() - 1)].id


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < columns and pos.y < rows


func _set_pieces_input(enabled: bool) -> void:
	if not _pieces_root:
		return
	for child in _pieces_root.get_children():
		if child is DessertPiece:
			(child as DessertPiece).input_enabled = enabled


func _recalculate_layout() -> void:
	var padding := 12.0
	var avail_w := maxf(size.x - padding * 2.0, 64.0)
	var avail_h := maxf(size.y - padding * 2.0, 64.0)
	cell_size = minf(avail_w / float(columns), avail_h / float(rows))
	var board_w := cell_size * columns
	var board_h := cell_size * rows
	_board_origin = Vector2((size.x - board_w) * 0.5, (size.y - board_h) * 0.5)

	if _board_background:
		_board_background.position = _board_origin - Vector2(8, 8)
		_board_background.size = Vector2(board_w + 16, board_h + 16)

	# Reposition existing pieces after resize.
	if grid.size() == rows:
		for row in rows:
			for col in columns:
				var piece: DessertPiece = grid[row][col]
				if piece:
					piece.cell_size = cell_size
					piece.refresh_layout()
					piece.snap_to(grid_to_world(Vector2i(col, row)))


func _on_resized() -> void:
	_recalculate_layout()
