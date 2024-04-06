{ pkgs, nix-filter, source-root }:
  let
    style-js-packages-src = nix-filter {
      root = source-root + "/crates/site-app/style/tailwind";
      include = [
        "package.json"
        "yarn.lock"
      ];
    };

    style-js-packages-yarn-registry = pkgs.fetchYarnDeps {
      yarnLock = source-root + "/crates/site-app/style/tailwind/yarn.lock";
      hash = "sha256-oZgyP0hTU9bxszOVg3Bmiu6yos2d2Inc1Do8To4z8GQ=";
      # hash = "";
    };
  in
    # use `yarn install` to build the `node_modules` directory
    pkgs.stdenv.mkDerivation {
      name = "style-js-node-modules";
      buildInputs = [ pkgs.yarn pkgs.yarn2nix-moretea.fixup_yarn_lock ];
      src = style-js-packages-src;

      configurePhase = ''
        runHook preConfigure
        
        export HOME=$(mktemp -d)
        yarn config --offline set yarn-offline-mirror ${style-js-packages-yarn-registry}

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        fixup_yarn_lock yarn.lock
        yarn install --offline --frozen-lockfile

        runHook postBuild
      
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out
        cp -r node_modules $out

        runHook postInstall
      '';
    }
