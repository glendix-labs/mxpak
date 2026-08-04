[English](README.md) | [Korean](README.ko.md) | **Japanese**

# mxpak

Mendix パッケージ マネージャーと、グローバル キャッシュとハード リンクを備えたワークスペース重複除去ツール。

各ウィジェットを 1 回ダウンロードしてグローバルにキャッシュし、追加のディスク費用なしですべてのプロジェクト間で共有できます。次に、残りの共有アセット (ライブラリ、テーマ リソース) を 1 回のパスで重複排除します。

## 仕組み

mxpak には 2 つの補完的なメカニズムがあり、両方とも `~/.mxpak/store/{sha256}/` の同じコンテンツ アドレス可能ストアによってサポートされています。

1. **`mxp install` — ウィジェット依存関係マネージャー。** Mendix Marketplace から `.mpk` ファイルをダウンロードし、SHA-256 ハッシュによって CAS に保存し、`<project>/widgets/` にハードリンクします。再現性を高めるために、`mxpak.lock` を介してロックされています。
2. **`mxp scan` — ワークスペース重複除去機能。** ワークスペース内のすべてのプロジェクトをスキャンし、`install` が管理しない共有ファイル (`userlib/`/`vendorlib/` の Java ライブラリ、`themesource/` の Mendix 標準テーマ アセット) をハッシュし、重複を単一のハード リンクに置き換えます。 CAS に保存されたコピー。

キャッシュとプロジェクトが別のドライブ上にある場合 (ハード リンクが機能しない場合)、mxpak は自動的に通常のファイル コピーに戻ります。

## インストール

**前提条件** — Erlang/OTP 26+ は `PATH` 上にある必要があります (`escript` コマンドが利用可能)。

- macOS: `brew install erlang`
- Windows: `winget install Erlang.ErlangOTP`
- Linux: `sudo apt-get install erlang` (またはディストリビューションの同等のもの)

### ワンライナー

**macOS / Linux**

```sh
curl -fsSL https://github.com/glendix-labs/mxpak/releases/latest/download/install.sh | sh
```

**Windows (PowerShell)**

```powershell
iwr -useb https://github.com/glendix-labs/mxpak/releases/latest/download/install.ps1 | iex
```

どちらのスクリプトも、`mxp` escript を `~/.mxpak/bin/` (macOS/Linux) または `%USERPROFILE%\.mxpak\bin\` (Windows) に配置します。

**Windows** - インストーラーはディレクトリをユーザー `PATH` に自動的に追加しますが、変更は **新しい** ターミナル ウィンドウでのみ有効になります。同じセッションで `mxp` をすぐに使用するには:

```powershell
$env:PATH = "$env:USERPROFILE\.mxpak\bin;$env:PATH"
mxp --version
```

**macOS / Linux** — シェル rc ファイルにディレクトリを自分で追加します。

```sh
export PATH="$HOME/.mxpak/bin:$PATH"     # add to ~/.zshrc, ~/.bashrc, etc.
mxp --version
```

### トラブルシューティング

- **`escript: ... command not found`** — Erlang/OTP がありません。上記の前提条件手順に従ってインストールし、インストーラーを再実行します。
- **`mxp: command not found` (インストール後)** — 新しいターミナルを開くか、上記のように現在のセッションに PATH を適用します。
- **`undefined function mxpak:main/0`** — 古い escript バンドル。インストーラーを再実行して最新リリースを取得します。

### ソースより

```sh
git clone https://github.com/glendix-labs/mxpak.git
cd mxpak
gleam run -m gleescript    # produces ./mxpak — rename to mxp and place on PATH
```

## 使用法

```
mxp <command> [options]
```

|コマンド |説明 |
|---|---|
| `install [project_root]` |構成からすべてのウィジェットを解決してインストールします (ロック ファイルを推奨) |
| `add <name> --version <v>` |ウィジェットを構成に追加してインストールします |
| `remove <name>` |構成からウィジェットを削除する |
| `update [name]` |ウィジェットを更新します (ロックをクリアし、再解決します) |
| `marketplace [project_root]` | Mendix Marketplace 用のインタラクティブ TUI ブラウザ |
| `outdated [project_root]` |利用可能なアップデートを含むウィジェットをリストする |
| `list [project_root]` |インストールされているウィジェットを一覧表示する |
| `info <name>` |ウィジェットの詳細を表示 |
| `audit [project_root]` |インストールされているすべての `.mpk` ファイルの SHA-256 整合性を確認します。
| `cache clean` |グローバル キャッシュをクリーンアップする |
| `scan [path]` |ワークスペース内のすべてのプロジェクトにわたって `*.mpk`、`*.jar`、および `themesource/**` を重複排除します。
| `status [path]` |プロジェクトごとの重複排除統計とディスク節約量を表示する |

## 構成

プロジェクトの TOML 構成に `[tools.mxpak]` セクションを追加します。

```toml
[tools.mxpak]
mode = "mpk"
widgets_dir = "widgets"

[tools.mxpak.widgets.Badge]
version = "3.2.2"
id = 50325

[tools.mxpak.widgets."com.mendix.widget.web.Datagrid"]
version = "2.22.3"
id = 116540
```

`mxp install` を実行すると、再現可能なビルド用に正確なバージョンと SHA-256 ハッシュを固定するロック ファイル (`mxpak.lock`) が生成されます。

## ワークスペースの重複排除

`mxp scan` は、実行場所に基づいてスキャン対象を自動検出します。

```sh
# Case 1 — inside a single Mendix project (a `*.mpr` is in the directory):
cd ~/Mendix/TSVE4HMC-main
mxp scan         # scans this project only
                 # its assets are absorbed into the global CAS at ~/.mxpak/store/
                 # future scans of any other project automatically dedup against them

# Case 2 — a directory whose immediate children are Mendix projects:
cd ~/Mendix      # contains TSVE4HMC-main/, ChartTest/, Blank/, ...
mxp scan         # scans every Mendix project (every immediate subdir with `*.mpr`)

mxp status       # works the same way (single project or workspace)
```

どちらのケースも一致しない場合 (ここには `*.mpr` がなく、直接の子には何もありません)、`scan` は明確なヒントを表示して終了します。

### デフォルトのルール (ゼロ構成)

`scan` は、そのまま使用できる適切なデフォルトで動作します。セットアップ ファイルは必要ありません。

|ルール |デフォルト値 |
|---|---|
| `include` | `["*.mpk", "*.jar"]` — ウィジェットと Java ライブラリ (`widgets/`、`userlib/`、`vendorlib/`) |
| `include_dirs` | `["themesource"]` — Mendix 標準テーマ モジュール (atlas_core、datawidgets など)。これらのディレクトリの下でスキャンされたすべての拡張子。
| `exclude_dirs` | `["deployment", "javascriptsource", "javasource", "modules", ".mendix-cache", ...]` — アーティファクトとプロジェクト固有のコードをビルドする |

`scan` と `install` は、`~/.mxpak/store/` で同じ CAS を共有します。 `mxp install` 経由でインストールされたウィジェットはすでにキャッシュにハードリンクされているため、それらに対する `scan` は事実上何も行われません。 Mendix Studio Pro が直接配置したウィジェットは、最初の `scan` の CAS に吸収され、それ以降は重複排除されます。

### カスタマイズ

ワークスペースのルートに `.mxpak-workspace.toml` をドロップして、上記のいずれかをオーバーライドします。

```toml
[scan]
include      = ["*.mpk", "*.jar", "*.zip"]
include_dirs = ["themesource", "shared"]
exclude_dirs = [".git", "deployment"]
```

キーが見つからない場合はデフォルトに戻ります。

### 測定された節約量 (16 個の実際の Mendix プロジェクト、合計約 23 GB)

`mxp scan` は、以下のすべてを 1 つのパスでカバーします。

|ターゲット |合計 |重複排除後 |保存済み |比率 |
|---|---|---|---|---|
| `widgets/*.mpk` | 804MB | 533MB | **270 MB** | 33.6% |
| userlib/vendorlib の `*.jar` | 534MB | 222MB | **311 MB** | 58.3% |
| `themesource/**` | 57MB | 15MB | **42 MB** | 74.0% |
| **組み合わせ** | **1,395 MB** | **770 MB** | **623 MB** | **44.7%** |

## ライセンス

[MPL-2.0](LICENCE)
