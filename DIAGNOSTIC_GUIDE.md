# Model Diagnostic Tool - Quick Guide

## What I Built

I've added a **Model Diagnostics** tool to your app that will help identify why your model is misclassifying obvious defects as "OK".

## Location

**Settings** → **Support & Diagnostics** → **Model Diagnostics**

## What It Does

The diagnostic tool tests your model with **4 different preprocessing schemes**:

1. **Current normalization** `[-1, 1]`: `(pixel/255 - 0.5) * 2`
2. **Simple normalization** `[0, 1]`: `pixel/255`
3. **ImageNet normalization**: `(pixel/255 - mean) / std`
4. **Raw values** `[0, 255]`: No normalization

For each scheme, it shows:
- The predicted class and confidence
- Input value range (to verify preprocessing)
- All class probabilities (bar chart)
- Detailed output analysis

## How to Use

1. Open the app
2. Go to **Settings** tab
3. Scroll to **Support & Diagnostics**
4. Tap **Model Diagnostics**
5. Tap **Pick Image & Run Diagnostics**
6. Select one of your test images (shattered glass or scratched car)
7. Wait ~5 seconds for results

## What to Look For

### ✅ **Best Case**: One normalization detects the defect

If any test shows `Crack`, `Scratch`, or another defect class, the diagnostic will highlight it with:
```
✅ FOUND ISSUE: The "Simple: pixel/255 → [0,1]" normalization detected a defect!

Your current normalization is likely incorrect. Update inference_service.dart to use this scheme.
```

**Action**: I can update `inference_service.dart` to use the correct normalization for you.

### ⚠️ **Worst Case**: All tests predict "OK"

```
⚠️ ALL TESTS PREDICT OK

This suggests the problem is not preprocessing, but rather:
1. Training data domain mismatch (model never saw images like this)
2. Model needs retraining with more diverse, real-world data
3. Check that training images actually contain visible defects
```

**Action**: You need to retrain the model with real-world automotive defect images.

## Next Steps Based on Results

### If preprocessing is the issue:
1. Tell me which normalization worked
2. I'll update `inference_service.dart` immediately
3. Test the regular Inspect flow with the fix

### If training data is the issue:
You need to:
1. Collect 200+ images per class of **real automotive defects**:
   - Real scratches on painted surfaces
   - Real cracks in glass/windshields
   - Real dents and deformations
   - Clean surfaces (OK class)
   - Real stains and discolorations

2. Put them in the expected folder structure:
   ```
   ~/orivis_data/
     Crack/
     Dent_Deformation/
     OK/
     Scratch/
     Stain_Discoloration/
   ```

3. Run the training script:
   ```bash
   cd /Users/jeromejoseph/orivis
   python3 training/train_orivis.py \
     --data_dir ~/orivis_data \
     --epochs 30 \
     --batch_size 32 \
     --model efficientnet_lite0
   ```

4. The script will export the new model to `assets/models/`

5. Rebuild and test the app

## Technical Details

The diagnostic tool:
- Uses the same TFLite interpreter as your main app
- Tests multiple preprocessing schemes in parallel
- Applies softmax to get proper probabilities
- Shows raw model outputs for debugging
- Identifies which normalization (if any) produces reasonable results

## Files Added

- `lib/services/inference_diagnostic.dart` - Diagnostic inference engine
- `lib/screens/diagnostic_screen.dart` - UI for running diagnostics
- Modified `lib/screens/settings_screen.dart` - Added menu link

## Questions?

After running the diagnostic:
1. Screenshot the results
2. Share them with me
3. I'll help you fix the issue immediately

---

**TL;DR**: Run the diagnostic tool with your defect images. If it finds a working normalization, I'll fix the code. If not, you need better training data.
