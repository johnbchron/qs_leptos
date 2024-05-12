# qs_leptos

This is a template project for Leptos apps, using TailwindCSS for styling and Nix for packaging and environments.

# Getting Started

> This repository is built to be used with Nix. If you don't have Nix installed, go [here](https://nixos.org/download/) to install it. In short, Nix is a package manager built for reproducible builds and immutability. This repository should be perfectly usable without Nix, but if you attempt to use it without Nix you should be familiar with installing the necessary tools because I won't go over all the non-Nix instructions.

If you have [`direnv`](https://direnv.net/) installed, simply `direnv allow`, and after some minutes you'll have your dev environment. If not, you can use `nix develop` to do the same thing (assuming you've set up [flakes and the new command syntax](https://nixos.wiki/wiki/Flakes#Enable_flakes_temporarily))

## Development
To start developing, simply run `just` if you have [`just`](https://github.com/casey/just) installed. Otherwise, you can look in the `justfile` file to find the commands (in this case it's the default recipe, `run`, which is `cargo leptos watch`).

If you'd like to test the release version of the app, run `just serve` (`cargo leptos serve --release`).

## Deployment

If you'd like to build and run the container version of the app, run `just container`. This will build the container entirely in Nix, load it into the docker daemon, and run it ephemerally (`--rm`) with port 3000 open. The image has correct defaults for all the environment variables that `cargo-leptos` normally provides, but they're also overridable when you run the container.

To learn more about building containers in Nix, read [here](https://thewagner.net/blog/2021/02/25/building-container-images-with-nix/) (tl;dr: it's awesome).

To just build and load the docker image, run `nix build "./#container" && docker load -i result`. The image will be loaded with the label `site-server`. You can then do any normal container action with this image.

You can also build the release build with `nix build` (which builds the default package, `site-server`), but if you run it with `./result/bin/site-server`, the binary won't inherit the environment variables that `cargo-leptos` normally provides, which is why I recommend you just use the container.

# Repo Layout
- `crates/`: contains all the Rust crates
  - `site-app/`: contains all the app code, isolated from its usage
    - `src/`
      - `lib.rs`: the app code, which defines `<App/>`
    - `style/`: contains styles used by `<App/>`
      - `main.scss`: the tailwind css input file, containing the `@tailwind` directives
      - `tailwind/`: tailwind-specific files
        - `package.json`: JS manifest in case you need JS packages for your tailwind plugins (like DaisyUI)
        - `yarn.lock`: lock file for package.json
        - `tailwind.config.js`: tailwind config
        - `node_modules`: contains installed packages used to build tailwind plugins (ignored)
    - `public/`: files here will be statically served
      - `favicon.ico`: the site icon
    - `Cargo.toml`: the cargo manifest for `site-app`
  - `site-server/`: binary crate for serving the app
    - `src/`
      - `main.rs`: starts the axum server
      - `fileserv.rs`: serve static files
    - `Cargo.toml`: the cargo manifest for `site-server`
  - `site-frontend/`: stub crate for use with `wasm-bindgen`
    - `src/`
      - `main.rs`: starts the axum server
      - `fileserv.rs`: serve static files
    - `Cargo.toml`: the cargo manifest for `site-server`
- `.envrc`: `direnv` commands to automatically set up the environment
- `.gitignore`: git ignore file
- `Cargo.lock`: cargo manifest lock file
- `Cargo.toml`: cargo manifest file, which also contains leptos configuration
- `flake.lock`: nix flake lock file
- `flake.nix`: nix flake file
- `justfile`: just recipe file
