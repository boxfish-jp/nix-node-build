{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix { inherit pkgs; }) check expectThrows;
  inherit (import ../lib/package_manager { inherit pkgs; }) resolvePackageManager;

  resolve = packageManager: source: resolvePackageManager { inherit packageManager source; };

  emptySource = pkgs.runCommand "empty-source" { } "mkdir -p $out";

  npmShrinkwrapSource = pkgs.runCommand "npm-shrinkwrap-source" { } ''
    cp -r ${./fixtures/npm} $out
    chmod -R u+w $out
    mv $out/package-lock.json $out/npm-shrinkwrap.json
  '';

  multipleLockfilesSource = pkgs.runCommand "multiple-lockfiles-source" { } ''
    cp -r ${./fixtures/npm} $out
    chmod -R u+w $out
    touch $out/pnpm-lock.yaml $out/yarn.lock
  '';
in
{
  package-manager-detects-npm = check "package-manager-detects-npm" (
    resolve null ./fixtures/npm == "npm"
  );

  package-manager-detects-pnpm = check "package-manager-detects-pnpm" (
    resolve null ./fixtures/pnpm == "pnpm"
  );

  package-manager-detects-yarn = check "package-manager-detects-yarn" (
    resolve null ./fixtures/yarn == "yarn"
  );

  package-manager-detects-yarn-berry = check "package-manager-detects-yarn-berry" (
    resolve null ./fixtures/yarn-berry == "yarn-berry"
  );

  package-manager-detects-npm-shrinkwrap = check "package-manager-detects-npm-shrinkwrap" (
    resolve null npmShrinkwrapSource == "npm"
  );

  package-manager-prefers-pnpm-when-multiple-lockfiles-exist =
    check "package-manager-prefers-pnpm-when-multiple-lockfiles-exist"
      (resolve null multipleLockfilesSource == "pnpm");

  package-manager-accepts-explicit-values-without-reading-source =
    check "package-manager-accepts-explicit-values-without-reading-source"
      (
        lib.all (manager: resolve manager (throw "source must not be read") == manager) [
          "npm"
          "pnpm"
          "yarn"
          "yarn-berry"
        ]
      );

  package-manager-without-lockfile-throws = check "package-manager-without-lockfile-throws" (
    expectThrows (resolve null emptySource)
  );

  package-manager-rejects-unknown-value = check "package-manager-rejects-unknown-value" (
    expectThrows (resolve "bun" ./fixtures/npm)
  );
}
