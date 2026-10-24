# nix-node-build

`src`（ソース）と `depsHash`（依存関係のハッシュ）を渡すだけで、そのリポジトリのロックファイルを見て npm / pnpm / yarn のどれでもビルドする Nix 関数です。flake の `lib` として提供するので、他のリポジトリから入力に追加して使えます。

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

`src` が URL のとき、またはまだストアにない derivation のときは自動判定できないため、`packageManager` の指定が必要です。

## ハッシュの取得

`depsHash` はパッケージマネージャが使う依存キャッシュのハッシュです。まず `nixpkgs.lib.fakeHash` を入れてビルドすると、正しい値がエラーに表示されます。

```nix
depsHash = nixpkgs.lib.fakeHash;
```

```console
$ nix build
...
error: hash mismatch in fixed-output derivation '...-npm-deps.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-zsbwE7tVlaNIQatR0go555QPd8uX++6vVIdQ/pnNStA=
```

`got:` の値を `depsHash` に貼り付けて再ビルドしてください。pnpm / yarn / Yarn Berry でも同じ手順です。

`depsHash` は次の条件で変わります。nixpkgs を更新したら取り直してください。

- パッケージマネージャが違う（npm / pnpm / yarn でそれぞれ別のハッシュ）
- ロックファイルが変わった
- nixpkgs 側のフェッチャ実装が変わった（pnpm の `fetcherVersion` など）

## URL からソースを取得する

`src` に `http(s)://` / `file://` のアーカイブ URL（tar.gz / zip）を渡すと、`srcHash` で固定して取得します。この場合だけ `srcHash` が必要です。

```nix
nix-node-build.lib.${system}.mkNodeApp {
  src = "https://example.com/my-app-1.0.0.tar.gz";
  srcHash = "sha256-...";
  packageManager = "npm";
  depsHash = "sha256-...";
};
```

`srcHash` の取得も同じ手順です。`srcHash = nixpkgs.lib.fakeHash;` で一度ビルドし、エラーに出る `got:` の値を貼り付けます（`fetchzip` のハッシュ = 展開後のツリーのハッシュ）。

パスや derivation を渡す場合、ソースは Nix がストアパスとして固定する（flake input なら `flake.lock`）ため、`srcHash` は不要です。パスと一緒に `srcHash` を渡すとエラーになります。

ローカルのアーカイブを使う場合は、パスを文字列に埋め込むとストア経由で読めます。

```nix
src = "file://${./my-app-1.0.0.tar.gz}";
```

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

CLI として `nix run` したい場合の例です。

```nix
installPhase = ''
  runHook preInstall

  mkdir -p $out/bin $out/lib/node-app
  cp -r . $out/lib/node-app
  makeWrapper ${pkgs.nodejs}/bin/node $out/bin/my-app \
    --add-flags $out/lib/node-app/dist/main.js

  runHook postInstall
'';
nativeBuildInputs = [ pkgs.makeWrapper ];
extraAttrs.meta.mainProgram = "my-app";
```

`nodejs` オプションを変更した場合は、`makeWrapper` に渡す Node.js のパスも合わせてください。

## オプション

| 引数 | デフォルト | 説明 |
| --- | --- | --- |
| `src` | （必須） | ソースのパス、derivation、または `http(s)://` / `file://` の URL 文字列 |
| `depsHash` | `lib.fakeHash` | 依存キャッシュのハッシュ。未設定ならビルドが正しい値を教えてくれる |
| `srcHash` | `null` | URL のときのソースハッシュ。URL 以外では指定しない |
| `packageManager` | `null`（自動判定） | `"npm"` / `"pnpm"` / `"yarn"` / `"yarn-berry"` |
| `pname` | `"node-app"` | パッケージ名 |
| `version` | `"0.0.0"` | バージョン |
| `nodejs` | `pkgs.nodejs` | 使用する Node.js |
| `pnpm` | `pkgs.pnpm` | pnpm を使う場合の pnpm パッケージ |
| `yarn` | `pkgs.yarn` | yarn classic を使う場合の yarn パッケージ |
| `buildScript` | `"build"` | 実行する npm script。`null` ならビルドスクリプトを実行しない |
| `installPhase` | ツリー全体を `$out` にコピー | インストール処理の差し替え |
| `nativeBuildInputs` | `[ ]` | ビルド時に追加する依存（`makeWrapper` など） |
| `buildInputs` | `[ ]` | ビルド時に追加する依存 |
| `yarnBerryMissingHashes` | `null` | Yarn Berry で `patch:` / `git:` 依存がある場合の `missing-hashes.json` |
| `extraAttrs` | `{ }` | 最後に derivation へマージする属性（`meta` / `env` はマージされる） |

`buildScript = null;` を指定するとビルドスクリプトを実行しません（依存のインストールだけ行う場合など）。

## 制約・注意点

- nixpkgs 26.05 で動作確認しています。npm / yarn のフックは nixpkgs 25.05 以降を想定しています（25.05 向けの pnpm フォールバックは未検証）。
- Yarn Berry は Yarn 4 のみ対応です（nixpkgs の `yarn-berry_4` / `yarn-berry_4-fetcher` を使用）。Yarn 3 のプロジェクトは未対応です。
- pnpm は指定した nixpkgs の `pkgs.pnpm` を使います（26.05 では pnpm 11）。`package.json` の `packageManager` フィールド（例: `"packageManager": "pnpm@9.15.9"`）は無視されます。nixpkgs の `pnpmConfigHook` と `fetchPnpmDeps` が pnpm のバージョン自動切り替えを無効化しているため、ビルド中に指定バージョンの pnpm を取りに行って失敗することはありません（`tests/fixtures/pnpm` は pnpm 11 で pnpm 9.15.9 指定のプロジェクトをビルドする検証になっています）。特定の pnpm が必要な場合は `pnpm = pkgs.pnpm_XX;` を指定し、`depsHash` を取り直してください。なお、nixpkgs 26.05 では pnpm 10 が insecure 扱いのため、必要に応じて `permittedInsecurePackages` の設定が要ります。
- `depsHash` は nixpkgs のフェッチャ実装に依存するため、nixpkgs を更新したら取り直してください。
- デフォルトの出力は `node_modules` を含むため大きくなります。`installPhase` で必要なファイルだけを入れるのを推奨します。
- ワークスペース（npm / pnpm / yarn workspaces）は未検証です。pnpm は `extraAttrs.pnpmWorkspaces` と `extraAttrs.pnpmInstallFlags` をフェッチとインストールの両方に渡します。
- `src = ./.` を渡すと、flake の仕様により git 管理下のファイルだけがビルドに含まれます。`node_modules` などは `.gitignore` に入れてください。

## テスト

```console
$ nix flake check
```

npm / pnpm / yarn classic / Yarn Berry / URL ソース / `installPhase` 差し替え のビルドを実行します。テスト用のプロジェクトは `tests/fixtures` にあります。
