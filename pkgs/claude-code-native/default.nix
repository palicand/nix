{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.1.285";

  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/${version}/darwin-arm64/claude";
      sha256 = "51f09bd1e021d9fa8a1864c179799bd37cb39962a937935c5cf6823398e86db4";
    };
    x86_64-darwin = {
      url = "${baseUrl}/${version}/darwin-x64/claude";
      sha256 = "24835f7ca4b4338c33ad21c98a3402d9c22f89b8055075d18828e97973844ec3";
    };
    aarch64-linux = {
      url = "${baseUrl}/${version}/linux-arm64/claude";
      sha256 = "24fac77749bed3d91365d6b6915aa4b824e14318ecb6bc17adbc192f01c9173d";
    };
    x86_64-linux = {
      url = "${baseUrl}/${version}/linux-x64/claude";
      sha256 = "33dad1ec615a2e08cc78b494f05c110e49916de2c79d78ec8799ebf46b233d29";
    };
  };

  inherit (stdenv.hostPlatform) system;
  source = sources.${system} or (throw "Unsupported system: ${system}");

in
stdenv.mkDerivation {
  pname = "claude-code-native";
  inherit version;

  src = fetchurl {
    inherit (source) url sha256;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  # CRITICAL: Do not strip on Darwin - breaks code signature
  dontStrip = stdenv.hostPlatform.isDarwin;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/claude
    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1
  '';

  meta = {
    description = "Claude Code - Agentic coding tool (native binary)";
    homepage = "https://claude.ai/code";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "claude";
  };
}
