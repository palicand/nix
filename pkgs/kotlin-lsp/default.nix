{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "271.2085.0";

  # The public endpoint supplies signed CDN redirects required for archives.
  baseUrl = "https://download.jetbrains.com/language-server/kotlin-server/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.sit";
      sha256 = "2d22388f58be6f4dfa7a8f18c1e231871164dcacc16e407559029d7232816b4a";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}.sit";
      sha256 = "68457ab1825331e3eac85191b7c32737cbd8993867f5a9c50dfe012c5509e8f7";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.tar.gz";
      sha256 = "877aee612a17dab48144466282a6414ec58ab428a10b97c7e13edd9b6b3dc96e";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-server-${version}.tar.gz";
      sha256 = "e398e799027f41749ea33faa57470307d13d40f910961858c7e30adbd778ae08";
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
