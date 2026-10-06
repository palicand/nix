{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "263.6379.0";

  # The public endpoint supplies signed CDN redirects required for archives.
  baseUrl = "https://download.jetbrains.com/language-server/kotlin-server/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.sit";
      sha256 = "ebef2e13cd4adc4ec9e04084b848000a3ec7a9d2917c64f269574ce2efe9ecad";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}.sit";
      sha256 = "e69e0c9d27b915b2db9ee692ec08d097df1a394d9f21190457ef199f2905f77e";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.tar.gz";
      sha256 = "50999901ef8bcfa1e58561b6a8d782a72dea5620fcf92a64130807f8924a56fc";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-server-${version}.tar.gz";
      sha256 = "ab8ca4455dc2fc5fe1a24db2bccc46c104254d2c465155c4251ee65df8f3f7cc";
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
