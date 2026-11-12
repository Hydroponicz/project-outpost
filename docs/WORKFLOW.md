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
