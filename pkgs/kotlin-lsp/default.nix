{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "263.7084.0";

  # The public endpoint supplies signed CDN redirects required for archives.
  baseUrl = "https://download.jetbrains.com/language-server/kotlin-server/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.sit";
      sha256 = "b403bf8a54bd458e3ba6731cf8abb3340be08b439c03576dfc02b13faf3694b8";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-server-${version}.sit";
      sha256 = "b29c393a5e541153d03d626e7946268437e358a667a5f914a126dbb4007664b1";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-server-${version}-aarch64.tar.gz";
      sha256 = "450ab7c1d80e48106aa429b48cb4226d82ca12a8a2400447ae02386794780cac";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-server-${version}.tar.gz";
      sha256 = "ae0c4b01e17ab73a4a5227a78ea99e6dcbe3e499600315b22759a4e4cddd11df";
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
