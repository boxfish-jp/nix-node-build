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

  urlTarball =
    pkgs.runCommand "url-src.tar.gz"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
        ];
      }
      ''
        mkdir -p root/url-src
        cp -r ${./fixtures/npm}/. root/url-src/
        tar czf $out -C root url-src
      '';
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

  url-source = mkNodeApp {
    src = "file://${urlTarball}";
    srcHash = "sha256-ersskztLhING71ate2aprYqcA/TE75wnNoW85GE1k5o=";
    packageManager = "npm";
    depsHash = npmDepsHash;
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
