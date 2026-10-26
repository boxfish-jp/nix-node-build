{ pkgs }:
let
  inherit (pkgs) lib;

  inherit (import ./package_manager { inherit pkgs; }) resolvePackageManager;
  inherit (import ./mk_node_deps.nix { inherit pkgs; }) mkNodeDeps;

  builders = {
    npm = import ./builder/npm.nix { inherit pkgs; };
    pnpm = import ./builder/pnpm.nix { inherit pkgs; };
    yarn = import ./builder/yarn.nix { inherit pkgs; };
    yarn-berry = import ./builder/yarn_berry.nix { inherit pkgs; };
  };

  defaultInstallPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -a ./. $out/
    rm -rf $out/.git

    runHook postInstall
  '';
in
{
  mkNodeApp =
    {
      src,
      depsHash ? lib.fakeHash,
      deps ? null,
      packageManager ? null,
      pname ? "node-app",
      version ? "0.0.0",
      meta ? { },
      env ? { },
      mainProgram ? null,
      nodejs ? pkgs.nodejs,
      pnpm ? pkgs.pnpm,
      pnpmWorkspaces ? null,
      pnpmInstallFlags ? null,
      yarn ? pkgs.yarn,
      buildScript ? "build",
      buildCommand ? null,
      preBuild ? "",
      postBuild ? "",
      preInstall ? null,
      postInstall ? null,
      pruneDev ? false,
      installPhase ? null,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      yarnBerryMissingHashes ? null,
      extraAttrs ? { },
    }:
    let
      source =
        if builtins.isPath src || lib.isDerivation src then
          src
        else
          throw "mkNodeApp: src must be a path or a derivation.";
      manager = resolvePackageManager { inherit packageManager source; };

      npmDepsFetcherVersion = extraAttrs.npmDepsFetcherVersion or 1;

      pnpmOptions = {
        pnpmWorkspaces =
          if pnpmWorkspaces != null then pnpmWorkspaces else extraAttrs.pnpmWorkspaces or [ ];
        pnpmInstallFlags =
          if pnpmInstallFlags != null then pnpmInstallFlags else extraAttrs.pnpmInstallFlags or [ ];
      };

      pruneDevCommands = {
        npm = "npm prune --omit=dev --no-save";
        pnpm = "pnpm prune --prod";
        yarn = "yarn install --production=true --frozen-lockfile --offline --ignore-scripts --ignore-engines --ignore-platform --non-interactive";
        yarn-berry = "YARN_ENABLE_SCRIPTS=0 yarn workspaces focus --production";
      };

      installHooks = {
        preInstall = lib.concatStringsSep "\n" (
          lib.filter (line: line != "") [
            (if preInstall != null then preInstall else extraAttrs.preInstall or "")
            (lib.optionalString pruneDev pruneDevCommands.${manager})
          ]
        );
        postInstall = if postInstall != null then postInstall else extraAttrs.postInstall or "";
      };

      dependencyCache =
        if deps != null then
          if depsHash != lib.fakeHash then
            throw "mkNodeApp: depsHash must be omitted when deps is set. deps already identifies the dependency cache."
          else
            let
              depsManager = deps.passthru.manager or null;
            in
            if depsManager == manager then
              deps
            else if depsManager == null then
              throw "mkNodeApp: deps must be created with mkNodeDeps. The given derivation has no passthru.manager."
            else
              throw "mkNodeApp: deps was created for \"${depsManager}\" but this app uses \"${manager}\". Create deps with the same package manager."
        else
          mkNodeDeps {
            src = source;
            inherit
              depsHash
              pnpm
              npmDepsFetcherVersion
              yarnBerryMissingHashes
              ;
            inherit (pnpmOptions) pnpmWorkspaces pnpmInstallFlags;
            packageManager = manager;
          };

      extra = removeAttrs extraAttrs [
        "meta"
        "env"
        "passthru"
        "preInstall"
        "postInstall"
        "pnpmWorkspaces"
        "pnpmInstallFlags"
      ];
      extraMeta = extraAttrs.meta or { };
      extraEnv = extraAttrs.env or { };
      extraPassthru = extraAttrs.passthru or { };

      resolvedMeta = {
        description = "${pname} built with ${manager}";
        platforms = nodejs.meta.platforms;
      }
      // extraMeta
      // meta
      // lib.optionalAttrs (mainProgram != null) { inherit mainProgram; };

      resolvedEnv = extraEnv // env;

      commonBuilderArgs = {
        sharedArgs = {
          inherit
            pname
            version
            nativeBuildInputs
            buildInputs
            ;
          src = source;
          installPhase = if installPhase != null then installPhase else defaultInstallPhase;
          inherit (installHooks) preInstall postInstall;
          dontStrip = true;
          strictDeps = true;
          passthru = extraPassthru // {
            deps = dependencyCache;
          };
          env = resolvedEnv;
          meta = resolvedMeta;
        };
        inherit
          buildScript
          buildCommand
          preBuild
          postBuild
          extra
          nodejs
          ;
        deps = dependencyCache;
      };

      builderArgs = {
        npm = commonBuilderArgs // {
          inherit npmDepsFetcherVersion;
        };
        pnpm = commonBuilderArgs // {
          inherit pnpm;
          # pnpmConfigHook passes an empty pnpmInstallFlags as one empty argument, which pnpm 11 rejects.
          extra = extra // lib.filterAttrs (_: value: value != [ ]) pnpmOptions;
        };
        yarn = commonBuilderArgs // {
          inherit yarn;
        };
        yarn-berry = commonBuilderArgs // {
          inherit yarnBerryMissingHashes;
        };
      };
    in
    builders.${manager} builderArgs.${manager};
}
