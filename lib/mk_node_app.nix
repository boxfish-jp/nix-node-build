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
      source =
        if builtins.isPath src || lib.isDerivation src then
          src
        else
          throw "mkNodeApp: src must be a path or a derivation.";
      manager = resolvePackageManager { inherit packageManager source; };

      npmDepsFetcherVersion = extraAttrs.npmDepsFetcherVersion or 1;
      pnpmWorkspaces = extraAttrs.pnpmWorkspaces or [ ];
      pnpmInstallFlags = extraAttrs.pnpmInstallFlags or [ ];

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
              pnpmWorkspaces
              pnpmInstallFlags
              yarnBerryMissingHashes
              ;
            packageManager = manager;
          };

      extra = removeAttrs extraAttrs [
        "meta"
        "env"
        "passthru"
      ];
      extraMeta = extraAttrs.meta or { };
      extraEnv = extraAttrs.env or { };
      extraPassthru = extraAttrs.passthru or { };

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
          dontStrip = true;
          strictDeps = true;
          passthru = extraPassthru // {
            deps = dependencyCache;
          };
          env = extraEnv;
          meta = {
            description = "${pname} built with ${manager}";
            platforms = nodejs.meta.platforms;
          }
          // extraMeta;
        };
        inherit
          buildScript
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
