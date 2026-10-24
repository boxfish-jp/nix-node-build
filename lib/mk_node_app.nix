{ pkgs }:
let
  inherit (pkgs) lib;

  supportedPackageManagers = [
    "npm"
    "pnpm"
    "yarn"
    "yarn-berry"
  ];

  isUrl = value: builtins.isString value && builtins.match "^(https?|file)://.*" value != null;

  invalidSourceError = throw "mkNodeApp: src must be a path, a derivation, or an http(s)/file URL string.";

  sourceRootOf =
    src:
    if builtins.isPath src then
      src
    else if lib.isDerivation src then
      src.outPath
    else
      null;

  readSourceEntries =
    src:
    let
      root = sourceRootOf src;
      readable = root != null && builtins.pathExists root;
    in
    if readable then builtins.readDir root else null;

  entryExists = entries: name: entries != null && builtins.hasAttr name entries;

  detectPackageManager =
    src:
    let
      entries = readSourceEntries src;
    in
    if entryExists entries "pnpm-lock.yaml" then
      "pnpm"
    else if entryExists entries "yarn.lock" then
      (if entryExists entries ".yarnrc.yml" then "yarn-berry" else "yarn")
    else if entryExists entries "package-lock.json" || entryExists entries "npm-shrinkwrap.json" then
      "npm"
    else
      null;

  resolveSource =
    { src, srcHash }:
    let
      pinnedSourceError = throw "mkNodeApp: srcHash is only used for URL sources. Paths and derivations are already pinned by Nix (flake inputs are pinned in flake.lock).";
    in
    if builtins.isPath src || lib.isDerivation src then
      if srcHash != null then pinnedSourceError else src
    else if builtins.isString src && isUrl src then
      if srcHash == null then
        throw "mkNodeApp: srcHash is required when src is a URL. Set srcHash = lib.fakeHash and copy the hash Nix reports."
      else
        pkgs.fetchzip {
          url = src;
          hash = srcHash;
        }
    else
      invalidSourceError;

  resolvePackageManager =
    { packageManager, src }:
    if packageManager != null then
      if builtins.elem packageManager supportedPackageManagers then
        packageManager
      else
        throw "mkNodeApp: unsupported packageManager \"${packageManager}\". Supported values: ${lib.concatStringsSep ", " supportedPackageManagers}."
    else if builtins.isString src && !(isUrl src) then
      invalidSourceError
    else
      let
        detected = detectPackageManager src;
      in
      if detected != null then
        detected
      else
        throw ''
          mkNodeApp: cannot determine the package manager from src.
          Expected one of pnpm-lock.yaml, yarn.lock, or package-lock.json in the source root.
          Set packageManager = "npm" | "pnpm" | "yarn" | "yarn-berry" explicitly when src is a URL or a derivation that is not in the store yet.
        '';
in
{
  mkNodeApp =
    {
      src,
      depsHash ? lib.fakeHash,
      srcHash ? null,
      packageManager ? null,
      pname ? "node-app",
      version ? "0.0.0",
      nodejs ? pkgs.nodejs,
      pnpm ? pkgs.pnpm,
      yarn ? pkgs.yarn,
      buildScript ? "build",
      installPhase ? null,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      yarnBerryMissingHashes ? null,
      extraAttrs ? { },
    }:
    let
      source = resolveSource { inherit src srcHash; };
      manager = resolvePackageManager { inherit packageManager src; };

      extra = removeAttrs extraAttrs [
        "meta"
        "env"
      ];
      extraMeta = extraAttrs.meta or { };
      extraEnv = extraAttrs.env or { };

      defaultInstallPhase = ''
        runHook preInstall

        mkdir -p $out
        cp -a ./. $out/
        rm -rf $out/.git

        runHook postInstall
      '';

      effectiveInstallPhase = if installPhase != null then installPhase else defaultInstallPhase;

      buildPhaseFor = script: ''
        runHook preBuild

        ${script}

        runHook postBuild
      '';

      mkBuildPhase =
        started:
        if buildScript == null then
          ''
            runHook preBuild
            runHook postBuild
          ''
        else
          buildPhaseFor "${started} ${lib.escapeShellArg buildScript}";

      # pnpm 11 needs fetcherVersion 4; older nixpkgs cap at 3. https://nixos.org/manual/nixpkgs/stable/#javascript-pnpm-fetcherVersion
      pnpmFetcherVersion = if lib.versionAtLeast pnpm.version "11.0.0" then 4 else 3;

      pnpmDependencies =
        if pkgs ? fetchPnpmDeps then
          pkgs.fetchPnpmDeps {
            inherit pname src;
            inherit pnpm;
            hash = depsHash;
            fetcherVersion = pnpmFetcherVersion;
            pnpmWorkspaces = extraAttrs.pnpmWorkspaces or [ ];
            pnpmInstallFlags = extraAttrs.pnpmInstallFlags or [ ];
          }
        else
          pnpm.fetchDeps {
            inherit pname src;
            hash = depsHash;
            pnpmWorkspaces = extraAttrs.pnpmWorkspaces or [ ];
            pnpmInstallFlags = extraAttrs.pnpmInstallFlags or [ ];
          };

      pnpmConfigHook = if pkgs ? pnpmConfigHook then pkgs.pnpmConfigHook else pnpm.configHook;

      sharedArgs = {
        inherit pname version;
        src = source;
        inherit nativeBuildInputs buildInputs;
        installPhase = effectiveInstallPhase;
        dontStrip = true;
        strictDeps = true;
        env = extraEnv;
        meta = {
          description = "${pname} built with ${manager}";
          platforms = nodejs.meta.platforms;
        }
        // extraMeta;
      };

      buildWithNpm = pkgs.buildNpmPackage (
        sharedArgs
        // {
          inherit nodejs;
          npmDepsHash = depsHash;
          buildPhase = mkBuildPhase "npm run";
        }
        // extra
      );

      buildWithPnpm = pkgs.stdenv.mkDerivation (
        sharedArgs
        // {
          pnpmDeps = pnpmDependencies;
          nativeBuildInputs = [
            nodejs
            pnpm
            pnpmConfigHook
          ]
          ++ nativeBuildInputs;
          buildPhase = mkBuildPhase "pnpm run";
        }
        // extra
      );

      buildWithYarn = pkgs.stdenv.mkDerivation (
        sharedArgs
        // {
          yarnOfflineCache = pkgs.fetchYarnDeps {
            inherit src;
            hash = depsHash;
          };
          nativeBuildInputs = [
            nodejs
            yarn
            pkgs.yarnConfigHook
          ]
          ++ nativeBuildInputs;
          buildPhase = mkBuildPhase "yarn --offline run";
        }
        // extra
      );

      buildWithYarnBerry =
        if !(builtins.hasAttr "yarn-berry_4-fetcher" pkgs) then
          throw "mkNodeApp: Yarn Berry support requires nixpkgs >= 26.05 (pkgs.yarn-berry_4-fetcher is missing). Use a newer nixpkgs, or switch the project to yarn classic."
        else
          pkgs.stdenv.mkDerivation (
            sharedArgs
            // {
              offlineCache = pkgs."yarn-berry_4-fetcher".fetchYarnBerryDeps (
                {
                  inherit src;
                  hash = depsHash;
                }
                // lib.optionalAttrs (yarnBerryMissingHashes != null) {
                  missingHashes = yarnBerryMissingHashes;
                }
              );
              nativeBuildInputs = [
                nodejs
                pkgs."yarn-berry_4"
                pkgs."yarn-berry_4-fetcher".yarnBerryConfigHook
              ]
              ++ nativeBuildInputs;
              buildPhase = mkBuildPhase "yarn run";
              env = {
                YARN_IGNORE_PATH = "1";
              }
              // lib.optionalAttrs (yarnBerryMissingHashes != null) {
                missingHashes = yarnBerryMissingHashes;
              }
              // extraEnv;
            }
            // extra
          );
    in
    {
      npm = buildWithNpm;
      pnpm = buildWithPnpm;
      yarn = buildWithYarn;
      yarn-berry = buildWithYarnBerry;
    }
    .${manager};
}
