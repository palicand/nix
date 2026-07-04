{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.1.201";

  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/${version}/darwin-arm64/claude";
      sha256 = "a0852d76afc47b30f5cb0b7625ec9a7714cb189f2eeef6c28c77e2be954fb7fd";
    };
    x86_64-darwin = {
      url = "${baseUrl}/${version}/darwin-x64/claude";
      sha256 = "1889287a92d25356ae8bd8d8e67b11456015516ee8ba4277a0c7074786c49bb6";
    };
    aarch64-linux = {
      url = "${baseUrl}/${version}/linux-arm64/claude";
      sha256 = "86b2eab34d382c7b428fc2e9f4c97f04e46805e950582472a13eb7d48de60516";
    };
    x86_64-linux = {
      url = "${baseUrl}/${version}/linux-x64/claude";
      sha256 = "a34809a6839fdefff21b9347d7fb5b6b58e6a9cc208a5e62853f29c83eb107a3";
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
