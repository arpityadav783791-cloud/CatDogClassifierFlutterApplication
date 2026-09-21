import tensorflow_datasets as tfds

# Load dataset
dataset, info = tfds.load(
    "cats_vs_dogs",
    split="train",
    as_supervised=True,
    with_info=True,
)

print("\n========== DATASET INFO ==========")
print("Dataset:", info.name)
print("Total images:", info.splits["train"].num_examples)
print("Classes:", info.features["label"].names)

print("\n========== SAMPLE DATA ==========")

for image, label in dataset.take(5):
    print("Image shape:", image.shape)
    print("Label:", label.numpy())
    print("Class:", info.features["label"].names[label.numpy()])
    print("--------------------------------")
