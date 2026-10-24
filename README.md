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
error: hash mismatch in fixed-output derivation '...-npm-deps.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-zsbwE7tVlaNIQatR0go555QPd8uX++6vVIdQ/pnNStA=
```

`got:` の値を `depsHash` に貼り付けて再ビルドしてください。pnpm / yarn / Yarn Berry でも同じ手順です。

`depsHash` は次の条件で変わります。nixpkgs を更新したら取り直してください。

- パッケージマネージャが違う（npm / pnpm / yarn でそれぞれ別のハッシュ）
- ロックファイルが変わった
- nixpkgs 側のフェッチャ実装が変わった（pnpm の `fetcherVersion` など）

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

## オプション

| 引数 | デフォルト | 説明 |
| --- | --- | --- |
| `src` | （必須） | ソースのパスまたは derivation |
| `depsHash` | `lib.fakeHash` | 依存キャッシュのハッシュ。未設定ならビルドが正しい値を教えてくれる |
| `packageManager` | `null`（自動判定） | `"npm"` / `"pnpm"` / `"yarn"` / `"yarn-berry"` |
| `pname` | `"node-app"` | パッケージ名 |
| `version` | `"0.0.0"` | バージョン |
| `nodejs` | `pkgs.nodejs` | 使用する Node.js |
| `pnpm` | `pkgs.pnpm` | pnpm を使う場合の pnpm パッケージ |
| `yarn` | `pkgs.yarn` | yarn classic を使う場合の yarn パッケージ |
| `buildScript` | `"build"` | 実行する npm script。`null` ならビルドスクリプトを実行しない |
| `installPhase` | ツリー全体を `$out` にコピー | インストール処理の差し替え |
| `nativeBuildInputs` | `[ ]` | ビルド時に追加する依存 |
| `buildInputs` | `[ ]` | ビルド時に追加する依存 |
| `yarnBerryMissingHashes` | `null` | Yarn Berry で `patch:` / `git:` 依存がある場合の `missing-hashes.json` |
| `extraAttrs` | `{ }` | 最後に derivation へマージする属性（`meta` / `env` はマージされる） |

`buildScript = null;` を指定するとビルドスクリプトを実行しません（依存のインストールだけ行う場合など）。

## 制約・注意点

- nixpkgs 26.05 で動作確認しています。npm / yarn のフックは nixpkgs 25.05 以降を想定しています（25.05 向けの pnpm フォールバックは未検証）。
- Yarn Berry は Yarn 4 のみ対応です（nixpkgs の `yarn-berry_4` / `yarn-berry_4-fetcher` を使用）。Yarn 3 のプロジェクトは未対応です。
- pnpm は指定した nixpkgs の `pkgs.pnpm` を使います（26.05 では pnpm 11）。`package.json` の `packageManager` フィールド（例: `"packageManager": "pnpm@9.15.9"`）は無視されます。nixpkgs の `pnpmConfigHook` と `fetchPnpmDeps` が pnpm のバージョン自動切り替えを無効化しているため、ビルド中に指定バージョンの pnpm を取りに行って失敗することはありません（`tests/fixtures/pnpm` は pnpm 11 で pnpm 9.15.9 指定のプロジェクトをビルドする検証になっています）。特定の pnpm が必要な場合は `pnpm = pkgs.pnpm_XX;` を指定し、`depsHash` を取り直してください。なお、nixpkgs 26.05 では pnpm 10 が insecure 扱いのため、必要に応じて `permittedInsecurePackages` の設定が要ります。
- `src` が derivation のときの自動判定は、評価時にそのソースをビルドして読みます（import from derivation）。`allow-import-from-derivation = false` では評価できないため、`packageManager` を明示してください。
- ワークスペース（npm / pnpm / yarn workspaces）は未検証です。pnpm は `extraAttrs.pnpmWorkspaces` と `extraAttrs.pnpmInstallFlags` をフェッチとインストールの両方に渡します。

## ライセンス

WTFPL（Do What The Fuck You Want To Public License）。詳細は [LICENSE](LICENSE) を参照してください。
