# LOCATION: ml_models/data_preprocessing/extract_yolo_pose.py
import os
import cv2
import numpy as np
import torch
from ultralytics import YOLO

# 1. True Asset Directories Mapping Layout
DATASET_BASE = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\mobile_app\assets\signs"
SUB_FOLDERS = ["original", "cropped", "test"]

# Destination workspace where extracted sequence tracking blocks will save
OUTPUT_BASE_DIR = r"D:\Program Files\Android Studio\Sign-Language-Chat-App\ml_models\processed_features"

# Fixed Sequence Sequence Window Frame Length (Standard normalized temporal depth)
SEQUENCE_LENGTH = 30 

def load_pose_model():
    print("⏳ Loading YOLOv8-Pose architecture weights...")
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    model = YOLO('yolov8n-pose.pt').to(device)
    print(f"✓ Active execution hardware engine target locked on: {device.upper()}")
    return model

def process_video_to_landmarks(video_path, model):
    cap = cv2.VideoCapture(video_path)
    sequence_keypoints = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
            
        # Run spatial tracking pose inference silently
        results = model(frame, verbose=False)
        
        if len(results) > 0 and results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
            # Extract tracking matrix for primary signer in frame
            # Shape output is [17 keypoints, 3 dimensions] -> (x, y, confidence score)
            kpts = results[0].keypoints.data[0].cpu().numpy()
            
            # Flatten [17, 3] matrix blocks into a single 1D vector row line of 51 parameters
            flattened_frame = kpts.flatten()
            sequence_keypoints.append(flattened_frame)
        else:
            # Apply a neutral 0-matrix placeholder line if a tracking frame is dropped/blocked
            sequence_keypoints.append(np.zeros(17 * 3))
            
    cap.release()
    
    total_frames = len(sequence_keypoints)
    if total_frames == 0:
        return None
        
    # Temporal Resampling Matrix Alignment: Normalizing clip outputs to a fixed 30-frame grid
    if total_frames >= SEQUENCE_LENGTH:
        # Down-sample longer frame tracks evenly
        indices = np.linspace(0, total_frames - 1, SEQUENCE_LENGTH, dtype=int)
        final_sequence = [sequence_keypoints[i] for i in indices]
    else:
        # Pad up brief sequences using the final historical frame snapshot
        final_sequence = list(sequence_keypoints)
        while len(final_sequence) < SEQUENCE_LENGTH:
            final_sequence.append(sequence_keypoints[-1])
            
    return np.array(final_sequence) # Outputs a clean [30, 51] matrix sequence block

def run_feature_extraction_pipeline():
    model = load_pose_model()
    
    for sub_folder in SUB_FOLDERS:
        target_folder_path = os.path.join(DATASET_BASE, sub_folder)
        if not os.path.exists(target_folder_path):
            print(f"⚠️ Directory pathway skipped (Not Found): {target_folder_path}")
            continue
            
        print(f"\n⚡ Extrapolating motion tracking vectors from section node: {sub_folder.upper()}")
        
        # Look for target video clip items matching files
        video_files = [f for f in os.listdir(target_folder_path) if f.lower().endswith('.mp4')]
        
        for video_name in video_files:
            video_full_path = os.path.join(target_folder_path, video_name)
            word_class_label = video_name.replace('.mp4', '')
            
            # Group matrices by their specific vocabulary word inside output target workspace
            label_save_directory = os.path.join(OUTPUT_BASE_DIR, word_class_label)
            os.makedirs(label_save_directory, exist_ok=True)
            
            feature_matrix = process_video_to_landmarks(video_full_path, model)
            
            if feature_matrix is not None:
                output_file_name = f"{sub_folder}_{word_class_label}.npy"
                np.save(os.path.join(label_save_directory, output_file_name), feature_matrix)
                print(f"  ✓ Saved Matrix Array Sequence: {output_file_name} | Shape: {feature_matrix.shape}")
            else:
                print(f"  ❌ Failed to extract parameters from video node track: {video_name}")

if __name__ == "__main__":
    run_feature_extraction_pipeline()
    print("\n🎉 Feature extraction workspace configuration successfully completed!")