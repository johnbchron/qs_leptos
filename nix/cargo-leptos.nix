{pkgs, craneLib, cargo-leptos}: 
  craneLib.buildPackage {
    src = craneLib.cleanCargoSource cargo-leptos;
    strictDeps = true;

    buildInputs = [ pkgs.pkg-config pkgs.openssl ];
    cargoExtraArgs = "--no-default-features --features no_downloads";

    doCheck = false;
  }
