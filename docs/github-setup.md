# Putting this on GitHub

The archive already contains a git repository with one commit on `main` and a
`v0.2.0` tag, so there is nothing to initialise.

## First push

Create an **empty** repository on GitHub — no README, no licence, no
`.gitignore`, or the first push will be rejected as unrelated history. Then:

```bash
cd shelves
git remote add origin git@github.com:<you>/shelves.git
git push -u origin main --follow-tags
```

Over HTTPS use `https://github.com/<you>/shelves.git` instead and sign
in with a personal access token when prompted.

If you would rather keep your own identity on the commit:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
git commit --amend --reset-author --no-edit
git tag -f -a v0.2.0 -m "v0.2 — Fast mode shell"
```

## What CI does on that first push

`.github/workflows/ci.yml` runs two jobs:

- **Godot** — downloads Godot 4.7, imports the project, runs
  `tools/selftest.tscn` headless, and fails on any `SCRIPT ERROR` in the log.
- **Android plugin** — sets up JDK 17 and the Android SDK, runs
  `gradle assemble`, and uploads the AAR as a build artifact.

The second job is the useful one right now: the Kotlin side has never been
compiled, so the first run will most likely be red. Read the Gradle log, fix,
push again. Once it is green you can download the AAR from the run page
instead of building it locally.

## Releases

Tagging is what marks a milestone:

```bash
git tag -a v0.3.0 -m "v0.3 — Library and folders"
git push --follow-tags
```

Add the APK to the GitHub release by hand for now. Building and signing one in
CI needs an export preset and a keystore in repository secrets — worth adding
once the export settings have settled.

## Keeping the design document with the code

The design document currently lives in a chat project. Copying it to
`docs/design.md` and editing it in commits means the "Open questions" section
has a history: you can see when an answer changed and why. Answers that are
still open are a good fit for GitHub issues, one per question.
