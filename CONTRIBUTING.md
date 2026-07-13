# Contributing

## Prerequisites

- Godot 4.7 or another team-approved compatible version
- Git 2.x
- Git LFS (`git lfs install` once per workstation)

## First-time setup

```sh
git clone <repository-url>
cd BossChaseDemo
git lfs pull
```

Import `project.godot` in Godot. Files under `.godot/` are generated locally and
must not be committed.

## Branch workflow

1. Update `main`: `git switch main && git pull --ff-only`.
2. Create a short-lived branch, such as `feature/player-dash`,
   `fix/lobby-sync`, or `docs/controls`.
3. Keep commits focused and use an imperative summary, for example
   `Add boss charge warning`.
4. Push the branch and open a pull request into `main`.
5. Ask at least one teammate to review gameplay or scene changes before merge.

Do not commit directly to `main` once a shared remote is configured. Prefer
small pull requests, and mention the Godot version used for changes that rewrite
scene or resource files.

## Before opening a pull request

- Open the project without parse or import errors.
- Run the main scene and test the affected gameplay path.
- Confirm `git status` contains no `.godot/`, logs, exports, or personal IDE files.
- Confirm large video changes are stored by Git LFS with `git lfs ls-files`.
- Describe what changed, how it was tested, and attach screenshots or video when
  the result is visual.

## Avoiding Godot merge conflicts

- Coordinate ownership of frequently edited `.tscn` scenes.
- Put reusable logic in `.gd` scripts and reusable data in `.tres` resources.
- Do not re-save unrelated scenes or resources.
- Resolve scene conflicts carefully in a text editor, then reopen the scene in
  Godot before committing the resolution.

