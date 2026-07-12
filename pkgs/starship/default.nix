{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "1.26.0";
  baseUrl = "https://github.com/starship/starship/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/starship-aarch64-apple-darwin.tar.gz";
      sha256 = "c40b27b11f580411e068f2fa6c1be7830a387c0bc47a94d1d37f32b054c5361d";
    };
    x86_64-darwin = {
      url = "${baseUrl}/starship-x86_64-apple-darwin.tar.gz";
      sha256 = "5548f406a4b6f5695903bdea83f77ce47ec12c8c0e62dabd33122d8f133e4207";
    };
    aarch64-linux = {
      url = "${baseUrl}/starship-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b";
    };
    x86_64-linux = {
      url = "${baseUrl}/starship-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3";
    };
  };

  inherit (stdenv.hostPlatform) system;
  source = sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  pname = "starship";
  inherit version;

  src = fetchurl {
    inherit (source) url sha256;
  };

  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf $src -C source
    cd source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 starship $out/bin/starship
    runHook postInstall
  '';

  meta = {
    description = "Minimal, blazing-fast, and infinitely customizable prompt";
    homepage = "https://starship.rs";
    license = lib.licenses.isc;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "starship";
  };
}
