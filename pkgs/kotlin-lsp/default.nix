{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "262.8190.0";

  baseUrl = "https://download-cdn.jetbrains.com/language-server/kotlin-server/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.sit";
      sha256 = "e20183262784bb7e665ce1aea4855872a8b16f211ebb478d452773553732d9fb";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}.sit";
      sha256 = "f3845ae9ee38c22ef5e436390d86a3d908f77073e9667fa643a5ae0957c19728";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.tar.gz";
      sha256 = "c3edd59ef34a7faa4d04f3517afb7a932b19c3f9cf17d1a14e9da17b0b5440ad";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-server-${version}.tar.gz";
      sha256 = "8b4c70e95065420e7867c99aaf9f18e0b4e76311ec453e4c1a39e3f6ae774cbf";
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
