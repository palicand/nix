{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
}:

let
  version = "2.1.310";

  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/${version}/darwin-arm64/claude";
      sha256 = "ffb64331bc0ee1b69efb7c2c428bd3ab516bc31b75bf60886b356c97c1c25ffd";
    };
    x86_64-darwin = {
      url = "${baseUrl}/${version}/darwin-x64/claude";
      sha256 = "28fdbed5a84ef7d4205b5751c7f021e79151c4e319c4a401e48fe6aae86bbb39";
    };
    aarch64-linux = {
      url = "${baseUrl}/${version}/linux-arm64/claude";
      sha256 = "9c64d9a7442436b65fcd7cc02c1aa0051bb5a7041e7788576ed3b5f29c447d54";
    };
    x86_64-linux = {
      url = "${baseUrl}/${version}/linux-x64/claude";
      sha256 = "b73676430af12f97316a798b8371f81d640f90a58bdcb8f3ce56a835bb47df56";
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
      --set DISABLE_AUTOUPDATER 1 \
      --set FORCE_AUTOUPDATE_PLUGINS 1
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
