# T3 Code — agent harness control surface (https://t3.codes).
#
# Upstream ships a self-contained, Bun-compiled CLI + server tarball per
# release. It is the only way to get the Pi provider today: Pi support is not
# in the stable channel (nor in the nixpkgs `t3code` package, which is still on
# an older stable release), only in nightly/preview builds.
#
# To bump: pick a tag from https://github.com/pingdotgg/t3code/releases
# (set T3CODE_CHANNEL=nightly), update `version`, then refresh `hash` with
#   nix store prefetch-file --json \
#     "https://github.com/pingdotgg/t3code/releases/download/v<version>/t3-<version>-linux-x64.tar.gz"
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3code";
  version = "0.0.46-nightly.20261009.2886";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-Y8hzNf59QBWivGgkyioK2P3G+Uos8WyKu/y/o/midaw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    # libatomic + libstdc++, needed by the Bun runtime and the native addons.
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  # The Bun single-file executable appends its payload after the ELF segments;
  # stripping it corrupts the binary (illegal instruction at runtime).
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/t3code
    # Keep the CLI next to the runtime tree (node_modules, client,
    # resource-monitor) — it resolves those relative to its own location.
    cp -a --no-preserve=ownership ./. $out/libexec/t3code/
    chmod -R u+w $out/libexec/t3code
    chmod +x \
      $out/libexec/t3code/t3 \
      $out/libexec/t3code/resource-monitor/linux-x64/t3-resource-monitor

    mkdir -p $out/bin
    makeWrapper $out/libexec/t3code/t3 $out/bin/t3

    runHook postInstall
  '';

  meta = {
    description = "Agent harness control surface (nightly, self-contained CLI + server)";
    longDescription = ''
      T3 Code runs coding agents on your machine and lets you control them from
      its web, desktop, or mobile app. This is the self-contained nightly CLI
      (including the Pi provider), built from the official release tarball.
    '';
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
