{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.1.217";

  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/${version}/darwin-arm64/claude";
      sha256 = "5840c777fd47115e9ca276e165563c6e121e7c7e2b4d86598e0025f8cc37de56";
    };
    x86_64-darwin = {
      url = "${baseUrl}/${version}/darwin-x64/claude";
      sha256 = "8387a6fd44edfd40d7e74c5fdc3270a15f5e6b1b58c7c6fee560e70d3d1943da";
    };
    aarch64-linux = {
      url = "${baseUrl}/${version}/linux-arm64/claude";
      sha256 = "40c53507ac669c1d438366c19760c22f52748a06e50e0fc0e353d2cb73425597";
    };
    x86_64-linux = {
      url = "${baseUrl}/${version}/linux-x64/claude";
      sha256 = "2630fc5dc6db61bc03f86b95daf47766e5ed5b61873f7bb7cfea764c5ac5a9ba";
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
