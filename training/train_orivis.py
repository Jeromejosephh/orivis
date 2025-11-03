#!/usr/bin/env python3
"""
Train a 5-class defect classifier for Orivis using TensorFlow Lite Model Maker.

Classes (folder names under DATA_DIR):
- OK
- Scratch
- Crack
- Dent_Deformation
- Stain_Discoloration

Input data layout expected:
~/orivis_data/
  OK/
  Scratch/
  Crack/
  Dent_Deformation/
  Stain_Discoloration/

Exports a quantized TFLite model directly into the Flutter project assets:
  /Users/jeromejoseph/orivis/assets/models/orivis_mnv3_q.tflite
  /Users/jeromejoseph/orivis/assets/models/labels.txt

Usage:
  python training/train_orivis.py --data_dir ~/orivis_data --epochs 20 --batch_size 32 \
    --export_dir /Users/jeromejoseph/orivis/assets/models

Notes:
- Uses EfficientNet-Lite0 as a strong mobile baseline.
- Includes on-the-fly data augmentation.
- Uses dynamic range quantization by default for broad device compatibility.
  You can switch to full int8 quantization with a small representative dataset
  by passing --int8_quant and ensuring there are enough samples.
"""

import argparse
import os
from pathlib import Path

# Silence TF logs a bit
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

from tflite_model_maker import model_spec
from tflite_model_maker import image_classifier
from tflite_model_maker.image_classifier import DataLoader
from tflite_model_maker.config import QuantizationConfig
import tensorflow as tf


CLASSES = [
    "OK",
    "Scratch",
    "Crack",
    "Dent_Deformation",
    "Stain_Discoloration",
]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", default=str(Path.home() / "orivis_data"),
                        help="Folder with class subfolders")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--val_split", type=float, default=0.15,
                        help="Fraction of data for validation (from train split)")
    parser.add_argument("--test_split", type=float, default=0.15,
                        help="Fraction of data for hold-out test")
    parser.add_argument("--export_dir", default="/Users/jeromejoseph/orivis/assets/models",
                        help="Where to write TFLite and labels.txt")
    parser.add_argument("--model", choices=[
        "efficientnet_lite0", "efficientnet_lite1", "mobilenet_v2"
    ], default="efficientnet_lite0")
    parser.add_argument("--int8_quant", action="store_true",
                        help="Export full integer INT8 quantized model (requires representative data)")
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def count_per_class(data_dir: Path):
    counts = {}
    for c in CLASSES:
        counts[c] = len(list((data_dir / c).glob("*.*")))
    return counts


def get_spec(name: str):
    if name == "efficientnet_lite0":
        return model_spec.get("efficientnet_lite0")
    if name == "efficientnet_lite1":
        return model_spec.get("efficientnet_lite1")
    if name == "mobilenet_v2":
        return model_spec.get("mobilenet_v2")
    raise ValueError(f"Unknown model spec: {name}")


def build_dataloaders(data_dir: Path, test_split: float, val_split: float, seed: int):
    # Model Maker will infer class names from subfolders (sorted)
    all_data = DataLoader.from_folder(str(data_dir))
    # First split train/test
    train_data, test_data = all_data.split(1.0 - test_split, shuffle=True, seed=seed)
    # Split train into train/val
    train_data, val_data = train_data.split(1.0 - val_split, shuffle=True, seed=seed)
    return train_data, val_data, test_data


def train_and_export(args):
    data_dir = Path(args.data_dir).expanduser().resolve()
    export_dir = Path(args.export_dir).expanduser().resolve()
    export_dir.mkdir(parents=True, exist_ok=True)

    print("Data dir:", data_dir)
    print("Export dir:", export_dir)

    # Print counts
    counts = count_per_class(data_dir)
    total = sum(counts.values())
    print("\nClass counts:")
    for k in CLASSES:
        print(f"- {k}: {counts.get(k, 0)}")
    print(f"Total images: {total}\n")

    # Data
    train_data, val_data, test_data = build_dataloaders(data_dir, args.test_split, args.val_split, args.seed)

    # Model
    spec = get_spec(args.model)
    # Enable simple augmentation on the fly
    spec.use_bfloat16 = False  # keep default

    model = image_classifier.create(
        train_data,
        model_spec=spec,
        epochs=args.epochs,
        batch_size=args.batch_size,
        validation_data=val_data,
        train_whole_model=True,
        shuffle=True,
        use_augmentation=True,
    )

    # Evaluate
    print("\nValidation metrics:")
    val_metrics = model.evaluate(val_data)
    print(val_metrics)

    print("\nTest metrics:")
    test_metrics = model.evaluate(test_data)
    print(test_metrics)

    # Quantization config
    if args.int8_quant:
        # Use a small representative dataset from training data for full int8 quantization
        # This improves speed and keeps accuracy close to FP32.
        def rep_ds_gen():
            for image, _ in train_data.gen_dataset().take(200):
                yield [tf.cast(image, tf.float32)]
        qconfig = QuantizationConfig.for_int8(representative_data=rep_ds_gen)
    else:
        # Dynamic range quantization (weights-only int8) – broadly compatible
        qconfig = QuantizationConfig.for_dynamic()

    # Export
    tflite_name = "orivis_mnv3_q.tflite"
    labels_name = "labels.txt"
    model.export(
        export_dir=str(export_dir),
        tflite_filename=tflite_name,
        label_filename=labels_name,
        quantization_config=qconfig,
    )

    print("\nExported:")
    print("-", export_dir / tflite_name)
    print("-", export_dir / labels_name)
    print("\nDone.")


if __name__ == "__main__":
    args = parse_args()
    train_and_export(args)
