{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "https://flakehub.com/f/oxalica/rust-overlay/0.1.1330.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "https://flakehub.com/f/ipetkov/crane/0.16.1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cargo-leptos-src = { url = "github:leptos-rs/cargo-leptos?tag=v0.2.16"; flake = false; };
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, rust-overlay, crane, cargo-leptos-src, nix-filter, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # set up `pkgs` with rust-overlay
        overlays = [ (import rust-overlay) ];
        pkgs = (import nixpkgs) {
          inherit system overlays;
        };

        # filter the source to reduce cache misses
        # add a path here if you need other files, e.g. bc of `include_str!()`
        src = nix-filter {
          root = ./.;
          include = [
            (nix-filter.lib.matchExt "toml")
            ./Cargo.lock
            ./crates
          ];
        };
        
        # set up the rust toolchain, including the wasm target
        toolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = [ "wasm32-unknown-unknown" ];
        });

        # read leptos options from `Cargo.toml`
        leptos-options = builtins.elemAt (builtins.fromTOML (
          builtins.readFile ./Cargo.toml
        )).workspace.metadata.leptos 0;
        
        # configure crane to use our toolchain
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        # build cargo-leptos from source
        cargo-leptos = (import ./nix/cargo-leptos.nix) {
          inherit pkgs craneLib;
          cargo-leptos = cargo-leptos-src;
        };

        # download and install JS packages used by tailwind
        style-js-deps = (import ./nix/style-js-deps.nix) {
          inherit pkgs nix-filter;
          source-root = ./.;
        };

        # crane build configuration used by multiple builds
        common-args = {
          inherit src;

          # use the name defined in the `Cargo.toml` leptos options
          pname = leptos-options.bin-package;
          version = "0.1.0";

          doCheck = false;

          nativeBuildInputs = [
            cargo-leptos
            pkgs.binaryen # provides wasm-opt

            # used by cargo-leptos for styling
            pkgs.dart-sass
            pkgs.tailwindcss
          ] ++ pkgs.lib.optionals (system == "x86_64-linux") [
            pkgs.nasm # wasm compiler only for x86_64-linux
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv # character encoding lib needed by darwin
          ];

          buildInputs = [
            pkgs.pkg-config # used by many crates for finding system packages
            pkgs.openssl # needed for many http libraries
          ];

        };

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        site-server-deps = craneLib.buildDepsOnly (common-args // {
          # if work is duplicated by the `server-site` package, update these
          # commands from the logs of `cargo leptos build --release -vvv`
          buildPhaseCargoCommand = ''
            # build the frontend dependencies
            cargo build --package=${leptos-options.lib-package} --lib --target-dir=/build/source/target/front --target=wasm32-unknown-unknown --no-default-features --profile=${leptos-options.lib-profile-release}
            # build the server dependencies
            cargo build --package=${leptos-options.bin-package} --no-default-features --release
          '';
        });

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        site-server = craneLib.buildPackage (common-args // {
          # link the style packages node_modules into the build directory
          preBuild = ''
            ln -s ${style-js-deps}/node_modules \
              ./crates/site-app/style/tailwind/node_modules
          '';
          
          buildPhaseCargoCommand = ''
            cargo leptos build --release -vvv
          '';

          installPhaseCommand = ''
            mkdir -p $out/bin
            cp target/release/site-server $out/bin/
            cp target/release/hash.txt $out/bin/
            cp -r target/site $out/bin/
          '';

          doCheck = false;
          cargoArtifacts = site-server-deps;
        });

        site-server-container = pkgs.dockerTools.buildLayeredImage {
          name = leptos-options.bin-package;
          tag = "latest";
          contents = [ site-server pkgs.cacert ];
          config = {
            # runs the executable with tini: https://github.com/krallin/tini
            # this does signal forwarding and zombie process reaping
            Entrypoint = [ "${pkgs.tini}/bin/tini" "site-server" "--" ];
            WorkingDir = "${site-server}/bin";
            # we provide the env variables that we get from Cargo.toml during development
            # these can be overridden when the container is run, but defaults are needed
            Env = [
              "LEPTOS_OUTPUT_NAME=${leptos-options.name}"
              "LEPTOS_SITE_ROOT=${leptos-options.name}"
              "LEPTOS_SITE_PKG_DIR=${leptos-options.site-pkg-dir}"
              "LEPTOS_SITE_ADDR=0.0.0.0:3000"
              "LEPTOS_RELOAD_PORT=${builtins.toString leptos-options.reload-port}"
              "LEPTOS_ENV=PROD"
              "LEPTOS_HASH_FILES=${builtins.toJSON leptos-options.hash-files}"
            ];
          };
        };
      
      in {
        checks = {
          # lint packages
          app-hydrate-clippy = craneLib.cargoClippy (common-args // {
            cargoArtifacts = site-server-deps;
            cargoClippyExtraArgs = "-p site-app --features hydrate -- --deny warnings";
          });
          app-ssr-clippy = craneLib.cargoClippy (common-args // {
            cargoArtifacts = site-server-deps;
            cargoClippyExtraArgs = "-p site-app --features ssr -- --deny warnings";
          });
          site-server-clippy = craneLib.cargoClippy (common-args // {
            cargoArtifacts = site-server-deps;
            cargoClippyExtraArgs = "-p site-server -- --deny warnings";
          });
          site-frontend-clippy = craneLib.cargoClippy (common-args // {
            cargoArtifacts = site-server-deps;
            cargoClippyExtraArgs = "-p site-frontend -- --deny warnings";
          });

          # make sure the docs build
          site-server-doc = craneLib.cargoDoc (common-args // {
            cargoArtifacts = site-server-deps;
          });

          # check formatting
          site-server-fmt = craneLib.cargoFmt {
            pname = common-args.pname;
            version = common-args.version;
            
            inherit src;
          };

          # # audit licenses
          # site-server-deny = craneLib.cargoDeny {
          #   pname = common_args.pname;
          #   version = common_args.version;
          #   inherit src;
          # };

          # run tests
          site-server-nextest = craneLib.cargoNextest (common-args // {
            cargoArtifacts = site-server-deps;
            partitions = 1;
            partitionType = "count";
          });
        };

        packages = {
          default = site-server;
          server = site-server;
          container = site-server-container;
        };
        
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = (with pkgs; [
            toolchain # cargo and such from crane
            just # command recipes
            dive # docker images
            cargo-leptos # main leptos build tool
            flyctl # fly.io
            bacon # cargo check w/ hot reload
            cargo-deny # license checking
          ])
            ++ common-args.buildInputs
            ++ common-args.nativeBuildInputs
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.Security
            ];
        };
      }
    );
}
