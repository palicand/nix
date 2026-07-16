{
  config,
  pkgs,
  lib,
  ...
}:

let
  # The one switch: true = brew-style "pull latest on every darwin-rebuild switch"
  upgradeOnActivation = false;

  # Agent name (must be a valid `skills add -a` value) -> skills dir under $HOME.
  # Both dirs are two levels below $HOME; the relative links below assume that.
  agentSkillDirs = {
    claude-code = ".claude/skills";
    codex = ".codex/skills";
  };

  # Third-party skills, installed and owned by `npx skills` (brew model:
  # declared here, installed by the native tool, additive like cleanup=none).
  externalSkills = [
    {
      source = "coreyhaines31/marketingskills";
      skills = [
        "copywriting"
        "product-marketing"
      ];
    }
    {
      source = "vercel-labs/skills";
      skills = [ "find-skills" ];
    }
  ];

  homeDir = config.home.homeDirectory;
  outOfStore = config.lib.file.mkOutOfStoreSymlink;

  # Self-written skills: every directory under <repo>/skills, no registration needed.
  localSkills = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../../skills)
  );

  # <name> -> ~/.agents/skills/<name> -> ~/.nixpkgs/skills/<name> (live-editable),
  # plus per-agent links into the canonical dir.
  localSkillLinks = lib.listToAttrs (
    lib.concatMap (
      name:
      [
        {
          name = ".agents/skills/${name}";
          value.source = outOfStore "${homeDir}/.nixpkgs/skills/${name}";
        }
      ]
      ++ map (dir: {
        name = "${dir}/${name}";
        value.source = outOfStore "${homeDir}/.agents/skills/${name}";
      }) (lib.attrValues agentSkillDirs)
    ) localSkills
  );

  npx = "${pkgs.nodejs}/bin/npx";
  # The CLI's bin resolves node via /usr/bin/env and shells out to git clone;
  # home-manager's activation PATH has neither.
  skillsPath = "${pkgs.nodejs}/bin:${pkgs.git}/bin:$PATH";
  agentFlags = lib.concatMapStringsSep " " (a: "-a ${a}") (lib.attrNames agentSkillDirs);

  # Install a source's skills only when absent from ~/.agents/skills —
  # presence is a filesystem check, so the happy path never invokes npx.
  # Repeated -a flags: a single agent flips the CLI into copy mode (no
  # canonical ~/.agents dir); space-separated multi-values misparse.
  installSnippet =
    { source, skills }:
    ''
      for skill in ${lib.concatStringsSep " " skills}; do
        if [ ! -e "$HOME/.agents/skills/$skill" ]; then
          run env PATH="${skillsPath}" ${npx} -y skills add ${source} -g -s "$skill" ${agentFlags} -y \
            || echo "warning: skills add $skill from ${source} failed (offline?)"
        fi
      done
    '';

  # Re-create a missing agent link without reinstalling (a `skills add` re-run
  # would pull HEAD, i.e. a surprise upgrade). Same relative-link convention
  # as the CLI; both agent dirs sit two levels below $HOME.
  relinkSnippet =
    { skills, ... }:
    lib.concatMapStrings (
      skill:
      lib.concatMapStrings (dir: ''
        if [ -e "$HOME/.agents/skills/${skill}" ] \
          && [ ! -e "$HOME/${dir}/${skill}" ] && [ ! -L "$HOME/${dir}/${skill}" ]; then
          run mkdir -p "$HOME/${dir}"
          run ln -s "../../.agents/skills/${skill}" "$HOME/${dir}/${skill}"
        fi
      '') (lib.attrValues agentSkillDirs)
    ) skills;
in
{
  home.file = localSkillLinks;

  home.activation.externalAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    ''
      run mkdir -p "$HOME/.agents/skills"
    ''
    + lib.concatMapStrings installSnippet externalSkills
    + lib.concatMapStrings relinkSnippet externalSkills
    + lib.optionalString upgradeOnActivation ''
      run env PATH="${skillsPath}" ${npx} -y skills update -g -y || echo "warning: skills update failed (offline?)"
    ''
  );
}
