# Godot + Rust 開発環境 整備手順書

PrincessMate で想定している **Godot 4.x + Rust（GDExtension / [godot-rust / gdext](https://github.com/godot-rust/gdext)）** のローカル開発環境を、先に一通り動かすための手順です。

## 目的

- Godot エディタでプロジェクトを開ける
- Rust でビルドしたネイティブライブラリを GDExtension として読み込み、エディタ起動時にエラーにならない
- 変更後に `cargo build` → Godot で再読み込み（または再起動）のサイクルが回せる

## 前提

- OS: **Windows 10 / 11**（他 OS の場合は `.gdextension` の `libraries` キーを該当プラットフォーム用に追加する）
- 権限: 開発用ツールのインストール（管理者は不要な場合が多い）
- 方針: **Godot のマイナーバージョンと `godot` クレートの `api-4-x` フィーチャを一致させる**（不一致は初期化失敗の典型原因）
- **PrincessMate / 本手順の標準エディタ: Godot 4.6**（`features = ["api-4-6"]` とセットで固定する）

## GDExtension は「プラグイン専用」ではない

聞き慣れない言葉のせいで、**GDExtension = エディタ用プラグイン** と誤解されやすいですが、仕組みとしては **Godot が起動時に読み込むネイティブ拡張（動的ライブラリ）の枠組み** です。エディタ拡張もゲーム本体も、同じ入口を使えます。

**ゲームロジックを Rust で書く**とは、gdext などで次のような型を Rust で実装し、Godot から **通常のノード／スクリプトと同様に** シーンに載せることです。

- `Node` / `Node2D` / `Area2D` などを継承したクラス（`#[derive(GodotClass)]` 等）
- `RefCounted` を継承したデータ用クラス
- `_process` / `_physics_process` / シグナル / プロパティを Rust 側で実装し、エディタでアタッチする

つまり **「プラグイン用の別物」ではなく、GDScript や C# と並ぶロジックの実装言語の一つ** として Rust を置くイメージです。PrincessMate の README が想定している「重い処理やルールを Rust に切り出す」も、この枠組みでそのまま実現できます。

運用上は、UI やレベル組みだけ GDScript に残し、バトルシミュレーションやデータ処理を Rust に寄せる、といった分担がよく取られます（必須ではない）。

## 全体像

```
リポジトリまたは作業ルート/
├── godot/                    # Godot プロジェクト（project.godot 等）
│   ├── project.godot
│   ├── *.gdextension         # GDExtension マニフェスト
│   └── .gdignore             # rust ソースを Godot から隠す（任意だが推奨）
└── rust/                     # Rust ライブラリ（cdylib）
    ├── Cargo.toml
    └── src/lib.rs
```

Godot 側は `.gdextension` で `rust/target/...` の DLL を指す。ビルド成果物のパスはプロジェクト構成に合わせて調整する。

---

## 手順 1: Rust ツールチェイン

1. [rustup](https://rustup.rs/) をインストールし、`rustup default stable` で stable を既定にする。
2. Windows で MSVC ツールチェインを使う場合、**Visual Studio の「C++ によるデスクトップ開発」** または Build Tools で MSVC を入れておく（`x86_64-pc-windows-msvc` が一般的）。
3. ターミナルで次を確認する。

```powershell
rustc -V
cargo -V
```

---

## 手順 2: Godot Engine

1. [Godot 公式](https://godotengine.org/download) から **Godot 4.6** を取得する（ZIP 版で可）。
2. **パッチバージョンも含めチームで揃える**（例: 4.6.x 系）。後述の `Cargo.toml` の **`api-4-6`** と対応する。
3. エディタを起動し、問題なく動作することを確認する。

別マイナー（4.5 など）に下げる場合は、`godot` クレートの **`api-4-5`** 等に必ず合わせ替える。

---

## 手順 3: Godot プロジェクトの作成

1. Godot で「新規プロジェクト」を作成し、作業ルートの `godot/` などに置く。
2. `project.godot` が生成されることを確認する。
3. Rust ソースツリーを Godot のファイルドックから除外したい場合、`rust/` のルートに **空の `.gdignore`** を置く（運用ポリシーに応じて `godot/` 側に置く構成でもよい）。

---

## 手順 4: Rust ライブラリ（ゲーム用 GDExtension / cdylib）

1. 作業ルートでライブラリクレートを作成する。

```powershell
cargo new rust/princess-mate-core --lib
```

（フォルダ名はプロジェクト方針に合わせてよい。以下 `rust/princess-mate-core` を例にする。）

2. `rust/princess-mate-core/Cargo.toml` を編集する。

- `crate-type = ["cdylib"]` を指定する（動的ライブラリとして Godot がロードするため必須）。
- `godot` 依存を追加する。**インストールした Godot のマイナーに対応する `api-4-x` フィーチャ**を付ける。

例（**Godot 4.6** ＋ [crates.io の `godot`](https://crates.io/crates/godot) 0.5 系。パッチは `cargo update` 前に互換を確認する）:

```toml
[package]
name = "princess-mate-core"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
godot = { version = "0.5", features = ["api-4-6"] }
```

※ `api-4-x` と実際の Godot 4.x がずれると、GDExtension 初期化で失敗することがある。公式の [Hello World](https://godot-rust.github.io/book/intro/hello-world.html) の互換表を参照する。  
※ `godot` クレートの新しい版は **MSRV（必要な `rustc` の最低バージョン）が上がる**ことがある。ビルドエラー時は [crates.io の MSRV 表示](https://crates.io/crates/godot) と `rustc -V` を照合する。

3. `src/lib.rs` に、gdext の最小エントリ（`ExtensionLibrary` と `#[gdextension]`）を実装する。公式ブックの Hello World をそのまま写して動作確認してよい。

4. ビルドする。

```powershell
cd rust/princess-mate-core
cargo build
cargo build --release
```

Windows では `rust/princess-mate-core/target/debug/princess_mate_core.dll`（クレート名によりファイル名は変わる）が生成される。

**出力先の固定（推奨）**: 一部の環境では `CARGO_TARGET_DIR` がリポジトリ外を指し、手順 5 の `res://../rust/.../target/...` とパスがずれる。本リポジトリの `rust/princess-mate-core/.cargo/config.toml` で `build.target-dir = "target"` を指定している。手元で別ディレクトリに出力したい場合はその設定を調整し、`.gdextension` のパスと揃える。

---

## 手順 5: `.gdextension` マニフェスト

Godot プロジェクト内（本リポジトリでは `godot/extension/princess_mate_core.gdextension`）にマニフェストを置く。

- `entry_symbol = "gdext_rust_init"`（gdext 既定）
- `compatibility_minimum = "4.6"`（本プロジェクトの Godot バージョンに合わせる）
- `reloadable = true`（エディタがフォーカス復帰時に拡張を再読み込み。不安定なら外す）
- `[libraries]` に **debug / release** と **windows.debug.x86_64** 等で `res://` からの相対パスでネイティブライブラリを指す

パスは **`project.godot` がある `godot/` を基準にした `res://`** で書く。クレートが `rust/princess-mate-core/` のときは `res://../rust/princess-mate-core/target/debug/...` のように **ひとつ上の `rust/` に入ってから** `target/` へ辿る（`godot/` と `rust/` が兄弟であること）。

編集・ビルド後に Godot を開き、**出力 / デバッグコンソールに GDExtension 関連のエラーが出ないこと**を確認する。

---

## 手順 6: エディタ連携（任意）

- **rust-analyzer**: VS Code / Cursor で `rust/` をワークスペースに含める。
- **フォーマット / Clippy**: チームで `rustfmt` と `clippy` の運用を決め、`cargo fmt` / `cargo clippy` を CI または手元で回す。

---

## 完了チェックリスト

| # | 確認内容 |
|---|-----------|
| 1 | `rustc` / `cargo` が動作する |
| 2 | 固定した Godot 4.x が起動する |
| 3 | `cargo build` でエラーなく `cdylib` が生成される |
| 4 | `.gdextension` のパスが実 DLL と一致している |
| 5 | Godot でプロジェクトを開いても GDExtension 初期化エラーが出ない |
| 6 |（任意）Hello World 相当の Rust クラスをノードにアタッチし、実行できる |

---

## トラブルシューティング（よくある原因）

| 現象 | 確認すること |
|------|----------------|
| `gdext_rust_init` 失敗 / API 不一致 | Godot のマイナーと `godot` クレートの `api-4-x` を揃える。Debug/Release の取り違え。 |
| DLL が見つからない | `.gdextension` の `res://` 相対パス、`cargo build` の出力先（debug/release）。 |
| MSVC リンクエラー | Visual Studio C++ ビルドツールが入っているか。 |
| 古い DLL が読まれる | Godot 再起動、または `target` のクリーンビルド。 |

---

## 参照

- [godot-rust book — Hello World](https://godot-rust.github.io/book/intro/hello-world.html)
- [gdext リポジトリ](https://github.com/godot-rust/gdext)
- リポジトリ README の技術スタック: Godot + Rust（GDExtension 想定）、Spine は本手順の後段で足す想定でよい

---

## メモ（PrincessMate 向け）

本リポジトリは現状「企画・基盤整備」段階のため、`rust/` は未配置の場合がある。`godot/` は **4.6** プロジェクトとして置ける。この手順で環境と最小 GDExtension を先に成立させ、その後に本番用クレート名・モジュール分割・Spine 連携を足す流れを推奨する。
