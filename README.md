# 🤟 Sign Language Chatting App

> A real-time, cross-platform mobile chat application that enables seamless bidirectional communication between deaf/mute and hearing users through on-device Pakistan Sign Language (PSL) recognition — no cloud, no latency, no privacy compromise.

<br>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-On--Device%20AI-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-LSTM%20Training-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![YOLOv8](https://img.shields.io/badge/YOLOv8-Pose%20Detection-00FFFF?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-Academic%20FYP-blueviolet?style=for-the-badge)

<br>

---

## 📋 Table of Contents

1. [Problem Statement](#-problem-statement)
2. [Solution Overview](#-solution-overview)
3. [Key Features](#-key-features)
4. [Tech Stack](#-tech-stack)
5. [System Architecture](#-system-architecture)
6. [Machine Learning Pipeline](#-machine-learning-pipeline)
   - [Word Recognition — LSTM Pipeline](#word--sentence-recognition--lstm-pipeline)
   - [Letter Recognition — Distilled Random Forest](#letter--fingerspelling-recognition--distilled-random-forest)
7. [Mobile App — Screen by Screen](#-mobile-app--screen-by-screen)
8. [Firebase Data Model](#-firebase-data-model)
9. [Project Directory Structure](#-project-directory-structure)
10. [Prerequisites](#-prerequisites)
11. [Getting Started](#-getting-started)
12. [Firebase Setup](#-firebase-setup)
13. [Building the ML Models](#-building-the-ml-models)
14. [Bundling Model Assets](#-bundling-model-assets)
15. [Building and Installing the APK](#-building-and-installing-the-apk)
16. [Firestore Security Rules](#-firestore-security-rules)
17. [Android Build Configuration](#-android-build-configuration)
18. [Known Limitations](#-known-limitations)
19. [Roadmap](#-roadmap)
20. [Contributors](#-contributors)

---

## 🧩 Problem Statement

Pakistan has one of the largest populations of individuals with hearing and speech impairments in South Asia. These individuals rely entirely on **Pakistan Sign Language (PSL)** for daily communication. However:

- The vast majority of hearing people do not understand PSL, creating a severe communication barrier in everyday situations — medical appointments, education, banking, social interaction.
- Existing tools are limited to **static dictionaries** or **cloud-dependent translation services** that require a stable internet connection, introduce noticeable latency, and involve transmitting sensitive biometric video data (a person's face and hands) to remote servers.
- There is no widely available, **real-time**, **bidirectional**, **privacy-preserving** mobile chat platform that serves both communities simultaneously.

The computational barrier makes this hard to solve: running a full computer vision + sequence classification pipeline in real time on a constrained mobile CPU, without any cloud backend, requires careful engineering of the entire stack from data collection to model quantization to mobile integration.

---

## 💡 Solution Overview

The Sign Language Chatting App is a **dual-audience mobile chat platform** that bridges this gap with two core innovations:

### 1. On-Device Edge AI
Instead of routing video to a cloud server, the app runs a complete ML inference pipeline locally on the Android device using **TensorFlow Lite**. This means:
- Zero round-trip latency — inference results appear in under one second
- Full offline operation — no internet required for sign recognition
- Absolute data privacy — no video ever leaves the device

### 2. Bidirectional Communication Design
- A **deaf/mute user** opens the camera, performs a sign, and the app translates it to text which is sent as a chat message
- A **hearing user** types a text message normally; the app automatically detects any recognized PSL vocabulary words in that message and renders them as **inline sign-language video clips** so the deaf/mute recipient understands the meaning visually

Both users see the same familiar chat interface, adapted to their specific communication mode.

---

## ✨ Key Features

### Core Communication
- 💬 **Real-time Firebase chat** — messages appear instantly on both sides using Firestore live streams
- 🤟 **Live sign-to-text translation** — camera recognizes PSL signs and converts them to sendable text
- 📹 **Text-to-sign video rendering** — keywords in incoming messages automatically play their corresponding PSL video clip inline in the chat
- 🔤 **Dual recognition modes** — word/sentence mode (LSTM over 30-frame temporal sequences) and letter/fingerspelling mode (single-frame classifier for A–Y)

### User Experience
- 🦴 **Real-time skeleton overlay** — live cyan/magenta/green bone and joint visualization drawn on top of the camera feed showing detected pose landmarks
- 📚 **Built-in PSL Dictionary** — browse all 80 vocabulary signs with four different video views (Original Feed, Cropped Mask, Train Instance, Test Instance)
- 👤 **User mode system** — Normal Mode (standard text keyboard) and Deaf/Mute Mode (gesture capture panel replaces keyboard)
- 🟢 **Unread message indicator** — a neon green dot appears on contacts who have sent unread messages
- 👁️ **Read receipts** — messages are marked as read when the chat is opened

### Technical
- 🔒 **100% on-device inference** — TFLite models bundled in APK
- 📶 **Works offline** — sign recognition functions without internet
- 🔐 **Secure Firestore rules** — messages are only accessible to the two participants of each specific chat
- ⚡ **Quantized models** — INT8 quantization reduces model size and speeds up mobile inference

---

## 🛠 Tech Stack

### Mobile Application

| Layer | Technology | Purpose |
|---|---|---|
| UI Framework | Flutter (Dart) | Cross-platform mobile UI |
| State / Architecture | Clean Architecture + StatefulWidget | Separation of concerns |
| Authentication | Firebase Auth | Email/password login and registration |
| Database | Cloud Firestore | Real-time message sync and user directory |
| On-Device ML | `tflite_flutter ^0.12.1` | Run TFLite models on device |
| Pose Detection | `google_mlkit_pose_detection ^0.14.1` | 17-point skeletal landmark extraction |
| Camera | `camera ^0.12.0` | Live image stream from device camera |
| Video Playback | `video_player ^2.9.0` | PSL sign video rendering in chat and dictionary |
| Permissions | `permission_handler ^12.0.1` | Runtime camera permission requests |

### Machine Learning

| Component | Technology | Purpose |
|---|---|---|
| Pose Extraction | Ultralytics YOLOv8-Pose (`yolov8n-pose.pt`) | Extract 17 COCO keypoints per video frame |
| Sequence Classifier | PyTorch `SignLanguageLSTM` | Temporal classification over 30-frame windows |
| Letter Classifier | scikit-learn `RandomForestClassifier` | Static fingerspelling sign classification |
| Knowledge Distillation | TensorFlow / Keras | Reproduce RF outputs in a mobile-friendly dense network |
| Export Pipeline | ONNX → TFLite | Cross-platform model conversion |
| Video Processing | OpenCV | Frame extraction, normalization, temporal resampling |
| Feature Engineering | Hu Moments (log-transformed) | Shape-descriptor features for letter classification |

### Backend / Infrastructure

| Component | Technology |
|---|---|
| Authentication | Firebase Authentication |
| Real-time Database | Cloud Firestore |
| Build System | Gradle 8.14 (Kotlin DSL) |
| Android SDK | Compiled to SDK 35, minSdk 21 |

---

## 🏗 System Architecture

The app is structured following Clean Architecture principles, with three distinct layers that each serve a clear responsibility.

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
│                                                                   │
│  LoginScreen → ProfileSetupScreen → ContactsScreen → ChatScreen  │
│                                          ↓                        │
│                               SignCameraScreen ←── PSLDictionaryScreen │
│                                                                   │
│  Widgets: PSLVideoPlayer, SignVideoPlayer, _SkeletonPainter       │
└──────────────────────────────┬────────────────────────────────────┘
                               │
┌──────────────────────────────▼────────────────────────────────────┐
│                          DOMAIN LAYER                              │
│                                                                    │
│  • User mode switching (Normal ↔ Deaf/Mute)                       │
│  • Chat room ID derivation (sorted UID pair → deterministic ID)   │
│  • Read-receipt tracking (lastReadBy array logic)                  │
│  • On-device inference pipeline (frame → landmarks → prediction)  │
│  • Keyword extraction (sign_map.json lookup for video autoplay)   │
└──────────────────────────────┬────────────────────────────────────┘
                               │
┌──────────────────────────────▼────────────────────────────────────┐
│                           DATA LAYER                               │
│                                                                    │
│  CameraController  │  TFLite Interpreter  │  PoseDetector         │
│  (image stream)    │  (model inference)   │  (ML Kit)             │
│                    │                      │                        │
│  Firestore (users + chats collections)  │  Asset bundles          │
│  Firebase Auth (session management)     │  sign_map.json          │
└────────────────────────────────────────────────────────────────────┘
```

### Chat Room ID Design

Every chat between two users is stored as a single Firestore document. The document ID is derived deterministically by sorting both user UIDs alphabetically and joining them with an underscore:

```
["uid_alice_xyz", "uid_bob_abc"]  →  sorted  →  "uid_alice_xyz_uid_bob_abc"
```

This guarantees that two users always reference the same document regardless of who initiates the conversation, and enables Firestore security rules to verify participation directly from the document ID without any extra database lookups.

---

## 🤖 Machine Learning Pipeline

### Word / Sentence Recognition — LSTM Pipeline

This pipeline translates continuous, dynamic PSL signs (words and short phrases) into text. It operates on temporal sequences of skeletal pose data.

#### Step 1 — Dataset structure

PSL video clips are organized as:

```
assets/signs/
├── original/      ← raw camera recordings
├── cropped/       ← signer isolated with background removed
├── test/          ← held-out validation clips
└── train/1_O/     ← primary training clips
```

80 vocabulary words are covered, including common words and a selection of PSL-specific terms such as `lakh`, `so-accentuator`, and `so-in-order-to`.

#### Step 2 — Pose feature extraction (`extract_yolo_pose.py`)

For every video clip in the dataset:
1. OpenCV reads each frame sequentially
2. YOLOv8-Pose runs inference on each frame to produce 17 COCO-standard keypoints for the primary detected person
3. Each keypoint has three values: `x` (normalized 0–1 by frame width), `y` (normalized 0–1 by frame height), and `confidence`
4. The 17 keypoints are flattened into a single 51-float feature vector per frame
5. Frames with no detected person receive a zero-padded vector
6. Variable-length clips are **temporally resampled** to exactly 30 frames using linear interpolation — longer clips are subsampled evenly, shorter clips are padded by repeating the final frame
7. Each clip becomes a `30 × 51` NumPy array, saved as a `.npy` file grouped by vocabulary class

This produces `X_sequences.npy` (shape: `[n_clips, 30, 51]`) and `Y_labels.npy` for training.

#### Step 3 — LSTM training (`train_lstm.py`)

```
Input: [batch, 30, 51]
       ↓
Linear Projection
       ↓
Stacked LSTM (2 layers, hidden_size=128, dropout=0.2)
       ↓
Final hidden state → Dense → Softmax over 80 classes
```

Training configuration:
- Optimizer: Adam (`lr = 0.001`)
- Loss: CrossEntropyLoss
- Batch size: 4 (tuned for limited-memory devices during training)
- Epochs: 40
- Device: CUDA if available, else CPU

The checkpoint is saved as `sign_language_lstm.pt`, containing the model weights, class list, and architecture config dictionary for clean reconstruction at export time.

#### Step 4 — Export to TFLite (`export_to_tflite.py`)

```
sign_language_lstm.pt
     ↓ torch.onnx.export (opset 14, dynamic batch axis)
sign_language.onnx
     ↓ onnx2tf
sign_language_float32.tflite
```

The final TFLite model expects input shape `[1, 30, 51]` float32 and outputs `[1, 80]` float32 softmax scores.

#### Step 5 — On-device inference (SignCameraScreen)

At runtime on the Android device:
1. `CameraController` streams raw NV21 frames to a callback
2. Each frame is converted to an `InputImage` and processed by `google_mlkit_pose_detection`
3. 17 landmarks are extracted, normalized by image dimensions, and assembled into a 51-float vector
4. The vector is appended to a sliding `_sequenceBuffer` (max 30 frames)
5. Once the buffer is full, it is passed to the `TFLite Interpreter` which runs the LSTM in under ~20ms
6. The class with the highest softmax score (above a confidence threshold of 0.45) is displayed as the live prediction

A thin linear progress bar at the bottom of the camera viewport shows how full the sequence buffer is, so the user knows when recognition will trigger.

---

### Letter / Fingerspelling Recognition — Distilled Random Forest

This pipeline recognizes static PSL fingerspelling signs for individual letters (A–Y, excluding J, Z, and X which require motion).

#### Step 1 — Dataset

1,575 labeled hand images covering 23 letter classes, preprocessed as:
- Resize to 224 × 224
- Convert to grayscale
- Gaussian blur (5×5, σ=0)
- Adaptive threshold (Gaussian method, block size 11, C=2)

#### Step 2 — Feature engineering (Hu Moments)

From each binarized hand contour, 7 **Hu Moments** are extracted. These are mathematical shape descriptors that are invariant to rotation, scale, and translation — exactly the right properties for a hand classifier that needs to work regardless of how far or at what angle the hand is held.

Each moment is log-transformed to compress the dynamic range:
```
hu_i = -sign(H_i) × log10(|H_i|)
```

Features are standardized to zero mean and unit variance (z-score normalization).

#### Step 3 — Model selection and training

Three models were evaluated:

| Model | Accuracy |
|---|---|
| SVM (linear kernel, C=1) | ~57% |
| SVM (RBF kernel, C=10, γ=scale) | ~75% |
| Random Forest (100 trees, max_features=sqrt) | **~80%** |

5-fold cross-validation on the Random Forest confirmed mean accuracy ~73% with std ~0.07, showing consistent generalization.

#### Step 4 — Knowledge distillation to TFLite

Since tree-based ensembles cannot be traced to a TensorFlow computation graph, a **knowledge distillation** step is used:

1. The trained Random Forest generates soft probability outputs (`predict_proba`) for all 1,575 training samples
2. A small dense neural network is trained to reproduce these soft labels:
   ```
   Input (7) → Dense(64, ReLU) → BatchNorm → Dense(64, ReLU) → BatchNorm → Dense(32, ReLU) → Dense(23, Softmax)
   ```
3. The distilled network achieves ~72% accuracy on the full dataset, closely matching the teacher RF
4. The network weights are extracted and baked into a manually traced `tf.function` — this bypasses all Keras 3 / TensorFlow 2.19 export compatibility issues
5. The concrete function is converted via `TFLiteConverter` with INT8 representative dataset quantization

The final `letter_classifier.tflite` is just **14.9 KB**.

Three companion files travel with the model:
- `letter_labels.txt` — 23 class names (A–Y minus J/X/Z)
- `scaler_params.json` — mean and std vectors for live-inference normalization
- `letter_classifier.onnx` — intermediate ONNX graph (retained for reference)

---

## 📱 Mobile App — Screen by Screen

### LoginScreen (`login_screen.dart`)

The entry point. Provides email/password sign-in and registration via Firebase Auth. On successful sign-in, routes to `ContactsScreen`. On successful registration (new account), routes to `ProfileSetupScreen` to complete onboarding.

### ProfileSetupScreen (`profile_setup_screen.dart`)

Allows the user to set their display name, gender, and most importantly their **application mode**:

- **Normal Mode** — standard text keyboard in chat
- **Deaf / Mute Mode** — gesture-capture panel replaces the keyboard; the user can tap a grid icon to open letter-recognition mode or a camera icon to open word-recognition mode

Mode choice is stored in Firestore (`users/{uid}.state`) and read by `ChatScreen` on every chat open to dynamically switch the input panel.

The screen also pre-populates with existing Firestore data if the user has already set up their profile, using a `FutureBuilder` on the user document.

### ContactsScreen (`contacts_screen.dart`)

A WhatsApp-style contact list. Streams all `users` documents from Firestore and displays them as cards with the user's initial, their mode (Standard / Deaf/Mute), and an unread message indicator.

The unread dot logic: for each contact, a secondary `StreamBuilder` listens to the specific chat room document. If `lastMessageSenderId != currentUserId` and `lastReadBy` does not contain `currentUserId`, a glowing neon green dot appears on the contact's avatar. The dot disappears as soon as the user opens that chat.

Tapping a contact navigates to `ChatScreen` and simultaneously writes `currentUserId` into the room's `lastReadBy` array (marking all messages as read).

### ChatScreen (`chat_screen.dart`)

The main chat interface. Has two distinct bottom panels based on the current user's mode:

**Normal Mode** — a standard text field with a send button.

**Deaf/Mute Mode** — two circular action buttons:
- **Grid button** (Alphabets) → opens `SignCameraScreen` in letter mode
- **Camera button** (Sentences) → opens `SignCameraScreen` in word mode

Both buttons wait for `SignCameraScreen` to return a `String` result, then call `_handleSend()` with it.

Every sent message also updates the parent chat room document's tracking metadata (`lastMessageSenderId`, `lastReadBy` reset to sender only, `lastMessageTime`) to power the unread indicator system.

**Automatic sign video autoplay**: after each message is rendered, `_extractKeywords()` scans the message text against `sign_map.json`. Any matching keywords trigger a `SignVideoPlayer` widget to be rendered below the message bubble, showing the PSL sign for that word. This lets deaf/mute recipients understand incoming text messages visually without knowing how to read.

### SignCameraScreen (`sign_camera_screen.dart`)

The core ML integration screen. Works in two modes based on the `checkMode` parameter passed from `ChatScreen`.

**Initialization sequence**:
1. Request camera runtime permission
2. Initialize ML Kit `PoseDetector` (stream mode, base model)
3. Load the appropriate TFLite model and label file from bundled assets
4. Open the camera in NV21 format (required for ML Kit on Android) and start the image stream

**Per-frame pipeline** (runs asynchronously, skips frames if busy):
1. Convert `CameraImage` → `InputImage` using the correct `InputImageFormat.nv21` and sensor rotation
2. Run ML Kit pose detection → extract 17 COCO landmarks
3. Normalize coordinates by image dimensions
4. Update `_currentPose` state → triggers `_SkeletonPainter` to redraw
5. Build 51-float feature vector and run model inference

**`_SkeletonPainter`** (`CustomPainter`): draws 16 bone connections between adjacent landmark pairs and 17 joint dots on top of the camera preview. High-confidence joints (>70%) are drawn in neon green; others in magenta. Bones are drawn in electric cyan. The painter accounts for sensor rotation and front camera mirroring when mapping ML Kit coordinates to canvas pixels.

A diagnostic strip at the top of the camera frame shows live frame count, pose detection count, detected image dimensions, and sensor angle — useful for debugging coordinate space issues on different devices.

### PSLDictionaryScreen (`video_dictionary_screen.dart`)

Accessible from the top-right icon in `ChatScreen`. Shows a two-panel layout:
- Left panel: scrollable list of all 80 vocabulary words
- Right panel: video player for the selected word

A dropdown in the AppBar switches between four video views:
- Original Feed (`signs/original/`)
- Cropped Mask (`signs/cropped/`)
- Train Instance (`signs/train/1_O/`) ← default
- Test Instance (`signs/test/`)

Video playback is handled by `PSLVideoPlayer`, which supports looping and manual play/pause via a button.

---

## 🔥 Firebase Data Model

### `users` collection

```
users/
└── {uid}/
    ├── uid:        string   // Firebase Auth UID
    ├── name:       string   // Display name
    ├── email:      string   // Registration email
    ├── gender:     string   // "Male" | "Female"
    ├── state:      string   // "Normal" | "Disabled"
    └── createdAt:  timestamp
```

### `chats` collection

```
chats/
└── {sortedUid1}_{sortedUid2}/
    ├── participants:          string[]   // [uid1, uid2]
    ├── lastMessageSenderId:   string
    ├── lastMessageTime:       timestamp
    ├── lastReadBy:            string[]   // UIDs who have seen the latest message
    │
    └── messages/ (subcollection)
        └── {messageId}/
            ├── senderId:    string
            ├── receiverId:  string
            ├── text:        string
            └── timestamp:   timestamp
```

**Chat room ID derivation**:
```dart
List<String> ids = [currentUserId, receiverUid];
ids.sort();
String chatRoomId = ids.join('_');
```

---

## 📁 Project Directory Structure

```
Sign-Language-Chat-App/
│
├── mobile_app/                              # Flutter project root
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle.kts            # App-level Gradle (Kotlin DSL)
│   │   │   └── src/main/
│   │   │       └── AndroidManifest.xml     # Permissions + activity config
│   │   ├── build.gradle.kts               # Root Gradle with JVM toolchain fix
│   │   ├── gradle.properties              # JVM args, incremental compile off
│   │   └── settings.gradle.kts            # Flutter plugin loader + KGP version
│   │
│   ├── assets/
│   │   ├── sign_map.json                  # 80 keyword → video path mappings
│   │   ├── model/
│   │   │   ├── sign_language.tflite       # Word recognition model (LSTM)
│   │   │   ├── labels.txt                 # 80 word class names
│   │   │   ├── letter_classifier.tflite   # Letter recognition model (distilled RF)
│   │   │   ├── letter_labels.txt          # 23 letter class names (A–Y)
│   │   │   ├── scaler_params.json         # Hu moment normalization params
│   │   │   └── letter_classifier.onnx     # Intermediate ONNX (reference)
│   │   └── signs/
│   │       ├── original/                  # Raw PSL video clips
│   │       ├── cropped/                   # Background-removed clips
│   │       ├── test/                      # Validation clips
│   │       └── train/1_O/                 # Primary training clips
│   │
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── profile_setup_screen.dart
│   │   │   ├── contacts_screen.dart
│   │   │   ├── chat_screen.dart           # Includes SignVideoPlayer widget
│   │   │   ├── sign_camera_screen.dart    # ML inference + skeleton overlay
│   │   │   └── video_dictionary_screen.dart
│   │   ├── widgets/
│   │   │   └── psl_video_player.dart
│   │   ├── firebase_options.dart           # Auto-generated by FlutterFire CLI
│   │   └── main.dart                      # App entry + global theme
│   │
│   └── pubspec.yaml
│
└── ml_models/                             # Python ML workspace (offline)
    ├── data_preprocessing/
    │   └── extract_yolo_pose.py           # YOLOv8-Pose feature extraction
    ├── processed_features/
    │   ├── X_sequences.npy               # [n, 30, 51] training data
    │   ├── Y_labels.npy                  # Class index labels
    │   ├── sign_language.onnx            # Exported ONNX graph
    │   ├── sign_language_float32.tflite  # Final word-recognition model
    │   └── {word}/                       # Per-word .npy feature folders
    ├── saved_models/
    │   └── sign_language_float32.tflite  # Mirror of processed_features output
    ├── train_lstm.py                      # LSTM training script
    ├── export_to_tflite.py               # PyTorch → ONNX → TFLite export
    ├── extract_labels.py                 # Pull class list from .pt checkpoint
    ├── convert_letter_model.py           # RF distillation + TFLite export
    ├── sign_language_lstm.pt             # Trained PyTorch checkpoint
    ├── sign_language.onnx
    └── yolov8n-pose.pt                   # Base YOLOv8n-pose weights
```

---

## ✅ Prerequisites

### For running the mobile app

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x
- Android SDK (API 21+) via Android Studio
- A **physical Android device** (camera-based ML Kit pose detection requires real hardware; most emulators do not provide a full camera stream)
- A Firebase project with Authentication and Firestore enabled

### For retraining ML models

- Python 3.12
- NVIDIA GPU with CUDA support (optional but strongly recommended for LSTM training)
- The PSL video dataset placed in `mobile_app/assets/signs/`
- The PSL fingerspelling image dataset

### Python packages (install in venv)

```bash
pip install torch torchvision ultralytics opencv-python numpy
pip install tensorflow scikit-learn skl2onnx onnx onnxruntime onnx2tf
pip install seaborn matplotlib
```

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/Sign-Language-Chat-App.git
cd Sign-Language-Chat-App/mobile_app
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Verify your environment

```bash
flutter doctor
```

Ensure Android toolchain shows no errors. Java version on your system should be Java 11–25 (the Gradle build dynamically aligns JVM targets across all plugins).

---

## 🔥 Firebase Setup

### Step 1 — Create Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com) and create a new project
2. Give it a name (e.g., `sign-language-chat-app`)
3. Disable Google Analytics (not required for this project)

### Step 2 — Enable Authentication

1. In the Firebase Console, click **Build → Authentication**
2. Click **Get started**
3. Under **Sign-in providers**, enable **Email/Password**

### Step 3 — Enable Firestore

1. Click **Build → Firestore Database**
2. Click **Create database**
3. Select **Start in production mode** (you will add proper rules in a later step)
4. Choose a region close to your users (e.g., `asia-south1` for Pakistan)

### Step 4 — Connect Firebase to Flutter

Run the FlutterFire CLI inside `mobile_app/`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select your Firebase project when prompted. This regenerates `lib/firebase_options.dart` with your project credentials.

Alternatively, download `google-services.json` from Project Settings → Your apps → Android and place it at `android/app/google-services.json`.

### Step 5 — Set Security Rules

See the [Firestore Security Rules](#-firestore-security-rules) section below.

---

## 🧠 Building the ML Models

### Word Recognition (LSTM)

```bash
cd ml_models
python -m venv venv
venv\Scripts\activate          # Windows
# or
source venv/bin/activate       # macOS/Linux

pip install torch ultralytics opencv-python numpy

# Step 1: Extract YOLOv8-Pose features from video dataset
python data_preprocessing/extract_yolo_pose.py

# Step 2: Train the LSTM classifier
python train_lstm.py

# Step 3: Export to ONNX
python export_to_tflite.py

# Step 4: Convert ONNX → TFLite (run in system Python with onnx2tf installed)
onnx2tf -i sign_language.onnx -o processed_features/

# Step 5: Extract class labels
python extract_labels.py
```

### Letter Recognition (Distilled Random Forest)

Run the Jupyter notebook cells in order:

- **Cells 1–8** — image preprocessing, Hu moment extraction, dataset serialization
- **Cells 9–13** — SVM, Random Forest training, cross-validation
- **Cell 17** — knowledge distillation + TFLite export (merged cell)

Cell 17 automatically saves `letter_classifier.tflite`, `letter_labels.txt`, and `scaler_params.json` directly into `mobile_app/assets/model/`.

---

## 📦 Bundling Model Assets

After training, ensure these five files are present in `mobile_app/assets/model/`:

```
assets/model/
├── sign_language.tflite       # copy from ml_models/processed_features/sign_language_float32.tflite
├── labels.txt                 # generated by extract_labels.py
├── letter_classifier.tflite   # generated by notebook Cell 17
├── letter_labels.txt          # generated by notebook Cell 17
└── scaler_params.json         # generated by notebook Cell 17
```

Ensure `pubspec.yaml` includes the model folder:

```yaml
flutter:
  assets:
    - assets/sign_map.json
    - assets/model/
    - assets/signs/original/
    - assets/signs/cropped/
    - assets/signs/test/
    - assets/signs/train/1_O/
```

---

## 🏗 Building and Installing the APK

```bash
cd mobile_app

# Clean previous build artifacts
flutter clean

# Fetch dependencies
flutter pub get

# Build release APK
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Install directly to a connected device:

```bash
flutter install
```

Or transfer the APK manually via USB and install it through your device's file manager.

> **Important**: Always test on a physical device. ML Kit pose detection and the TFLite camera pipeline behave differently on emulators due to limited camera format support.

---

## 🔐 Firestore Security Rules

Apply these rules in **Firebase Console → Firestore Database → Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Chat room IDs are built as "uidA_uidB" (sorted alphabetically).
    // We verify participation directly from the document ID.
    function isChatParticipant(chatId) {
      return isSignedIn() &&
        (chatId.split('_')[0] == request.auth.uid ||
         chatId.split('_')[1] == request.auth.uid);
    }

    // Any signed-in user can read the contacts directory.
    // Users can only write to their own profile document.
    match /users/{userId} {
      allow read:          if isSignedIn();
      allow create, update: if isOwner(userId);
      allow delete:        if false;
    }

    // Only the two participants of a chat can read or write the room.
    // Messages can be created but not edited or deleted.
    // The senderId field must match the authenticated user.
    match /chats/{chatId} {
      allow read, write: if isChatParticipant(chatId);

      match /messages/{messageId} {
        allow read:   if isChatParticipant(chatId);
        allow create: if isChatParticipant(chatId) &&
                          request.resource.data.senderId == request.auth.uid;
        allow update, delete: if false;
      }
    }
  }
}
```

Click **Publish** after pasting. Changes propagate within ~30 seconds and do not require an app rebuild.

---

## ⚙️ Android Build Configuration

The app uses Kotlin DSL (`build.gradle.kts`) throughout. A significant engineering effort was required to resolve JVM target compatibility conflicts between different Flutter plugins (`tflite_flutter`, `camera_android_camerax`, `video_player_android`) when building with Java 25.

### Key configuration decisions

**`android/build.gradle.kts`** — The root build file contains a per-project Kotlin compile task override that aligns each plugin's `compileReleaseKotlin` JVM target to match its own `compileReleaseJavaWithJavac` target. This is applied lazily with `tasks.configureEach` to avoid `afterEvaluate` lifecycle violations.

**`android/app/build.gradle.kts`** — The app module uses Java 11 compile options with matching `kotlinOptions.jvmTarget = "11"`, matching the lowest common denominator across all bundled plugins.

**`android/gradle.properties`** — Kotlin incremental compilation is disabled (`kotlin.incremental=false`) to prevent `.tab` cache corruption that occurs on builds interrupted by JVM target mismatches.

**`pubspec.yaml`** — `camera_android_camerax` is pinned to `0.7.2+1` via `dependency_overrides` to resolve a `jvmTarget` finalization bug present in `0.7.2`.

---

## ⚠️ Known Limitations

### Machine Learning

- The word recognition LSTM was trained on ~80 signs with limited samples per class. Real-world accuracy on live camera input, especially with varied skin tones, backgrounds, and lighting, may be lower than validation accuracy.
- The letter recognition model (distilled Random Forest) achieves ~72–80% accuracy on the training distribution. Generalization to very different hand shapes or image conditions is not guaranteed.
- Neither model has been evaluated on a held-out user population test — all accuracy figures are from the same dataset distribution as training.
- The fingerspelling model uses positional features derived from upper-body pose landmarks rather than true hand keypoints. A dedicated hand landmark model (e.g., MediaPipe Hands) would significantly improve letter discrimination.

### Mobile Inference

- The skeleton overlay coordinate mapping is sensitive to device sensor orientation. Devices where the camera sensor is oriented at 0° or 180° instead of the standard 90° may show misaligned overlays.
- Frame processing drops frames if the previous frame is still being processed by ML Kit (single-frame concurrency gate). On slow devices, this reduces the effective frame rate fed to the LSTM.
- NV21 format is used for ML Kit compatibility. Some device/driver combinations may not fully support NV21 streaming through the `camera` plugin.

### App

- The contacts list shows all registered users — there is no search, filtering, or friend-request system.
- Automatic keyword video rendering in chat can display multiple videos per message if several keywords match, which may create a cluttered visual experience for long messages.
- The PSL video assets add ~260 MB to the APK size. A production version should use on-demand video streaming rather than bundled assets.

---

## 🗺 Roadmap

| Priority | Feature |
|---|---|
| High | Replace Hu Moment features with MediaPipe Hand Landmarker for proper fingerspelling classification |
| High | Expand word vocabulary to 200+ PSL signs with a larger, more diverse video dataset |
| High | Implement on-device model hot-swap so vocabulary can be extended without an APK rebuild |
| Medium | Add sentence-level context correction (e.g., LLM post-processing to fix grammar in translated output) |
| Medium | Support two-handed and facial-expression-aware sign recognition |
| Medium | Move video assets to Firebase Storage with lazy on-demand download to reduce APK size |
| Medium | Add iOS support (currently Android-only due to `google_mlkit_pose_detection` and `tflite_flutter` configurations) |
| Low | Add group chat support |
| Low | Add push notifications (FCM) for offline message delivery |
| Low | Add a sign learning/practice mode that lets hearing users learn PSL vocabulary |

---

## 👥 Contributors

| Name | Role |
|---|---|
| **Sufyan Afzal** | Lead developer — Flutter app, ML pipeline, system integration |
| **Sabeen Saeed** | Project partner — dataset collection, testing, documentation |
| **Mr. Qasim Malik** | Project supervisor — COMSATS University Islamabad |

This project is developed as a **Final Project for Subject Mobile App Development** for a Bachelor of Science in Artificial Intelligence at **COMSATS University Islamabad**, expected graduation 2027.

---

## 📎 Related Links

- [LinkedIn — Sufyan Afzal](https://linkedin.com/in/sufyanafzal7/)
- [Flutter Documentation](https://docs.flutter.dev)
- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [Google ML Kit Pose Detection](https://developers.google.com/ml-kit/vision/pose-detection)
- [Ultralytics YOLOv8](https://docs.ultralytics.com)
- [Firebase Console](https://console.firebase.google.com)

---

<p align="center">Built with ❤️ for accessibility — breaking communication barriers one sign at a time</p>
