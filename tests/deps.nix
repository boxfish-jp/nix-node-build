{
  pkgs,
  mkNodeApp,
  mkNodeDeps,
  mkNodeDepsWithPkgs,
  hashes,
}:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix { inherit pkgs; }) check expectThrows outputCheck;

  npmSource = ./fixtures/npm;
  pnpmSource = ./fixtures/pnpm;
  yarnSource = ./fixtures/yarn;
  yarnBerrySource = ./fixtures/yarn-berry;

  npmDeps = mkNodeDeps {
    src = npmSource;
    depsHash = hashes.npm;
    packageManager = "npm";
  };

  pnpmDeps = mkNodeDeps {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    packageManager = "pnpm";
  };

  yarnDeps = mkNodeDeps {
    src = yarnSource;
    depsHash = hashes.yarn;
    packageManager = "yarn";
  };

  yarnBerryDeps = mkNodeDeps {
    src = yarnBerrySource;
    depsHash = hashes.yarnBerry;
    packageManager = "yarn-berry";
  };

  npmAppWithDeps = mkNodeApp {
    src = npmSource;
    deps = npmDeps;
    pname = "npm-app-with-deps";
  };

  pnpmAppWithDeps = mkNodeApp {
    src = pnpmSource;
    deps = pnpmDeps;
    depsHash = lib.fakeHash;
    pname = "pnpm-app-with-deps";
  };

  sharedPnpmAppFirst = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    pname = "shared-pnpm-first";
  };

  sharedPnpmAppSecond = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    pname = "shared-pnpm-second";
  };

  sharedNpmAppFirst = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    pname = "shared-npm-first";
  };

  sharedNpmAppSecond = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    pname = "shared-npm-second";
  };

  bareDeps = pkgs.runCommand "bare-deps" { } "mkdir -p $out";
in
{
  deps-expose-their-package-manager = check "deps-expose-their-package-manager" (
    npmDeps.passthru.manager == "npm"
    && pnpmDeps.passthru.manager == "pnpm"
    && yarnDeps.passthru.manager == "yarn"
    && yarnBerryDeps.passthru.manager == "yarn-berry"
  );

  deps-match-the-internal-fetch-for-npm = check "deps-match-the-internal-fetch-for-npm" (
    npmDeps.drvPath == (mkNodeApp {
      src = npmSource;
      depsHash = hashes.npm;
    }).passthru.deps.drvPath
  );

  deps-match-the-internal-fetch-for-pnpm = check "deps-match-the-internal-fetch-for-pnpm" (
    pnpmDeps.drvPath == (mkNodeApp {
      src = pnpmSource;
      depsHash = hashes.pnpm;
    }).passthru.deps.drvPath
  );

  deps-match-the-internal-fetch-for-yarn = check "deps-match-the-internal-fetch-for-yarn" (
    yarnDeps.drvPath == (mkNodeApp {
      src = yarnSource;
      depsHash = hashes.yarn;
    }).passthru.deps.drvPath
  );

  deps-match-the-internal-fetch-for-yarn-berry =
    check "deps-match-the-internal-fetch-for-yarn-berry"
      (
        yarnBerryDeps.drvPath == (mkNodeApp {
          src = yarnBerrySource;
          depsHash = hashes.yarnBerry;
        }).passthru.deps.drvPath
      );

  deps-shared-between-pnpm-apps-with-the-same-source =
    check "deps-shared-between-pnpm-apps-with-the-same-source"
      (sharedPnpmAppFirst.passthru.deps.drvPath == sharedPnpmAppSecond.passthru.deps.drvPath);

  deps-shared-between-npm-apps-with-the-same-source =
    check "deps-shared-between-npm-apps-with-the-same-source"
      (sharedNpmAppFirst.passthru.deps.drvPath == sharedNpmAppSecond.passthru.deps.drvPath);

  deps-injected-are-exposed-through-passthru = check "deps-injected-are-exposed-through-passthru" (
    pnpmAppWithDeps.passthru.deps.drvPath == pnpmDeps.drvPath
    && npmAppWithDeps.passthru.deps.drvPath == npmDeps.drvPath
  );

  deps-injected-are-used-by-the-pnpm-builder = check "deps-injected-are-used-by-the-pnpm-builder" (
    pnpmAppWithDeps.pnpmDeps.drvPath == pnpmDeps.drvPath
  );

  deps-injected-are-used-by-the-npm-builder = check "deps-injected-are-used-by-the-npm-builder" (
    npmAppWithDeps.npmDeps.drvPath == npmDeps.drvPath
  );

  deps-injected-npm-output = outputCheck "deps-injected-npm-output" ''
    grep -q "built with npm" ${npmAppWithDeps}/dist/index.html
  '';

  deps-injected-pnpm-output = outputCheck "deps-injected-pnpm-output" ''
    grep -q "built with pnpm" ${pnpmAppWithDeps}/dist/index.html
  '';

  deps-manager-mismatch-throws = check "deps-manager-mismatch-throws" (
    expectThrows (
      (mkNodeApp {
        src = pnpmSource;
        deps = npmDeps;
      }).drvPath
    )
  );

  deps-and-real-deps-hash-throws = check "deps-and-real-deps-hash-throws" (
    expectThrows (
      (mkNodeApp {
        src = pnpmSource;
        deps = pnpmDeps;
        depsHash = hashes.pnpm;
      }).drvPath
    )
  );

  deps-without-package-manager-throws = check "deps-without-package-manager-throws" (
    expectThrows (
      (mkNodeApp {
        src = pnpmSource;
        deps = bareDeps;
      }).drvPath
    )
  );

  deps-available-through-pkgs-entry-point = check "deps-available-through-pkgs-entry-point" (
    (mkNodeDepsWithPkgs {
      inherit pkgs;
      src = pnpmSource;
      depsHash = hashes.pnpm;
    }).passthru.manager == "pnpm"
  );
}
