# qs_leptos

This is a template project for Leptos apps, using TailwindCSS for styling and Nix for packaging and environments.

## Getting Started

> This repo is built to be used with Nix. If you don't have it, go [here](https://nixos.org/download/) to install it. In short, Nix is a package manager built for reproducible builds and immutability. It should be perfectly usable without Nix, but you should be familiar with installing the necessary tools because I won't go over all the non-Nix instructions.

If you have `direnv` installed, simply `direnv allow`, and after some minutes you'll have your dev environment. If not, you can use `nix develop` to do the same thing (assuming you've set up [flakes and the new command syntax](https://nixos.wiki/wiki/Flakes#Enable_flakes_temporarily))

### Development
To start developing, simply run `just` if you have `just` installed. If you don't know what I'm talking about, you can look in the `just` file to find the commands. In this case it's the first recipe (`run`), which is `cargo leptos watch`.

If you'd like to test the release version of the app, run `just serve` (`cargo leptos serve --release`).

If you'd like to build and run the container version of the app, run `just container`. This will build the container entirely in Nix, load it into the docker daemon, and run it ephemerally (`--rm`) with port 3000 open. To learn more about building containers in Nix, read [here](https://thewagner.net/blog/2021/02/25/building-container-images-with-nix/) (tl;dr: it's awesome).

## Repo Layout
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
