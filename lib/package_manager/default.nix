{ pkgs }:
let
  inherit (pkgs) lib;

  supportedPackageManagers = [
    "npm"
    "pnpm"
    "yarn"
    "yarn-berry"
  ];

  readSourceEntries =
    source:
    let
      root = if builtins.isPath source then source else source.outPath;
    in
    if builtins.pathExists root then builtins.readDir root else null;

  entryExists = entries: name: entries != null && builtins.hasAttr name entries;

  detectPackageManager =
    source:
    let
      entries = readSourceEntries source;
    in
    if entryExists entries "pnpm-lock.yaml" then
      "pnpm"
    else if entryExists entries "yarn.lock" then
      (if entryExists entries ".yarnrc.yml" then "yarn-berry" else "yarn")
    else if entryExists entries "package-lock.json" || entryExists entries "npm-shrinkwrap.json" then
      "npm"
    else
      null;

  resolvePackageManager =
    { packageManager, source }:
    if packageManager != null then
      if builtins.elem packageManager supportedPackageManagers then
        packageManager
      else
        throw "mkNodeApp: unsupported packageManager \"${packageManager}\". Supported values: ${lib.concatStringsSep ", " supportedPackageManagers}."
    else
      let
        detected = detectPackageManager source;
      in
      if detected != null then
        detected
      else
        throw ''
          mkNodeApp: cannot determine the package manager from src.
          Expected one of pnpm-lock.yaml, yarn.lock, package-lock.json, or npm-shrinkwrap.json in the source root (.yarnrc.yml next to yarn.lock selects Yarn Berry).
          Set packageManager = "npm" | "pnpm" | "yarn" | "yarn-berry" explicitly to skip reading the source during evaluation.
        '';
in
{
  inherit resolvePackageManager;
}
