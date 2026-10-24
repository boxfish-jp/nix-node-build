# nix-node-build

`src`（ソース）と `depsHash`（依存関係のハッシュ）を渡すだけで、そのリポジトリのロックファイルを見て npm / pnpm / yarn のどれでもビルドする Nix 関数です。

- npm（`package-lock.json` / `npm-shrinkwrap.json`）
- pnpm（`pnpm-lock.yaml`）
- yarn classic / Yarn 1（`yarn.lock`）
- Yarn Berry / Yarn 4（`yarn.lock` + `.yarnrc.yml`）

## 使い方

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-node-build.url = "github:YOUR_NAME/nix-node-build";
  };

  outputs = { nixpkgs, nix-node-build, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = nix-node-build.lib.mkNodeApp {
            inherit pkgs;
            src = ./.;
            depsHash = "sha256-...";
          };
        });
    };
}
```

```console
$ nix build
```

自分の `pkgs` を渡さず、この flake が固定している nixpkgs で評価したい場合は `lib.${system}.mkNodeApp` も使えます。その場合は `inputs.nix-node-build.inputs.nixpkgs.follows = "nixpkgs";` を設定すると nixpkgs が二重になりません。

```nix
default = nix-node-build.lib.${system}.mkNodeApp {
  src = ./.;
  depsHash = "sha256-...";
};
```

## パッケージマネージャの決定

`packageManager` を省略すると、`src` 直下のファイルから自動判定します。

| `src` 直下のファイル | 使用するもの |
| --- | --- |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` と `.yarnrc.yml` | Yarn Berry（Yarn 4） |
| `yarn.lock` | yarn classic（Yarn 1） |
| `package-lock.json` または `npm-shrinkwrap.json` | npm |

明示したい場合は `packageManager = "npm" | "pnpm" | "yarn" | "yarn-berry"` を渡してください。

`packageManager` を指定すると自動判定は行いません。`src` が derivation の場合、自動判定は評価時にそのソースをビルドして読むため（import from derivation）、`allow-import-from-derivation = false` の環境では `packageManager` を明示してください。

## ハッシュの取得

`depsHash` はパッケージマネージャが使う依存キャッシュのハッシュです。まず `nixpkgs.lib.fakeHash` を入れてビルドすると、正しい値がエラーに表示されます。

```nix
depsHash = nixpkgs.lib.fakeHash;
```

```console
$ nix build
...
error: hash mismatch in fixed-output derivation '...-node-deps.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-zsbwE7tVlaNIQatR0go555QPd8uX++6vVIdQ/pnNStA=
```

`got:` の値を `depsHash` に貼り付けて再ビルドしてください。pnpm / yarn / Yarn Berry でも同じ手順です。

`depsHash` は次の条件で変わります。nixpkgs を更新したら取り直してください。

- パッケージマネージャが違う（npm / pnpm / yarn でそれぞれ別のハッシュ）
- ロックファイルが変わった
- nixpkgs 側のフェッチャ実装が変わった（pnpm の `fetcherVersion` など）

## モノレポで依存キャッシュを共有する

同じ `src`（同じロックファイル）を複数のパッケージで使う場合、`mkNodeDeps` で依存キャッシュを1つだけ作り、`deps` で各アプリに注入できます。

```nix
outputs = { nixpkgs, nix-node-build, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  in {
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        src = ./.;
        depsHash = "sha256-...";

        deps = nix-node-build.lib.mkNodeDeps {
          inherit pkgs src depsHash;
          packageManager = "pnpm";
        };

        mkApp = pname: nix-node-build.lib.mkNodeApp {
          inherit pkgs src deps pname;
          version = "v1.0.18";
        };
      in {
        cli = mkApp "cli";
        hub = mkApp "hub";
      });
  };
```

- `mkNodeDeps` は `mkNodeApp` と同じく `src` からパッケージマネージャを判定します（`packageManager` で明示も可能）
- `deps` を渡したアプリは依存をフェッチせず、その derivation をそのまま使います。`depsHash` は不要です（実際のハッシュを併用するとエラーになります。デフォルトの `lib.fakeHash` は無視されます）
- `deps` を作ったときのパッケージマネージャとアプリのパッケージマネージャが違う場合もエラーになります
- 実際に使った依存キャッシュは `passthru.deps` から取得できます

`deps` を渡さなくても、同じ `src` と `depsHash` を使うアプリ同士では依存キャッシュが自動で共有されます（フェッチ名を固定しているため）。`deps` は、アプリごとに `depsHash` を二重管理したくない場合や、`mkNodeApp` を評価せずに依存キャッシュだけを取り出したい場合に使ってください。

`lib.${system}.mkNodeDeps` も同じように使えます（`pkgs` は不要です）。

## 出力

`$out` にはビルド後のプロジェクトツリー全体（ソース、`node_modules`、ビルド成果物）が入ります。

```console
$ nix build
$ ls result
build.js  dist  node_modules  package.json  ...
```

必要なものだけを入れたい場合は `installPhase` を差し替えてください。

```nix
installPhase = ''
  runHook preInstall

  mkdir -p $out
  cp -r dist $out/dist

  runHook postInstall
'';
```

## ビルド工程を差し替える

`buildScript` は `package.json` のスクリプト名しか受け取れません。引数付きのコマンドを実行したい場合や、ビルドの前後に処理を挟みたい場合は `buildCommand` / `preBuild` / `postBuild` を使います。

```nix
nix-node-build.lib.mkNodeApp {
  inherit pkgs src depsHash;

  preBuild = ''
    for sqliteDir in node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3; do
      (cd "$sqliteDir" && node-gyp rebuild --release --nodedir=${pkgs.nodejs})
    done
  '';

  buildCommand = "turbo build --filter=cli";

  postBuild = ''
    rm -rf .turbo
  '';
}
```

実行順は `runHook preBuild` → `preBuild` → ビルド → `postBuild` → `runHook postBuild` です。

- `buildCommand` はシェル行としてそのまま実行されます。`npm run` などの前置は付かないので、`turbo build --filter=cli` のような引数付きコマンドや、`&&`・パイプ・リダイレクトを含む行をそのまま書けます
- `buildCommand` を指定すると `buildScript` は無視されます（`buildScript` のデフォルトは `"build"` なので、両方を指定してもエラーにはなりません）
- `preBuild` は依存のインストール後に実行されるため、`node_modules` の中のネイティブモジュールを直接再ビルドできます
- `buildCommand = null` かつ `buildScript = null` のときはビルドコマンドを実行しません（`preBuild` / `postBuild` だけを実行することもできます）
- `extraAttrs.buildPhase` を指定した場合は従来どおり `buildPhase` 全体を上書きします（`buildCommand` / `preBuild` / `postBuild` より優先されます）

## オプション

| 引数 | デフォルト | 説明 |
| --- | --- | --- |
| `src` | （必須） | ソースのパスまたは derivation |
| `depsHash` | `lib.fakeHash` | 依存キャッシュのハッシュ。未設定ならビルドが正しい値を教えてくれる |
| `deps` | `null` | `mkNodeDeps` が返す依存キャッシュ。指定するとフェッチせずに注入する（`depsHash` とは併用しない） |
| `packageManager` | `null`（自動判定） | `"npm"` / `"pnpm"` / `"yarn"` / `"yarn-berry"` |
| `pname` | `"node-app"` | パッケージ名 |
| `version` | `"0.0.0"` | バージョン |
| `nodejs` | `pkgs.nodejs` | 使用する Node.js |
| `pnpm` | `pkgs.pnpm` | pnpm を使う場合の pnpm パッケージ |
| `yarn` | `pkgs.yarn` | yarn classic を使う場合の yarn パッケージ |
| `buildScript` | `"build"` | 実行する npm script。`null` ならビルドスクリプトを実行しない。`buildCommand` を指定した場合は無視される |
| `buildCommand` | `null` | ビルド工程で実行するシェル行。指定すると `buildScript` より優先される（パッケージマネージャの `run` は前置されない） |
| `preBuild` | `""` | ビルドの直前に実行するシェル行 |
| `postBuild` | `""` | ビルドの直後に実行するシェル行 |
| `installPhase` | ツリー全体を `$out` にコピー | インストール処理の差し替え |
| `nativeBuildInputs` | `[ ]` | ビルド時に追加する依存 |
| `buildInputs` | `[ ]` | ビルド時に追加する依存 |
| `yarnBerryMissingHashes` | `null` | Yarn Berry で `patch:` / `git:` 依存がある場合の `missing-hashes.json` |
| `extraAttrs` | `{ }` | 最後に derivation へマージする属性（`meta` / `env` / `passthru` はマージされる） |

`buildScript = null;` を指定するとビルドスクリプトを実行しません（依存のインストールだけ行う場合など）。`buildCommand` を指定した場合は、`buildScript` の値にかかわらず `buildCommand` が実行されます。

`extraAttrs.pnpmDeps` のような依存キャッシュの直接指定も引き続き動きますが、`deps` を使う方が意図が明確です。

## 制約・注意点

- nixpkgs 26.05 で動作確認しています。npm / yarn のフックは nixpkgs 25.05 以降を想定しています（25.05 向けの pnpm フォールバックは未検証）。
- Yarn Berry は Yarn 4 のみ対応です（nixpkgs の `yarn-berry_4` / `yarn-berry_4-fetcher` を使用）。Yarn 3 のプロジェクトは未対応です。
- pnpm は指定した nixpkgs の `pkgs.pnpm` を使います（26.05 では pnpm 11）。`package.json` の `packageManager` フィールド（例: `"packageManager": "pnpm@9.15.9"`）は無視されます。nixpkgs の `pnpmConfigHook` と `fetchPnpmDeps` が pnpm のバージョン自動切り替えを無効化しているため、ビルド中に指定バージョンの pnpm を取りに行って失敗することはありません（`tests/fixtures/pnpm` は pnpm 11 で pnpm 9.15.9 指定のプロジェクトをビルドする検証になっています）。特定の pnpm が必要な場合は `pnpm = pkgs.pnpm_XX;` を指定し、`depsHash` を取り直してください。なお、nixpkgs 26.05 では pnpm 10 が insecure 扱いのため、必要に応じて `permittedInsecurePackages` の設定が要ります。
- `src` が derivation のときの自動判定は、評価時にそのソースをビルドして読みます（import from derivation）。`allow-import-from-derivation = false` では評価できないため、`packageManager` を明示してください。
- ワークスペース（npm / pnpm / yarn workspaces）は未検証です。pnpm は `extraAttrs.pnpmWorkspaces` と `extraAttrs.pnpmInstallFlags` をフェッチとインストールの両方に渡します。
- 依存キャッシュのフェッチ名は固定しています（npm: `node-deps`、pnpm: `node-deps-pnpm-deps`、yarn / Yarn Berry: `offline`）。この名前が変わると既存の依存キャッシュは一度だけ再ビルドになりますが、`depsHash` は内容ベースなので取り直す必要はありません。

## ライセンス

WTFPL（Do What The Fuck You Want To Public License）。詳細は [LICENSE](LICENSE) を参照してください。
