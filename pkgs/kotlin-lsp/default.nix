{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "262.4739.0";

  baseUrl = "https://download-cdn.jetbrains.com/kotlin-lsp/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.sit";
      sha256 = "1b745743ce22ad92681a1bc3b1046803e942a6e1f36e04fb85ae9a40334a2f1e";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}.sit";
      sha256 = "6f06efe7a10f94b9c8a028c4efeb6c7e1769f47a01edfb74450acf30ab5665e4";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.tar.gz";
      sha256 = "625870ae091c6d0dee25514d545c708a6ea50d7cbb5154aaf1aa9123ccff338b";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-server-${version}.tar.gz";
      sha256 = "46971110c9b8a3360ce3fdf5437467f4c447dad37ad73dbf81d64af6779e4105";
    };
  };

  inherit (stdenv.hostPlatform) system;
  source = sources.${system} or (throw "Unsupported system: ${system}");

in
stdenv.mkDerivation {
  pname = "kotlin-lsp";
  inherit version;

  src = fetchurl {
    inherit (source) url sha256;
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;
  dontStrip = true;

  # Darwin ships a `.sit` (zip payload with macOS metadata), Linux a `.tar.gz`.
  # Both wrap their contents in a top-level `kotlin-server-<version>/` dir;
  # flatten that so the rest of the derivation sees a stable `unpacked/` root.
  unpackPhase = ''
    runHook preUnpack
    mkdir staging
    case "$src" in
      *.sit) unzip -q $src -d staging ;;
      *.tar.gz) tar -xzf $src -C staging ;;
      *) echo "kotlin-lsp: unsupported archive $src" >&2; exit 1 ;;
    esac
    mv staging/*/ unpacked
    rmdir staging
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec $out/bin
    cp -r unpacked/* $out/libexec/

    # Native launcher; the deprecated kotlin-lsp.sh wrapper just exec's this.
    ln -s $out/libexec/bin/intellij-server $out/bin/kotlin-lsp
    ln -s $out/libexec/bin/intellij-server $out/bin/kotlin-language-server

    runHook postInstall
  '';

  meta = {
    description = "Kotlin Language Server Protocol implementation by JetBrains";
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    platforms = builtins.attrNames sources;
    mainProgram = "kotlin-lsp";
  };
}
