// challenge_director.dart
// Location: lib/features/face/widgets/challenge_director.dart
//
// Orchestrates the liveness challenge sequence and owns the session countdown timer.
// Pure Dart — no Flutter/UI imports. No BuildContext, no widgets.
//
// Responsibilities (per architecture doc §7.4):
//   - Receives FaceLivenessConfig on construction
//   - Builds challenge queue (shuffled or ordered per config.isRandom)
//   - Starts the session countdown timer
//   - Advances to the next challenge when ChallengeValidator reports a pass
//   - On timer expiry: emits LivenessSessionResult.timeout, resets index to 0
//   - On all challenges passed: emits LivenessSessionResult.pass
//
// ChallengeDirector does NOT know:
//   - How to detect faces (that's ChallengeValidator)
//   - How to render anything (that's the UI widgets)
//   - How many total retries have been used (that's FaceNotifier)
//
// Usage:
//   final director = ChallengeDirector(config: config);
//   director.stateStream.listen((state) { setState(() => _directorState = state); });
//   director.timerStream.listen((progress) { setState(() => _timerProgress = progress); });
//   director.start();
//
//   // When ChallengeValidator reports a pass for the current challenge:
//   director.onChallengePass();
//
//   // Always dispose when done:
//   director.dispose();

import 'dart:async';
import 'dart:math';
import 'face_liveness_config.dart';
import 'liveness_challenge.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Final outcome of a liveness session.
enum LivenessSessionResult {
  /// All challenges were passed within the session timer.
  pass,

  /// The session timer expired before all challenges were completed.
  timeout,
}

// ---------------------------------------------------------------------------
// Director state
// ---------------------------------------------------------------------------

/// Snapshot of ChallengeDirector's current state.
/// Emitted on the [ChallengeDirector.stateStream] on every meaningful change.
class ChallengeDirectorState {
  /// The challenge the user must currently perform.
  final LivenessChallenge activeChallenge;

  /// 0-based index of the active challenge in the queue.
  final int activeIndex;

  /// Total number of challenges in this session's queue.
  final int totalChallenges;

  /// Number of challenges completed so far (not counting the active one).
  final int completedCount;

  /// True if the session has ended (pass or timeout).
  /// UI should stop processing frames when this is true.
  final bool isComplete;

  /// Set when [isComplete] is true.
  final LivenessSessionResult? result;

  const ChallengeDirectorState({
    required this.activeChallenge,
    required this.activeIndex,
    required this.totalChallenges,
    required this.completedCount,
    required this.isComplete,
    this.result,
  });

  @override
  String toString() =>
      'ChallengeDirectorState(active: ${activeChallenge.value}, '
      '$completedCount/$totalChallenges, complete: $isComplete, result: $result)';
}

// ---------------------------------------------------------------------------
// ChallengeDirector
// ---------------------------------------------------------------------------

class ChallengeDirector {
  final FaceLivenessConfig config;

  // Challenge queue built from config on start()
  late final List<LivenessChallenge> _queue;

  // Current position in the queue
  int _activeIndex = 0;

  // Session countdown timer
  Timer? _sessionTimer;

  // High-frequency timer for smooth timer bar updates
  Timer? _tickTimer;

  // Remaining seconds tracked internally
  late int _remainingSeconds;

  // Streams
  final _stateController = StreamController<ChallengeDirectorState>.broadcast();
  final _timerController = StreamController<double>.broadcast();
  final _noFaceController = StreamController<bool>.broadcast();

  bool _isStarted = false;
  bool _isDisposed = false;

  // Debounce timer for the "no face detected" hint — avoids flicker on
  // single dropped frames; only surfaces after sustained absence.
  Timer? _noFaceDebounce;
  bool _noFaceHintVisible = false;

  ChallengeDirector({required this.config});

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Emits [ChallengeDirectorState] on every challenge advance and on completion.
  /// UI widgets listen to this to know which challenge is active and when done.
  Stream<ChallengeDirectorState> get stateStream => _stateController.stream;

  /// Emits a progress value from 1.0 (full) down to 0.0 (expired) roughly
  /// every 100ms. UI timer bar listens to this.
  Stream<double> get timerProgressStream => _timerController.stream;

  /// Emits true when no face has been detected for a sustained period
  /// (debounced — see [reportFaceDetected]), false once a face reappears.
  /// UI shows a "No face detected" hint when this emits true.
  Stream<bool> get noFaceDetectedStream => _noFaceController.stream;

  // ---------------------------------------------------------------------------
  // Current state (synchronous read for initial widget build)
  // ---------------------------------------------------------------------------

  LivenessChallenge get activeChallenge => _queue[_activeIndex];
  int get activeIndex => _activeIndex;
  int get totalChallenges => _queue.length;
  int get completedCount =>
      _activeIndex; // challenges before active index are done

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Builds the challenge queue and starts the session timer.
  /// Call once. Do not call again after timeout — FaceNotifier handles retries
  /// by disposing this director and creating a new one.
  void start() {
    assert(!_isStarted, 'ChallengeDirector.start() called more than once.');
    assert(!_isDisposed, 'ChallengeDirector has been disposed.');

    _isStarted = true;
    _queue = _buildQueue();
    _remainingSeconds = config.sessionDurationSeconds;

    _emitState();
    _startSessionTimer();
    _startTickTimer();
  }

  /// Disposes all timers and closes streams.
  /// Call from the parent widget's dispose() or when FaceNotifier resets.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _sessionTimer?.cancel();
    _tickTimer?.cancel();
    _noFaceDebounce?.cancel();
    _stateController.close();
    _timerController.close();
    _noFaceController.close();
  }

  // ---------------------------------------------------------------------------
  // Challenge advance
  // ---------------------------------------------------------------------------

  /// Called by FaceLivenessWidget when ChallengeValidator reports a pass for
  /// the current active challenge.
  ///
  /// Advances to the next challenge, or emits a pass result if all are done.
  /// No-op if the session is already complete or disposed.
  void onChallengePass() {
    if (_isDisposed || !_isStarted) return;
    if (_activeIndex >= _queue.length) return; // already complete

    _activeIndex++;

    if (_activeIndex >= _queue.length) {
      // All challenges complete
      _endSession(LivenessSessionResult.pass);
    } else {
      _emitState();
    }
  }

  // ---------------------------------------------------------------------------
  // Face presence reporting
  // ---------------------------------------------------------------------------

  /// Duration of sustained face absence before the "no face" hint is shown.
  /// Short enough to feel responsive, long enough to ignore single dropped frames.
  static const Duration noFaceDebounceDelay = Duration(milliseconds: 600);

  /// Called by FaceLivenessWidget on every processed frame with whether a
  /// valid face was detected ([ChallengeResult.noFace] vs other results).
  ///
  /// When a face is present, immediately clears any pending "no face" hint.
  /// When absent, starts (or keeps running) a debounce timer — only after
  /// [noFaceDebounceDelay] of continuous absence does the hint actually show.
  /// No-op if the session is already complete or disposed.
  void reportFaceDetected(bool detected) {
    if (_isDisposed || !_isStarted) return;
    if (_activeIndex >= _queue.length) return; // session complete

    if (detected) {
      // Face is back — cancel any pending hint and clear it if shown
      _noFaceDebounce?.cancel();
      _noFaceDebounce = null;
      if (_noFaceHintVisible) {
        _noFaceHintVisible = false;
        _noFaceController.add(false);
      }
      return;
    }

    // Face absent — start debounce if not already running
    if (_noFaceDebounce != null || _noFaceHintVisible) return;

    _noFaceDebounce = Timer(noFaceDebounceDelay, () {
      if (_isDisposed) return;
      _noFaceHintVisible = true;
      _noFaceController.add(true);
    });
  }

  List<LivenessChallenge> _buildQueue() {
    final list = List<LivenessChallenge>.from(config.challengeSequence);
    if (config.isRandom) {
      list.shuffle(Random.secure());
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // Private — timers
  // ---------------------------------------------------------------------------

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) return;
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _endSession(LivenessSessionResult.timeout);
      }
    });
  }

  /// High-frequency tick for smooth timer bar progress updates (~10 fps).
  void _startTickTimer() {
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isDisposed) return;
      final progress = _remainingSeconds / config.sessionDurationSeconds;
      _timerController.add(progress.clamp(0.0, 1.0));
    });
  }

  // ---------------------------------------------------------------------------
  // Private — session end
  // ---------------------------------------------------------------------------

  void _endSession(LivenessSessionResult result) {
    _sessionTimer?.cancel();
    _tickTimer?.cancel();

    if (_isDisposed) return;

    // Emit 0 progress on timeout so timer bar drains fully
    if (result == LivenessSessionResult.timeout) {
      _timerController.add(0.0);
    }

    _stateController.add(
      ChallengeDirectorState(
        activeChallenge: _queue[_activeIndex.clamp(0, _queue.length - 1)],
        activeIndex: _activeIndex.clamp(0, _queue.length - 1),
        totalChallenges: _queue.length,
        completedCount: completedCount,
        isComplete: true,
        result: result,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Private — state emission
  // ---------------------------------------------------------------------------

  void _emitState() {
    if (_isDisposed) return;
    _stateController.add(
      ChallengeDirectorState(
        activeChallenge: _queue[_activeIndex],
        activeIndex: _activeIndex,
        totalChallenges: _queue.length,
        completedCount: completedCount,
        isComplete: false,
        result: null,
      ),
    );
  }
}
