#!/usr/bin/env python3
"""
Keras-based training for Orivis 5-class defect classifier.
- Uses EfficientNetB0 with augmentation
- Reads data from a directory with 5 subfolders: OK, Scratch, Crack, Dent_Deformation, Stain_Discoloration
- Splits into train/val/test
- Exports INT8 quantized TFLite model + labels.txt into Flutter assets

Usage:
  python training/train_orivis_keras.py --data_dir ~/orivis_data --epochs 30 --batch_size 32 \
    --export_dir /Users/jeromejoseph/orivis/assets/models
"""
import argparse
import os
from pathlib import Path
import random

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models

CLASSES = [
    "OK",
    "Scratch",
    "Crack",
    "Dent_Deformation",
    "Stain_Discoloration",
]

IMG_SIZE = (224, 224)
SEED = 42

def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data_dir", default=str(Path.home()/"orivis_data"))
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--batch_size", type=int, default=32)
    ap.add_argument("--val_split", type=float, default=0.15)
    ap.add_argument("--test_split", type=float, default=0.15)
    ap.add_argument("--export_dir", default="/Users/jeromejoseph/orivis/assets/models")
    return ap.parse_args()


def list_files_by_class(data_dir: Path):
    files = []
    for cls in CLASSES:
        cls_dir = data_dir/cls
        for p in sorted(cls_dir.glob("*")):
            if p.suffix.lower() in [".jpg", ".jpeg", ".png"]:
                files.append((str(p), cls))
    return files


def split_dataset(files, val_split, test_split):
    random.Random(SEED).shuffle(files)
    n = len(files)
    n_test = int(n * test_split)
    n_val = int((n - n_test) * val_split)
    test = files[:n_test]
    val = files[n_test:n_test+n_val]
    train = files[n_test+n_val:]
    return train, val, test


def make_tf_dataset(items, class_indices, batch_size, shuffle, augment):
    paths = [p for p,_ in items]
    labels = [class_indices[c] for _,c in items]
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if shuffle:
        ds = ds.shuffle(buffer_size=len(paths), seed=SEED, reshuffle_each_iteration=True)

    def _load(path, label):
        img = tf.io.read_file(path)
        img = tf.image.decode_image(img, channels=3, expand_animations=False)
        img = tf.image.convert_image_dtype(img, tf.float32)
        img = tf.image.resize(img, IMG_SIZE)
        return img, tf.one_hot(label, depth=len(CLASSES))

    ds = ds.map(_load, num_parallel_calls=tf.data.AUTOTUNE)

    aug_layers = tf.keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.08),
        layers.RandomZoom(0.1),
        layers.RandomBrightness(0.1),
        layers.RandomContrast(0.1),
    ]) if augment else None

    if augment:
        def _aug(img, label):
            return aug_layers(img, training=True), label
        ds = ds.map(_aug, num_parallel_calls=tf.data.AUTOTUNE)

    return ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)


def build_model(num_classes):
    base = tf.keras.applications.EfficientNetB0(
        include_top=False,
        input_shape=IMG_SIZE + (3,),
        weights="imagenet",
        pooling="avg",
    )
    base.trainable = True  # fine-tune entire model

    inputs = layers.Input(shape=IMG_SIZE + (3,))
    x = tf.keras.applications.efficientnet.preprocess_input(inputs)
    x = base(x, training=True)
    x = layers.Dropout(0.25)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    model = models.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-4),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def export_tflite_int8(model, rep_ds, export_path: Path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = rep_ds
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.uint8
    converter.inference_output_type = tf.uint8
    tflite_model = converter.convert()
    export_path.write_bytes(tflite_model)


def representative_data_gen(ds, take=200):
    def gen():
        n = 0
        for batch, _ in ds.unbatch().batch(1).take(take):
            # Keras preprocess already scaled to 0..1 then EfficientNet preprocess rescales internally
            yield [tf.cast(batch, tf.float32)]
            n += 1
    return gen


def main():
    args = parse_args()
    data_dir = Path(args.data_dir).expanduser().resolve()
    export_dir = Path(args.export_dir).expanduser().resolve()
    export_dir.mkdir(parents=True, exist_ok=True)

    files = list_files_by_class(data_dir)
    if not files:
        raise SystemExit(f"No images found under {data_dir}")

    # Class map
    class_indices = {c:i for i,c in enumerate(CLASSES)}

    train_items, val_items, test_items = split_dataset(files, args.val_split, args.test_split)

    train_ds = make_tf_dataset(train_items, class_indices, args.batch_size, shuffle=True, augment=True)
    val_ds   = make_tf_dataset(val_items, class_indices, args.batch_size, shuffle=False, augment=False)
    test_ds  = make_tf_dataset(test_items, class_indices, args.batch_size, shuffle=False, augment=False)

    model = build_model(len(CLASSES))

    callbacks = [
        tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True, monitor="val_accuracy"),
        tf.keras.callbacks.ReduceLROnPlateau(patience=2, factor=0.5, monitor="val_loss"),
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=callbacks,
    )

    print("\nEvaluation (test set):")
    model.evaluate(test_ds)

    # Export labels
    labels_txt = export_dir / "labels.txt"
    labels_txt.write_text("\n".join(CLASSES) + "\n")

    # Export INT8 tflite
    tflite_path = export_dir / "orivis_mnv3_q.tflite"
    rep = representative_data_gen(train_ds)
    export_tflite_int8(model, rep, tflite_path)

    print("\nExported:")
    print("-", tflite_path)
    print("-", labels_txt)


if __name__ == "__main__":
    main()
