use godot::prelude::*;

struct PrincessMateExtension;

// SAFETY: gdext の `ExtensionLibrary` 契約に従う。本クレートが Godot に登録する唯一のエントリであり、
// GDScript 等エンジン外からの前提は利用側の責任（`ExtensionLibrary` の「Safety」節と同旨）。
#[gdextension]
unsafe impl ExtensionLibrary for PrincessMateExtension {}
