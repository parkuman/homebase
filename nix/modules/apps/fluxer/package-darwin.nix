# Fluxer desktop client for macOS: repackages the official universal release
# dmg (same one the Homebrew cask uses). Building from source on darwin isn't
# supported here (see package.nix for the Linux source build).
#
# The app's built-in self-updater can't write to the Nix store; bump `version`
# and `hash` instead:
#   nix store prefetch-file --json \
#     "https://pkgs.fluxer.com/desktop/stable/darwin/arm64/<version>/dmg"
{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fluxer-desktop";
  version = "2026.1124.64728";

  src = fetchurl {
    url = "https://pkgs.fluxer.com/desktop/stable/darwin/arm64/${finalAttrs.version}/dmg";
    hash = "sha256-rksWKFue5XYvlXQ9Ly96I4JvwFMLRnCwGZFFlhJ/IGY=";
    name = "Fluxer-${finalAttrs.version}.dmg";
  };

  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";

  # the dmg is APFS, which undmg can't read; 7zz can
  unpackPhase = ''
    runHook preUnpack
    7zz x -snld "$src" -o. -y >/dev/null
    # 7zz extracts xattrs as stray "file:attr" files, which break the code seal
    find . -name '*:*' -delete
    runHook postUnpack
  '';

  # don't touch the signed bundle
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -R Fluxer.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "A free and open source instant messaging and VoIP chat app";
    homepage = "https://fluxer.app/";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
  };
})
