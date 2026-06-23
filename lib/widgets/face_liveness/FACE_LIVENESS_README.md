# Face Liveness Widget Files

This folder contains the core face liveness challenge components used by the app.

## Files

- `face_liveness_widget.dart`
  - Root widget for the face liveness flow.
  - Owns camera initialization, `ChallengeValidator`, and `ChallengeDirector`.
  - Renders the camera preview, overlay UI, timer bar, progress dots, and hints.
  - Sample usage:
    ```dart
    FaceLivenessWidget(
      config: faceLivenessConfig,
      onPass: _handlePass,
      onTimeout: _handleTimeout,
    )
    ```

- `face_liveness_config.dart`
  - Defines behavior settings for the liveness session.
  - Holds the list of challenges, randomization flag, and per-challenge duration.
  - Supports JSON serialization/deserialization.
  - Sample usage:
    ```dart
    final config = FaceLivenessConfig(
      challengeSequence: [
        LivenessChallenge.blink,
        LivenessChallenge.smile,
        LivenessChallenge.turnLeft,
      ],
      isRandom: true,
      secondsPerChallenge: 18,
    );
    ```

- `liveness_challenge.dart`
  - Enum defining supported liveness actions.
  - Used by config, validation, and display layers.
  - Sample usage:
    ```dart
    final challenge = LivenessChallenge.fromString('smile');
    if (challenge == LivenessChallenge.smile) {
      // show smile overlay
    }
    ```

- `liveness_thresholds.dart`
  - Stores detection thresholds for blink, smile, head turn, tilt, and face quality.
  - `ChallengeValidator` reads these values when evaluating frames.
  - Sample usage:
    ```dart
    if (face.smilingProbability >= LivenessThresholds.smileThreshold) {
      return ChallengeResult.pass;
    }
    ```

- `challenge_director.dart`
  - Orchestrates the active challenge queue and session timer.
  - Accepts `FaceLivenessConfig`, builds the challenge order, and advances challenges on pass.
  - Emits state and timer progress streams for UI widgets.
  - Sample usage:
    ```dart
    final director = ChallengeDirector(config: config);
    director.stateStream.listen((state) {
      setState(() => _directorState = state);
    });
    director.timerProgressStream.listen((progress) {
      setState(() => _timerProgress = progress);
    });
    director.start();
    ```

- `challenge_validator.dart`
  - Evaluates camera frames against the currently active challenge.
  - Uses ML Kit face detection and threshold constants.
  - Returns `ChallengeResult.pass`, `notYet`, `noFace`, or `error`.
  - Sample usage:
    ```dart
    await validator.initialize();
    final result = await validator.evaluate(
      image: inputImage,
      challenge: LivenessChallenge.blink,
    );
    if (result == ChallengeResult.pass) {
      director.onChallengePass();
    }
    ```

- `challenge_overlay.dart`
  - Displays the current challenge text and icon in an animated panel.
  - Used by `FaceLivenessWidget` to show instructions clearly.
  - Sample usage:
    ```dart
    ChallengeOverlay(
      challenge: LivenessChallenge.smile,
      style: detectionStyle,
    )
    ```

- `challenge_progress_dots.dart`
  - Renders completion progress as dots representing each challenge.
  - Shows completed, active, and upcoming states.
  - Sample usage:
    ```dart
    ChallengeProgressDots(
      totalChallenges: state.totalChallenges,
      completedCount: state.completedCount,
      activeIndex: state.activeIndex,
      style: detectionStyle,
    )
    ```

- `no_face_hint.dart`
  - Displays a hint banner when no face is detected for a sustained time.
  - Helps users reposition without pausing the session.
  - Sample usage:
    ```dart
    NoFaceHint(
      visible: _noFaceHintVisible,
      style: detectionStyle,
    )
    ```

- `session_timer_bar.dart`
  - Shows the remaining session time as an animated progress bar.
  - Changes color when the remaining time drops below a warning threshold.
  - Sample usage:
    ```dart
    SessionTimerBar(
      progress: timerProgress,
      style: detectionStyle,
    )
    ```

## Purpose

These files work together to implement a face liveness flow where the user must complete one or more face actions (blink, smile, turn, look) within a timed session.
