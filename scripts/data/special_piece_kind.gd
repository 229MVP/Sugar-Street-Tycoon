class_name SpecialPieceKind
extends RefCounted
## Match-3 special piece kinds. NONE means a normal dessert tile.

enum Kind {
	NONE,
	LINE_H, ## Clears an entire row when activated.
	LINE_V, ## Clears an entire column when activated.
	BOMB, ## Clears a 3x3 area when activated.
	RAINBOW, ## Clears all tiles of a swapped color when activated.
}


static func is_special(kind: int) -> bool:
	return kind != Kind.NONE


static func label(kind: int) -> String:
	match kind:
		Kind.LINE_H:
			return "═"
		Kind.LINE_V:
			return "║"
		Kind.BOMB:
			return "💣"
		Kind.RAINBOW:
			return "★"
		_:
			return ""
