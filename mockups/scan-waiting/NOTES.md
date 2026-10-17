# Scan waiting screen: 4 directions

Pages: `features/scan-N/v1-early.html` (1,204 of 41,280 checked, nothing found) and `v2-mid.html` (18,930 checked, 212 near a stadium, 3 venues, 2 games, third venue still matching). `scan-1/v3-done.html` is the celebration sketch. PNGs in `png/`. `gen.py` regenerates the pages.
Honesty rules for all four: the bar is photos checked / total, nothing else. Pins, tickets and dots appear only when the scanner emits a real result. A venue with no matched game yet shows as pending (ring or dashed), never as a game. Privacy line sits at the bottom of every state.

## 1. Map that fills in (recommended)
Motion: pin drops from 24pt above and settles, 0.45s spring (response .4, damping .65); dots within ~95pt of the pin brighten over 0.8s easeOut; the list row slides in 0.3s easeOut. Counter uses contentTransition(.numericText). Reduce Motion: pin and dots cross-fade 0.2s, no drop.
SwiftUI: dot grid drawn once in Canvas from a bundled low-res land mask (our own data, no assets); pins as overlay Views in ZStack positioned by the same projection; lit dots recomputed only when a venue is added. SF Symbols: pause, lock. Pin pulse = repeating scaleEffect on one view.
Cost: lowest of the four. Canvas redraws only on a new venue (a few dozen times per scan). No continuous animation, so no extra CPU or battery beyond the scan itself.
Done (v3): map settles, amber arcs from home venue draw in 0.9s (trim 0 to 1, easeInOut, 60ms stagger), "47" counts up 0.8s, champagne check chip scales in once with a light haptic. Reduce Motion: final frame appears with a 0.2s fade.

## 2. Season timeline grid
Motion: the current month cell has an amber outline that steps forward month by month (0.25s easeOut, no continuous motion); finished months fade to density tone 0.3s; a game dot scales 0 to 1 with overshoot 0.4s spring and a soft glow that fades out in 1s. Reduce Motion: no scale, 0.2s fade.
SwiftUI: LazyVGrid 13 columns or Canvas; month tone = photos in that month from PhotoKit metadata (known up front, cheap). Scan oldest to newest so the cursor moves forward. Hollow ring = venue found, game not yet matched.
Cost: low. State-driven animation only on month change (about 175 steps) and on game finds.

## 3. Ticket stack and stamps
Motion: new ticket drops in from above with a slight rotation, 0.5s spring, then its round stamp thumps on (scale 1.4 to 1, 0.25s easeIn, rotate -6 degrees) with a soft haptic; older tickets slide down 62pt, 0.35s easeInOut. Dashed ghost slot shows a pending venue. Reduce Motion: tickets fade in, stamp appears without the thump, no haptic change.
SwiftUI: ticket as a Shape with two circular notch cutouts (even-odd path), stamp = Circle strokes plus Text, rotation via rotationEffect; stack in ZStack ordered by date, cap visible tickets at 4 and collapse the rest into the counter. SF Symbols: pause, lock only.
Cost: low to medium. Shadows on 3 to 4 stacked layers; set drawingGroup() on the stack. Empty most of the time.

## 4. Calm radar
Motion: sweep wedge rotates 360 degrees in 6s linear, repeating; blips fade in with a 1.2s ring ripple (scale 1 to 2, opacity .4 to 0); facts rotate every 4s with a 0.35s cross-fade (a checkmark SF Symbol swaps with symbolEffect). Reduce Motion: no rotation, a fixed wedge, facts still rotate (cross-fade only).
Facts (all true of the pipeline): Checking dates against real schedules / Looking for photos taken near a stadium / Matching photos to games on this iPhone / Photos stay on your device.
SwiftUI: TimelineView(.animation) driving a Canvas for rings and wedge (angle = time mod 6s), or a single rotationEffect on an AngularGradient mask; numbers via numericText.
Cost: highest here, a continuous 60fps redraw. Cap with TimelineView(.animation(minimumInterval: 1/30)), pause when the app is backgrounded or low power mode is on.
