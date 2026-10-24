{ pkgs }:
let
  inherit (pkgs) lib;

  inherit (import ./source { inherit pkgs; }) resolveSource;
  inherit (import ./package_manager { inherit pkgs; }) resolvePackageManager;

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
      manager = resolvePackageManager { inherit packageManager source; };

      extra = removeAttrs extraAttrs [
        "meta"
        "env"
      ];
      extraMeta = extraAttrs.meta or { };
      extraEnv = extraAttrs.env or { };

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
          env = extraEnv;
          meta = {
            description = "${pname} built with ${manager}";
            platforms = nodejs.meta.platforms;
          }
          // extraMeta;
        };
        inherit
          buildScript
          depsHash
          extra
          nodejs
          ;
      };

      builderArgs = {
        npm = commonBuilderArgs;
        pnpm = commonBuilderArgs // {
          inherit pnpm pname extraAttrs;
          src = source;
        };
        yarn = commonBuilderArgs // {
          inherit yarn;
          src = source;
        };
        yarn-berry = commonBuilderArgs // {
          inherit yarnBerryMissingHashes;
          src = source;
        };
      };
    in
    builders.${manager} builderArgs.${manager};
}
