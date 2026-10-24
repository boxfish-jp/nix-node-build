{
  pkgs,
  mkNodeApp,
  mkNodeAppWithPkgs,
  mkNodeDeps,
  hashes,
}:
let
  inherit (pkgs) lib;
  inherit (import ./lib.nix { inherit pkgs; }) check outputCheck;

  npmSource = ./fixtures/npm;
  pnpmSource = ./fixtures/pnpm;
  yarnSource = ./fixtures/yarn;
  yarnBerrySource = ./fixtures/yarn-berry;

  npmApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
  };

  pnpmApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
  };

  yarnApp = mkNodeApp {
    src = yarnSource;
    depsHash = hashes.yarn;
  };

  yarnBerryApp = mkNodeApp {
    src = yarnBerrySource;
    depsHash = hashes.yarnBerry;
  };

  customInstallApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dist $out/dist

      runHook postInstall
    '';
  };

  buildScriptNullApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildScript = null;
  };

  buildCommandApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildCommand = "node build_args.js --some-flag value";
  };

  buildCommandPrecedenceApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildCommand = "node build.js";
    buildScript = "missing-script";
  };

  buildCommandWithNullBuildScriptApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildCommand = "node build.js";
    buildScript = null;
  };

  buildPhaseOrderApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    preBuild = "printf 'preBuild\\n' >> build-order.log";
    buildCommand = "printf 'build\\n' >> build-order.log";
    postBuild = "printf 'postBuild\\n' >> build-order.log";
  };

  buildHooksApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    preBuild = "printf 'preBuild\\n' > prebuild-marker";
    postBuild = "printf 'postBuild\\n' > postbuild-marker";
  };

  extraBuildPhaseApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildCommand = "node build_args.js --from-build-command";
    extraAttrs.buildPhase = "mkdir -p dist && printf 'built with extraAttrs\\n' > dist/override.txt";
  };

  pnpmBuildCommandApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    buildCommand = "node build.js && printf 'built with buildCommand\\n' >> dist/index.html";
  };

  derivedSource = pkgs.runCommand "npm-derivation-source" { } ''
    cp -r ${npmSource} $out
    chmod -R u+w $out
    substituteInPlace $out/package.json --replace-fail '"build":' '"compile":'
    mkdir -p $out/.git
    printf 'ref: refs/heads/main\n' > $out/.git/HEAD
  '';

  derivedSourceApp = mkNodeApp {
    src = derivedSource;
    depsHash = hashes.npm;
    buildScript = "compile";
  };

  nodejsOverrideApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    nodejs = pkgs.nodejs_22;
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      node --version > $out/node-version

      runHook postInstall
    '';
  };

  nativeBuildInputApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    nativeBuildInputs = [ pkgs.hello ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      hello > $out/hello.txt

      runHook postInstall
    '';
  };

  buildInputApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    buildInputs = [ pkgs.zlib ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      printf '%s\n%s\n' "''${NIX_LDFLAGS:-}" "''${NIX_CFLAGS_COMPILE:-}" > $out/compiler-flags

      runHook postInstall
    '';
  };

  extraAttrsApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    extraAttrs = {
      env.EXTRA_MESSAGE = "from-extra-attrs";
      meta.description = "description from extraAttrs";
      meta.homepage = "https://example.com/custom-app";
      passthru.custom = "custom-value";
      customAttribute = "custom-attribute-value";
    };
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      printf '%s\n' "$EXTRA_MESSAGE" > $out/extra-message

      runHook postInstall
    '';
  };

  pnameVersionApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    pname = "custom-app";
    version = "1.2.3";
  };

  topLevelEnvApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    env.TOP_LEVEL_MESSAGE = "from-top-level";
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      printf '%s\n' "$TOP_LEVEL_MESSAGE" > $out/top-level-message

      runHook postInstall
    '';
  };

  topLevelMetaApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    meta = {
      description = "description from top level";
      homepage = "https://example.com/top-level-app";
    };
  };

  mergedAttributesApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    meta.description = "description from top level";
    env.MERGED_MESSAGE = "from-top-level";
    extraAttrs = {
      meta.description = "description from extraAttrs";
      env.MERGED_MESSAGE = "from-extra-attrs";
    };
  };

  mainProgramApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    mainProgram = "hello";
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${pkgs.hello}/bin/hello $out/bin/hello

      runHook postInstall
    '';
  };

  mainProgramPrecedenceApp = mkNodeApp {
    src = npmSource;
    depsHash = hashes.npm;
    meta.mainProgram = "from-meta";
    mainProgram = "hello";
  };

  pnpmOptionsApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    pnpmWorkspaces = [ "packages/app" ];
    pnpmInstallFlags = [ "--prefer-offline" ];
  };

  pnpmOptionsDeps = mkNodeDeps {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    packageManager = "pnpm";
    pnpmWorkspaces = [ "packages/app" ];
    pnpmInstallFlags = [ "--prefer-offline" ];
  };

  pnpmExtraAttrsOptionsApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    extraAttrs = {
      pnpmWorkspaces = [ "packages/app" ];
      pnpmInstallFlags = [ "--prefer-offline" ];
    };
  };

  explicitPnpmApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    packageManager = "pnpm";
  };

  explicitYarnBerryApp = mkNodeApp {
    src = yarnBerrySource;
    depsHash = hashes.yarnBerry;
    packageManager = "yarn-berry";
  };

  pnpmSpy =
    (pkgs.writeShellScriptBin "pnpm" ''
      if [ -n "''${PNPM_SPY:-}" ]; then
        mkdir -p "$out"
        printf 'used\n' >> "$out/pnpm-override-marker"
      fi
      exec ${pkgs.pnpm}/bin/pnpm "$@"
    '')
    // {
      version = pkgs.pnpm.version;
      nodejs-slim = pkgs.pnpm.nodejs-slim;
    };

  pnpmOverrideApp = mkNodeApp {
    src = pnpmSource;
    depsHash = hashes.pnpm;
    pnpm = pnpmSpy;
    extraAttrs.env.PNPM_SPY = "1";
  };

  yarnSpy = pkgs.writeShellScriptBin "yarn" ''
    if [ -n "''${YARN_SPY:-}" ]; then
      mkdir -p "$out"
      printf 'used\n' >> "$out/yarn-override-marker"
    fi
    exec ${pkgs.yarn}/bin/yarn "$@"
  '';

  yarnOverrideApp = mkNodeApp {
    src = yarnSource;
    depsHash = hashes.yarn;
    yarn = yarnSpy;
    extraAttrs.env.YARN_SPY = "1";
  };

  npmShrinkwrapSource = pkgs.runCommand "npm-shrinkwrap-source" { } ''
    cp -r ${npmSource} $out
    chmod -R u+w $out
    mv $out/package-lock.json $out/npm-shrinkwrap.json
  '';

  npmShrinkwrapApp = mkNodeApp {
    src = npmShrinkwrapSource;
    depsHash = hashes.npm;
  };

  yarnBerryMissingHashesApp = mkNodeApp {
    src = yarnBerrySource;
    depsHash = hashes.yarnBerryMissingHashes;
    yarnBerryMissingHashes = pkgs.writeText "missing-hashes.json" "{}";
  };
in
{
  npm = npmApp;
  pnpm = pnpmApp;
  yarn = yarnApp;
  yarn-berry = yarnBerryApp;

  custom-install = customInstallApp;
  with-pkgs-entry-point = mkNodeAppWithPkgs {
    inherit pkgs;
    src = yarnSource;
    packageManager = "yarn";
    depsHash = hashes.yarn;
  };

  npm-output = outputCheck "npm-output" ''
    test -f ${npmApp}/package.json
    test -d ${npmApp}/node_modules/is-number
    test -f ${npmApp}/dist/index.html
    grep -q "built with npm" ${npmApp}/dist/index.html
  '';

  pnpm-output = outputCheck "pnpm-output" ''
    test -f ${pnpmApp}/package.json
    test -d ${pnpmApp}/node_modules/is-number
    test -f ${pnpmApp}/dist/index.html
    grep -q "built with pnpm" ${pnpmApp}/dist/index.html
  '';

  pnpm-output-excludes-volatile-install-state = outputCheck "pnpm-output-excludes-volatile-install-state" ''
    test ! -e ${pnpmApp}/node_modules/.modules.yaml
    test ! -e ${pnpmApp}/node_modules/.pnpm-workspace-state-v1.json
  '';

  yarn-output = outputCheck "yarn-output" ''
    test -f ${yarnApp}/package.json
    test -d ${yarnApp}/node_modules/is-number
    test -f ${yarnApp}/dist/index.html
    grep -q "built with yarn" ${yarnApp}/dist/index.html
  '';

  yarn-berry-output = outputCheck "yarn-berry-output" ''
    test -f ${yarnBerryApp}/package.json
    test -d ${yarnBerryApp}/node_modules/is-number
    test -f ${yarnBerryApp}/dist/index.html
    grep -q "built with yarn-berry" ${yarnBerryApp}/dist/index.html
  '';

  custom-install-output = outputCheck "custom-install-output" ''
    test -f ${customInstallApp}/dist/index.html
    test ! -e ${customInstallApp}/node_modules
    test ! -e ${customInstallApp}/package.json
  '';

  build-script-null-output = outputCheck "build-script-null-output" ''
    test -d ${buildScriptNullApp}/node_modules/is-number
    test ! -e ${buildScriptNullApp}/dist
  '';

  build-command-output = outputCheck "build-command-output" ''
    grep -qx -- "--some-flag value" ${buildCommandApp}/dist/args.txt
  '';

  build-command-precedence-output = outputCheck "build-command-precedence-output" ''
    grep -q "built with npm" ${buildCommandPrecedenceApp}/dist/index.html
  '';

  build-command-with-null-build-script-output = outputCheck "build-command-with-null-build-script-output" ''
    grep -q "built with npm" ${buildCommandWithNullBuildScriptApp}/dist/index.html
  '';

  build-phase-order-output = outputCheck "build-phase-order-output" ''
    test "$(cat ${buildPhaseOrderApp}/build-order.log)" = "$(printf 'preBuild\nbuild\npostBuild')"
  '';

  build-hooks-output = outputCheck "build-hooks-output" ''
    grep -qx preBuild ${buildHooksApp}/prebuild-marker
    grep -qx postBuild ${buildHooksApp}/postbuild-marker
    grep -q "built with npm" ${buildHooksApp}/dist/index.html
  '';

  extra-attrs-build-phase-output = outputCheck "extra-attrs-build-phase-output" ''
    grep -qx "built with extraAttrs" ${extraBuildPhaseApp}/dist/override.txt
    test ! -e ${extraBuildPhaseApp}/dist/args.txt
  '';

  pnpm-build-command-output = outputCheck "pnpm-build-command-output" ''
    grep -q "built with pnpm" ${pnpmBuildCommandApp}/dist/index.html
    grep -q "built with buildCommand" ${pnpmBuildCommandApp}/dist/index.html
  '';

  derivation-source-output = outputCheck "derivation-source-output" ''
    test -f ${derivedSourceApp}/dist/index.html
    grep -q "built with npm" ${derivedSourceApp}/dist/index.html
    test ! -e ${derivedSourceApp}/.git
  '';

  nodejs-override-output = outputCheck "nodejs-override-output" ''
    grep -q '^v22\.' ${nodejsOverrideApp}/node-version
  '';

  native-build-inputs-output = outputCheck "native-build-inputs-output" ''
    grep -q "Hello, world!" ${nativeBuildInputApp}/hello.txt
  '';

  build-inputs-output = outputCheck "build-inputs-output" ''
    grep -q '${pkgs.zlib}' ${buildInputApp}/compiler-flags
  '';

  extra-attrs-output = outputCheck "extra-attrs-output" ''
    grep -qx "from-extra-attrs" ${extraAttrsApp}/extra-message
  '';

  extra-attrs-attributes = check "extra-attrs-attributes" (
    extraAttrsApp.meta.description == "description from extraAttrs"
    && extraAttrsApp.meta.homepage == "https://example.com/custom-app"
    && extraAttrsApp.meta.platforms == pkgs.nodejs.meta.platforms
    && extraAttrsApp.passthru.custom == "custom-value"
    && extraAttrsApp.customAttribute == "custom-attribute-value"
  );

  pname-version = check "pname-version" (
    pnameVersionApp.name == "custom-app-1.2.3"
    && pnameVersionApp.meta.description == "custom-app built with npm"
  );

  top-level-env-output = outputCheck "top-level-env-output" ''
    grep -qx "from-top-level" ${topLevelEnvApp}/top-level-message
  '';

  top-level-meta-attributes = check "top-level-meta-attributes" (
    topLevelMetaApp.meta.description == "description from top level"
    && topLevelMetaApp.meta.homepage == "https://example.com/top-level-app"
    && topLevelMetaApp.meta.platforms == pkgs.nodejs.meta.platforms
  );

  top-level-meta-wins-over-extra-attrs = check "top-level-meta-wins-over-extra-attrs" (
    mergedAttributesApp.meta.description == "description from top level"
    && mergedAttributesApp.meta.platforms == pkgs.nodejs.meta.platforms
  );

  top-level-env-wins-over-extra-attrs = check "top-level-env-wins-over-extra-attrs" (
    mergedAttributesApp.MERGED_MESSAGE == "from-top-level"
  );

  main-program-sets-meta-main-program-for-nix-run =
    check "main-program-sets-meta-main-program-for-nix-run"
      (mainProgramApp.meta.mainProgram == "hello");

  main-program-wins-over-meta-main-program = check "main-program-wins-over-meta-main-program" (
    mainProgramPrecedenceApp.meta.mainProgram == "hello"
  );

  main-program-out-bin-is-executable-for-nix-run = outputCheck "main-program-out-bin-is-executable-for-nix-run" ''
    test -x ${mainProgramApp}/bin/hello
    ${mainProgramApp}/bin/hello | grep -q "Hello, world!"
  '';

  pnpm-options-reach-fetch-and-install = check "pnpm-options-reach-fetch-and-install" (
    pnpmOptionsApp.passthru.deps.drvPath == pnpmOptionsDeps.drvPath
    && pnpmOptionsApp.passthru.deps.drvPath != pnpmApp.passthru.deps.drvPath
    && pnpmOptionsApp.pnpmWorkspaces == [ "packages/app" ]
    && pnpmOptionsApp.pnpmInstallFlags == [ "--prefer-offline" ]
  );

  pnpm-options-fall-back-to-extra-attrs = check "pnpm-options-fall-back-to-extra-attrs" (
    pnpmExtraAttrsOptionsApp.passthru.deps.drvPath == pnpmOptionsDeps.drvPath
    && pnpmExtraAttrsOptionsApp.pnpmWorkspaces == [ "packages/app" ]
    && pnpmExtraAttrsOptionsApp.pnpmInstallFlags == [ "--prefer-offline" ]
  );

  default-deps-hash = check "default-deps-hash" (
    (mkNodeApp { src = npmSource; }).npmDeps.outputHash == lib.fakeHash
    && (mkNodeApp { src = pnpmSource; }).pnpmDeps.outputHash == lib.fakeHash
    && (mkNodeApp { src = yarnSource; }).yarnOfflineCache.outputHash == lib.fakeHash
    && (mkNodeApp { src = yarnBerrySource; }).offlineCache.outputHash == lib.fakeHash
  );

  explicit-package-manager-pnpm-output = outputCheck "explicit-package-manager-pnpm-output" ''
    grep -q "built with pnpm" ${explicitPnpmApp}/dist/index.html
  '';

  explicit-package-manager-yarn-berry-output = outputCheck "explicit-package-manager-yarn-berry-output" ''
    grep -q "built with yarn-berry" ${explicitYarnBerryApp}/dist/index.html
  '';

  pnpm-override-output = outputCheck "pnpm-override-output" ''
    test -f ${pnpmOverrideApp}/pnpm-override-marker
  '';

  yarn-override-output = outputCheck "yarn-override-output" ''
    test -f ${yarnOverrideApp}/yarn-override-marker
  '';

  npm-shrinkwrap-output = outputCheck "npm-shrinkwrap-output" ''
    grep -q "built with npm" ${npmShrinkwrapApp}/dist/index.html
  '';

  yarn-berry-missing-hashes-output = outputCheck "yarn-berry-missing-hashes-output" ''
    grep -q "built with yarn-berry" ${yarnBerryMissingHashesApp}/dist/index.html
  '';
}
