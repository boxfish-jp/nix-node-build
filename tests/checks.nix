{
  pkgs,
  mkNodeApp,
  mkNodeAppWithPkgs,
}:
let
  npmDepsHash = "sha256-zsbwE7tVlaNIQatR0go555QPd8uX++6vVIdQ/pnNStA=";
  pnpmDepsHash = "sha256-lcmu8p7kTx915aNZO8dCQGATqpGlMqeUCndXtNFv+p4=";
  yarnDepsHash = "sha256-2uMGM868iM8TZ/7fm30bgB1CYH9eVbl96LCOngfk6dw=";
  yarnBerryDepsHash = "sha256-4e5F6Y8n/xQBTAQuuBF5nHtspET7jTGenv7ClRrRrTc=";

  mkUrlTarball =
    name: fixture:
    pkgs.runCommand "url-src-${name}.tar.gz"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
        ];
      }
      ''
        mkdir -p root/url-src
        cp -r ${fixture}/. root/url-src/
        tar czf $out -C root url-src
      '';

  urlTarballs = {
    npm = mkUrlTarball "npm" ./fixtures/npm;
    pnpm = mkUrlTarball "pnpm" ./fixtures/pnpm;
    yarn = mkUrlTarball "yarn" ./fixtures/yarn;
    yarn-berry = mkUrlTarball "yarn-berry" ./fixtures/yarn-berry;
  };
in
{
  npm = mkNodeApp {
    src = ./fixtures/npm;
    depsHash = npmDepsHash;
  };

  pnpm = mkNodeApp {
    src = ./fixtures/pnpm;
    depsHash = pnpmDepsHash;
  };

  yarn = mkNodeApp {
    src = ./fixtures/yarn;
    depsHash = yarnDepsHash;
  };

  yarn-berry = mkNodeApp {
    src = ./fixtures/yarn-berry;
    depsHash = yarnBerryDepsHash;
  };

  url-source-npm = mkNodeApp {
    src = "file://${urlTarballs.npm}";
    srcHash = "sha256-ersskztLhING71ate2aprYqcA/TE75wnNoW85GE1k5o=";
    packageManager = "npm";
    depsHash = npmDepsHash;
  };

  url-source-pnpm = mkNodeApp {
    src = "file://${urlTarballs.pnpm}";
    srcHash = "sha256-fZtmPE8DwfWSNU0HlNe5fkY25O29mp1xtoZ/LTGFWU0=";
    depsHash = pnpmDepsHash;
  };

  url-source-yarn = mkNodeApp {
    src = "file://${urlTarballs.yarn}";
    srcHash = "sha256-dxaUX7S5snvHD8EN/UGHABtGiJNV8T1kM47LuOOLL1A=";
    depsHash = yarnDepsHash;
  };

  url-source-yarn-berry = mkNodeApp {
    src = "file://${urlTarballs.yarn-berry}";
    srcHash = "sha256-XjOQ6jbuwd0ySXTiUo6d8lFiF84gvrrHWNEF1+Vk+Fc=";
    depsHash = yarnBerryDepsHash;
  };

  custom-install = mkNodeApp {
    src = ./fixtures/pnpm;
    depsHash = pnpmDepsHash;
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dist $out/dist

      runHook postInstall
    '';
  };

  with-pkgs-entry-point = mkNodeAppWithPkgs {
    inherit pkgs;
    src = ./fixtures/yarn;
    packageManager = "yarn";
    depsHash = yarnDepsHash;
  };
}
