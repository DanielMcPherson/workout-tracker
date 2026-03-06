# Workout Tracker

Personal app, only ever installed on one phone.

## Android Release Keystore

- Path: `~/.android/workout-tracker-release.keystore`
- Backup: `~/Documents/workout-tracker-release.keystore.bak`
- Alias: `workout`
- Password: `workout123`

## Data Files

All data lives at `Internal Storage/Documents/WorkoutTracker/` on the phone:

- `program_config.json` — workout program definition, edit this directly over USB to change the program
- `progress.json` — last weight/reps per exercise
- `workout_history.json` — completed workout log

On first launch after a fresh install, `program_config.json` is seeded from the bundled `res://program_config.json`.

## Editing the Program

Nautilus MTP is broken on Linux — use adb to transfer files.

Pull the file from the phone to edit it:
```bash
adb pull /sdcard/Documents/WorkoutTracker/program_config.json ~/godot/workout-tracker/program_config.json
```

Edit it, then push it back:
```bash
adb push ~/godot/workout-tracker/program_config.json /sdcard/Documents/WorkoutTracker/program_config.json
```

The app reads the file fresh on each launch, so just restart the app on the phone after pushing.

Also commit the updated `program_config.json` to git to keep it in sync with the repo.

## Deployment

The APK is signed with the release keystore above. Never needs to be redeployed — change the program by editing `program_config.json` directly on the phone via USB (see above).

If a reinstall is ever necessary:
1. Copy keystore to a visible location: `cp ~/.android/workout-tracker-release.keystore ~/workout-tracker-release.keystore`
2. Export APK from Godot with the release keystore
3. `adb install ~/godot/workout-tracker/builds/workout-tracker.apk`
