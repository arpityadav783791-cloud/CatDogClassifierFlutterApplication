import tensorflow_datasets as tfds

dataset, info = tfds.load(
    "cats_vs_dogs",
    split="train",
    as_supervised=True,
    with_info=True,
)

print("Dataset downloaded successfully!")
print("Number of images:", info.splits["train"].num_examples)
print("Classes:", info.features["label"].names)
