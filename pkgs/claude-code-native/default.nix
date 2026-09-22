{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.1.280";

  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/${version}/darwin-arm64/claude";
      sha256 = "387a5c5dcdbb815085edf0baf79591f9d8894efe922bceaf3d75b1b08055229d";
    };
    x86_64-darwin = {
      url = "${baseUrl}/${version}/darwin-x64/claude";
      sha256 = "c1d32d87630482250633208ab77855429b24010ae3086a7ff7539b57b93168d4";
    };
    aarch64-linux = {
      url = "${baseUrl}/${version}/linux-arm64/claude";
      sha256 = "92f2b4fd05d0bdcf7b9a0d4e0ecef4a1e4b368b290cd8fd07cff9a50013f45a2";
    };
    x86_64-linux = {
      url = "${baseUrl}/${version}/linux-x64/claude";
      sha256 = "1e08503dbdf3c2cb0d706d32f3408277388d1c76ef108673e8fe42c1b322925b";
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
