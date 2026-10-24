{ pkgs, mkNodeApp }:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix { inherit pkgs; }) check expectThrows;

  fixture = ./fixtures/npm;
  derivationSource = pkgs.runCommand "source-derivation" { } "mkdir -p $out";

  appWithSource =
    src:
    mkNodeApp {
      inherit src;
      packageManager = "npm";
      depsHash = lib.fakeHash;
    };

  appDrvPath = src: (appWithSource src).drvPath;
in
{
  source-path-passes-through = check "source-path-passes-through" (
    builtins.toString (appWithSource fixture).src == builtins.toString fixture
  );

  source-derivation-passes-through = check "source-derivation-passes-through" (
    (appWithSource derivationSource).src.drvPath == derivationSource.drvPath
  );

  source-url-string-throws = check "source-url-string-throws" (
    expectThrows (appDrvPath "https://example.com/app.tar.gz")
  );

  source-file-url-string-throws = check "source-file-url-string-throws" (
    expectThrows (appDrvPath "file:///tmp/app.tar.gz")
  );

  source-invalid-type-throws = check "source-invalid-type-throws" (expectThrows (appDrvPath 42));
}
