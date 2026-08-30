// Pins a single piece of text to the device's lock screen as an ongoing
// reminder. Deliberately takes primitives rather than a Note: this is a
// thin "pin this text" port that knows nothing about the note aggregate —
// every presentation rule (what an untitled note is called, what a locked
// note reveals) stays in the ViewModel above it, and a fake implementation
// needs no domain objects to be useful in a test.
abstract class LiveNoteService {
  // Shows or replaces the single live notification. Returns false if the
  // OS won't let us post one (permission off or revoked).
  Future<bool> show({
    required String noteId,
    required String title,
    required String body,
  });

  // Takes the live notification down. Safe to call when nothing is showing.
  Future<void> hide();

  // Whether the system currently has our live notification posted. Used
  // to self-heal when the user swipes it away.
  Future<bool> isShowing();
}
