# Workflow

Two branches. That's it.

| Branch | What it holds | Who changes it |
|---|---|---|
| `main` | Tested, working game. Always safe to build from. | Only by merging `preview` after you've tested it |
| `preview` | The newest update, waiting to be tested | Claude pushes new work here |

## The cycle for every update
1. **We plan it** in chat first. No code until we agree.
2. **Claude builds it** and pushes it to `preview`.
3. **You test it**: in GitHub Desktop, switch to `preview`, click **Fetch origin**, then **Pull origin**. Open the project in Godot and play.
4. **Feedback or fixes**: tell Claude what's wrong. Fixes also go to `preview`. Repeat step 3.
5. **Merge when it's good**: on GitHub, open a pull request from `preview` into `main` and merge it.
   (Claude can open the pull request for you; you click Merge.)
6. Mark the step done in `docs/ROADMAP.md` and plan the next one.

## Rules
- Never commit untested work to `main`.
- One roadmap step (or one fix) per update, so it's always clear what you're testing.
- If an update goes badly wrong, `main` is untouched. We can reset `preview` back to `main` and try again.

## Notes
- Branches named `claude/...` are Claude's scratch space for each chat session. You can ignore them.

## Godot-generated files
Godot creates some files itself when it opens the project: a `.uid` file next to
every script, and `.import` files next to images. **Commit these** (they belong in
the repo); Claude can't create them because Godot doesn't run in its sandbox.

If GitHub Desktop refuses to pull because `project.godot` "would be overwritten":
1. Right-click `project.godot` in Changes → **Discard changes** (Godot just re-saved it).
2. **Pull origin**.
3. Open the project in Godot, then commit any new generated files to `preview` and push.

Claude always fetches `preview` before making changes, so your commits there are safe.
