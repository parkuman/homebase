# immich-public-proxy 4.x: npm workspaces monorepo (shared/ + app/ + upload-app/)
# that builds two programs: the read-only gallery proxy and the optional upload service.
# Upstream: https://github.com/alangrainger/immich-public-proxy
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "immich-public-proxy";
  version = "4.1.1";

  src = fetchFromGitHub {
    owner = "alangrainger";
    repo = "immich-public-proxy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Ozm6vQ3me9xa4qxcho5sUD1UZiQxquPDgjJqqoKz6Jo=";
  };

  # package-lock.json is at the repo root and covers every workspace
  npmDepsHash = "sha256-kwGHYuP0PDxs+7GpiGsdKq6o+F6Hu0Fi7mBdwI8Ciws=";

  nativeBuildInputs = [ makeWrapper ];

  # root `npm run build` runs `tsc` in shared, app and upload-app (in that order)
  npmBuildScript = "build";

  # The default install phase packs a single package; we need the whole workspace
  # (node_modules/@ipp/core is a symlink to ../../shared), so install by hand.
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --no-audit --no-fund

    mkdir -p $out/lib/ipp
    cp -r package.json node_modules shared app upload-app $out/lib/ipp/

    # tests, sources and docs aren't needed at runtime
    rm -rf $out/lib/ipp/*/tests $out/lib/ipp/*/src/client

    # Both apps serve ./public relative to the cwd and read ../config.json relative
    # to dist/, so run each from its own directory.
    makeWrapper ${lib.getExe nodejs} $out/bin/immich-public-proxy \
      --chdir $out/lib/ipp/app \
      --add-flags $out/lib/ipp/app/dist/index.js \
      --set NODE_ENV production
    makeWrapper ${lib.getExe nodejs} $out/bin/immich-public-proxy-upload \
      --chdir $out/lib/ipp/upload-app \
      --add-flags $out/lib/ipp/upload-app/dist/index.js \
      --set NODE_ENV production

    runHook postInstall
  '';

  meta = {
    changelog = "https://github.com/alangrainger/immich-public-proxy/releases/tag/${finalAttrs.src.tag}";
    description = "Share your Immich photos and albums in a safe way without exposing your Immich instance to the public";
    homepage = "https://github.com/alangrainger/immich-public-proxy";
    license = lib.licenses.agpl3Only;
    inherit (nodejs.meta) platforms;
    mainProgram = "immich-public-proxy";
  };
})
