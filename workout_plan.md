Workout Routine Specification (Final, Simplified 8–12 Rep Rule)

This file defines the full workout routine and rules used by the Workout Tracker app.
It is structured so all future development (UI, GDScript, JSON handling) has a consistent reference.

Overview

The program follows a fixed 5-workout cycle:

A → B → C → D → E → repeat

Each workout contains exactly 3 exercises, performed with:

Several warm-up sets (not logged)

1 working set to failure

Optional drop sets (not logged)

The app only tracks:

last_weight

last_reps

for each exercise.

All exercises follow the exact same progression rule.

Progression Rule (Unified for All Exercises)

To keep logic and UI simple, all exercises use this single rule:

Reps Target: 8–12

If last_reps > 12 → increase weight next time

If 8 ≤ last_reps ≤ 12 → keep same weight

If last_reps < 8 → reduce or retry the weight

There are no exercise-specific rep ranges.
Warm-ups and drop sets are not logged.

Workout A – Biceps / Chest Press / Leg Press
1. Seated DB Curl

Warm-ups → 1 working set to failure (record weight & reps)

2. Chest Press Machine

Warm-ups → 1 working set to failure

3. Leg Press

Warm-ups → 1 working set to failure

Workout B – Triceps / Pulldown / Rear Delts
1. Straight Bar Pushdown

Warm-ups → 1 working set

2. Lat Pulldown

Warm-ups → 1 working set

3. Reverse Pec Deck

Warm-ups → 1 working set

Workout C – Shoulder Press / Chest Fly / Weighted Crunch
1. Shoulder Press (Bar / Fixed Bar Machine)

Warm-ups → 1 working set

2. Chest Fly Machine

Warm-ups → 1 working set

3. Weighted Crunch Machine

Warm-ups → 1 working set
(Note: Still uses 8–12 rep rule like everything else)

Workout D – Biceps / Row / Leg Curl
1. DB Hammer Curl

Warm-ups → 1 working set

2. Row Machine

Warm-ups → 1 working set

3. Leg Curl Machine

Warm-ups → 1 working set

Workout E – Triceps / Laterals / Trackable Abs
1. Overhead Cable Extension

Warm-ups → 1 working set

2. DB Lateral Raise

Warm-ups → 1 working set

3. Cable Woodchoppers

Warm-ups → 1 working set
(App may instruct to log left/right reps together or separately — developer choice.)

App Behavior Specification
Workout Display

When the user opens the app, it loads the workout corresponding to:

meta.current_workout_index


This index increments (wrapping 0–4) after pressing Complete Workout.

Exercise Blocks

For each of the three exercises per workout:

Display exercise name

Show previous working set as:
“Last: (weight) × (reps)”

Pre-fill the weight field with the suggested weight based on the progression rule

User enters:

Weight actually used

Reps achieved

Timer

Simple count-up timer (“Timer”)

Start/Reset button resets the timer to 0 and starts it

Complete Workout Button

Saves:

New last_weight

New last_reps

Optional: append entry to a separate history file.

Advances to the next workout.

Data Model Summary
program_config.json contains only:

List of workouts A–E

Exercise IDs for each workout

A map of:

exercise_id → { name, last_weight, last_reps }


meta.current_workout_index

No rep ranges or advanced metadata required.

History file (optional)

Stores complete workout history for future export, not needed for logic.

Exercise IDs

These IDs are referenced consistently across the JSON and GDScript:

seated_db_curl
chest_press_machine
leg_press

triceps_pushdown_bar
lat_pulldown
reverse_pec_deck

shoulder_press_bar
chest_fly_machine
weighted_crunch_machine

hammer_curl_db
row_machine
leg_curl_machine

oh_cable_extension
db_lateral_raise
cable_woodchopper


Each exercise object stores:

last_weight
last_reps
