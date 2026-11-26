# Fluxer desktop client (https://github.com/fluxerapp/fluxer), built from source.
#
# Adapted from sodiboo's derivation:
# https://turning.computers.gay/sodiboo/system/src/commit/ec982b4311bc76509a201ae4dfb89b0ff6bbf5dc/personal/pkgs/fluxer.nix
#
# Differences vs. that version (upstream moved on since):
# - Everything is one Cargo workspace / Cargo.lock now, so there is a single
#   cargoDeps and the native addons are built by upstream's own build script
#   instead of one derivation per addon.
# - Upstream supports FLUXER_CI_BIN and FLUXER_SYSTEM_LIBS=1 natively, so the
#   two local patches are no longer needed (the glibc check is skipped for the
#   `dir` target).
#
# To bump: change `rev`/`version`, set the three hashes to lib.fakeHash and
# rebuild; nix reports the right ones.
{
  lib,
  stdenv,
  makeWrapper,
  fetchFromGitHub,

  nodejs_26,
  nodejs-slim_26,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  electron_44,

  cargo,
  rustc,
  fetchCrate,
  rustPlatform,

  buildWasmBindgenCli,

  lld,
  clang,
  pkg-config,

  openssl,
  libfido2,
  pipewire,
  udev,
  zstd,
}:
let
  pname = "fluxer-desktop";
  # Latest desktop-stable tag before `rev`; only used for the app's version string.
  version = "2026.1124.64728-unstable-2026-11-25";
  rev = "58062ed2e5fc57f3a9754748874d365b23690148";
  app-id = "app.fluxer.Fluxer";

  src = fetchFromGitHub {
    owner = "fluxerapp";
    repo = "fluxer";
    inherit rev;
    hash = "sha256-oqFhWDjiVnvAeqD+7UN2nt3d1HD/BC/LgIIJGXa7hho=";
  };

  nodejs = nodejs_26;
  pnpm = pnpm_11.override { nodejs-slim = nodejs-slim_26; };
  electron = electron_44;

  pnpmDeps = fetchPnpmDeps {
    pname = "fluxer";
    inherit src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-5lAz/MfiiQZDW8/+GF+5TF8tCmHVoSrN0prLpgkybcU=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    name = "fluxer";
    inherit src;
    hash = "sha256-EQMrTc2b629uQZz+SGVspcSNXz4KKY2pQY3nwhtDQDM=";
  };

  # Must match the wasm-bindgen entry in the root Cargo.lock.
  wasm-bindgen-cli = buildWasmBindgenCli rec {
    src = fetchCrate {
      pname = "wasm-bindgen-cli";
      version = "0.2.128";
      hash = "sha256-a7lcXJnnZkYReja+iUO7NqqrWyv3toxnUgQb8s4IS5s=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      inherit (src) pname version;
      hash = "sha256-R1Tas33Ursy8kqsxguAkG0ZhNed2n5uFTAhw1l2qlLY=";
    };
  };

  fluxer-ci = rustPlatform.buildRustPackage {
    name = "fluxer-ci";
    inherit src cargoDeps;
    buildAndTestSubdir = "tools/ci";
    doCheck = false;

    meta.mainProgram = "fluxer-ci";
  };
in
stdenv.mkDerivation {
  inherit
    pname
    src
    version
    pnpmDeps
    cargoDeps
    ;

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
    cargo
    rustc
    clang.cc
    lld
    pkg-config
    rustPlatform.cargoSetupHook
    rustPlatform.bindgenHook
    fluxer-ci
    wasm-bindgen-cli
    electron
  ];

  buildInputs = [
    zstd
    openssl
    libfido2
    pipewire
    udev
  ];

  env = {
    npm_config_nodedir = nodejs;
    BUNDLE_LOCAL_ASSETS = true;
    ELECTRON_ARCH = "x64";
    FLUXER_CI_BIN = lib.getExe fluxer-ci;
    # link against the Nix libfido2 instead of bundling it / asserting Ubuntu ABI
    FLUXER_SYSTEM_LIBS = "1";
    # no self-updates
    FLUXER_OFFLINE = "1";
  };

  postPatch = ''
    patchShebangs --build tools/ci/run.sh
  '';

  preBuild = ''
    (
      cd fluxer_desktop
      echo "version is: $version"
      pnpm version $version --no-git-tag-version --allow-same-version
    )
  '';

  buildPhase = ''
    runHook preBuild

    (
      cd fluxer_desktop
      pnpm build

      cp -r ${electron.dist} electron-dist
      chmod -R +w electron-dist

      pnpm exec electron-builder \
        --dir --linux --x64 \
        -c.electronDist=electron-dist \
        -c.electronVersion=${electron.version} \
        --config electron-builder.config.cjs
    )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/${app-id}
    cp -t $out/share/${app-id} -r ./fluxer_desktop/dist-electron/linux-unpacked/resources/*

    mkdir -p $out/bin
    makeWrapper ${lib.getExe electron} $out/bin/fluxer-desktop \
      --add-flags "$out/share/${app-id}/app.asar"

    (
      cd fluxer_desktop/packaging/linux
      substituteInPlace ${app-id}.desktop \
        --replace-fail "Exec=${app-id}" "Exec=$out/bin/fluxer-desktop"

      install -Dm444 ${app-id}.desktop $out/share/applications/${app-id}.desktop
      install -Dm444 ${app-id}.metainfo.xml $out/share/metainfo/${app-id}.metainfo.xml
      install -Dm444 ${app-id}.svg $out/share/icons/hicolor/scalable/apps/${app-id}.svg
    )

    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 fluxer_desktop/dist-electron/linux-unpacked/resources/icons/"$size"x"$size".png \
        $out/share/icons/hicolor/"$size"x"$size"/apps/${app-id}.png
    done

    runHook postInstall
  '';

  meta = {
    description = "A free and open source instant messaging and VoIP chat app";
    license = lib.licenses.agpl3Plus;
    homepage = "https://github.com/fluxerapp/fluxer";
    mainProgram = "fluxer-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
