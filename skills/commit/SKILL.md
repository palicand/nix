---
name: commit
description: This skill should be used when the user asks to "commit", "create a commit", "commit changes", "commit my changes", "make a commit", or wants to stage and commit code changes with a proper commit message. Use this for any git commit operations.
allowed-tools: ["Bash(git status:*)", "Bash(git diff:*)", "Bash(git add:*)", "Bash(git commit:*)", "Bash(git log:*)", "Bash(git branch:*)"]
---

# Smart Commit Skill

Create git commits with AI-generated messages following Conventional Commits specification, adapting to repository-specific patterns when detected.

## Context Gathering

First, gather all necessary context:

```bash
# Check for changes
git status --porcelain

# View staged and unstaged changes
git diff HEAD

# Get current branch name
git branch --show-current

# Review recent commit history to detect patterns
git log --oneline -15
```

## Commit Style Detection

**Check if the repository uses a different commit convention** by analyzing recent commits:

1. **Conventional Commits** (default): `type(scope): description`
   - Pattern: Commits start with `feat:`, `fix:`, `chore:`, `docs:`, etc.

2. **BKBN Style**: `type/[ISSUE-ID] description`
   - Pattern: Commits like `feature/[ISSUE-123] add feature`
   - Extract issue ID from branch name if present

3. **Other patterns**: Match whatever style the repository uses consistently

If >=70% of recent commits follow a recognizable pattern, use that pattern. Otherwise, default to Conventional Commits.

## Staging Strategy

### Files Changed in This Session
Stage automatically if they appear related to the current work:
- Modified files that were touched in recent conversation
- New files that were created as part of the task

### Other Unstaged Files
For files not clearly related to the session:
- List them and ask the user which to include
- Never auto-stage files that might be unrelated

### Never Stage These Files
- `.env`, `.env.*`, `*.local`
- `credentials*`, `*secret*`, `*.key`, `*.pem`
- `node_modules/`, `target/`, `build/`, `dist/`
- IDE configs unless explicitly requested

## Conventional Commits Format

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

### Types (REQUIRED)
| Type | Description | SemVer |
|------|-------------|--------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | - |
| `style` | Formatting, no code change | - |
| `refactor` | Code change, no feature/fix | - |
| `perf` | Performance improvement | - |
| `test` | Adding/correcting tests | - |
| `build` | Build system or dependencies | - |
| `ci` | CI configuration | - |
| `chore` | Other maintenance | - |

### Scope (optional)
Noun describing section of codebase in parentheses:
- `feat(parser):` `fix(api):` `docs(readme):`

### Breaking Changes
- Append exclamation mark before the colon, e.g. `feat!:` or `feat(api)!:`
- Include `BREAKING CHANGE:` footer with explanation

## Message Guidelines (from cbea.ms, CC takes precedence)

1. **Separate subject from body with blank line**

2. **Subject line max 50 characters** (hard limit: 72)

3. **Capitalize subject** - First letter uppercase
   - `feat: Add user authentication` (correct)
   - `feat: add user authentication` (incorrect)

4. **No period at end of subject**

5. **Imperative mood** - Write as a command
   - "Add feature" not "Added feature"
   - Test: "If applied, this commit will [your subject]"

6. **Body wrapped at 72 characters**

7. **Body explains what and why, not how**
   - Code shows how; commit explains motivation
   - Don't just list the changes, they can be seen in the diff

8. **Body is optional, include only when change is non-trivial**

## Workflow

1. **Analyze changes:**
   - Read diffs to understand what changed
   - Identify the primary type of change
   - Determine appropriate scope if applicable

2. **Detect repository pattern:**
   - Check recent commits for consistent style
   - Use detected pattern or default to Conventional Commits

3. **Stage appropriate files:**
   - Stage session-related changes automatically
   - Ask about unrelated unstaged files

4. **Generate commit message:**
   - Choose correct type based on changes
   - Write concise subject in imperative mood
   - Add body only if needed for context

5. **Show proposal before committing:**
   ```
   ## Proposed Commit

   **Message:**
   feat(auth): Add OAuth2 login flow

   Implement OAuth2 authentication with Google provider.
   Includes token refresh and session management.

   **Files to commit:**
   - src/auth/oauth.ts (new)
   - src/auth/session.ts (modified)
   - src/config/auth.ts (modified)

   **Staged separately (not included):**
   - .env.example (unrelated)
   ```

6. **Create the commit:**
   ```bash
   git commit -m "$(cat <<'EOF'
   feat(auth): Add OAuth2 login flow

   Implement OAuth2 authentication with Google provider.
   Includes token refresh and session management.

   Co-Authored-By: <active-agent-name> <active-agent-email>
   EOF
   )"
   ```

## Examples

### Simple Feature
```
feat: Add dark mode toggle
```

### Feature with Scope
```
feat(ui): Add dark mode toggle to settings panel
```

### Bug Fix with Body
```
fix(api): Handle null response from payment gateway

The payment API occasionally returns null instead of an error
object when the service is degraded. This caused unhandled
exceptions in the checkout flow.
```

### Breaking Change
```
feat(api)!: Change authentication to JWT

BREAKING CHANGE: API now requires Bearer token instead of
session cookie. All clients must update authentication logic.
```

### Chore
```
chore(deps): Update lodash to 4.17.21
```

### BKBN Style (when detected)
```
feature/[BKBN-1234] add user authentication endpoint
```

## Important Notes

- Always use HEREDOC for commit messages to preserve formatting
- Include a `Co-Authored-By` footer identifying the active coding agent,
  using that agent's canonical name and email. Do not hard-code an agent or
  provider; replace the placeholders from the workflow example.
- Run formatters if available before committing (spotlessApply, prettier, etc.)
- Never commit without showing the proposal first
- If no changes exist, inform the user and exit
