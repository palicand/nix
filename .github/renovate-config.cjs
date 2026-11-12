module.exports = {
  platform: 'github',
  repositories: [process.env.GITHUB_REPOSITORY],
  onboarding: false,
  requireConfig: 'required',
  branchPrefix: 'renovate-self-hosted/',
  repositoryCache: 'enabled',
  force: { enabled: true },
  allowedCommands: [
    '^bash pkgs/(codex|kotlin-lsp|claude-code-native)/update\\.sh v?[0-9]+\\.[0-9]+\\.[0-9]+$',
    '^nix flake update (herdr|brew-src)$',
  ],
  secrets: { githubToken: process.env.RENOVATE_TOKEN },
  customEnvVariables: {
    GH_TOKEN: '{{ secrets.githubToken }}',
    NIX_CONFIG: 'experimental-features = nix-command flakes',
  },
};
