import tensorflow_datasets as tfds
import matplotlib.pyplot as plt

# Load dataset
dataset, info = tfds.load(
    "cats_vs_dogs",
    split="train",
    as_supervised=True,
    with_info=True,
)

class_names = info.features["label"].names

# Take 9 images
samples = dataset.take(9)

plt.figure(figsize=(10, 10))

for i, (image, label) in enumerate(samples):
    plt.subplot(3, 3, i + 1)
    plt.imshow(image)
    plt.title(class_names[label.numpy()])
    plt.axis("off")

plt.tight_layout()
plt.savefig("dataset_samples.png")
print("Saved: dataset_samples.png")
