#!/bin/bash
set -eu  # Exit on error

storage_dir=$1
librispeech_dir=$storage_dir/LibriSpeech
wham_dir=$storage_dir/wham_noise
librimix_outdir=$storage_dir/

# Function to download LibriSpeech/dev-clean
function LibriSpeech_test_clean() {
    if ! test -e $librispeech_dir/test-clean; then
        echo "Download LibriSpeech/test-clean into $storage_dir"
        # If downloading stalls for more than 20s, relaunch from previous state.
        wget -c --tries=0 --read-timeout=20 http://www.openslr.org/resources/12/test-clean.tar.gz -P $storage_dir
        tar -xzf $storage_dir/test-clean.tar.gz -C $storage_dir
        rm -rf $storage_dir/test-clean.tar.gz
    fi
}

# Function to download and extract wham_noise
function wham() {
    if ! test -e $wham_dir; then
        echo "Download wham_noise into $storage_dir"
        # If downloading stalls for more than 20s, relaunch from previous state.
        wget -c --tries=0 --read-timeout=20 https://my-bucket-a8b4b49c25c811ee9a7e8bba05fa24c7.s3.amazonaws.com/wham_noise.zip -P $storage_dir
        unzip -qn $storage_dir/wham_noise.zip -d $storage_dir
        rm -rf $storage_dir/wham_noise.zip
    fi
}

# Download LibriSpeech/test-clean and wham_noise in parallel
LibriSpeech_test_clean &
wham &

# Wait for downloads to complete
wait

# Path to python
python_path=python

# Run data augmentation script
$python_path scripts/augment_train_noise.py --wham_dir $wham_dir

# Generate LibriMix dataset for different numbers of sources
for n_src in 2 3; do
    metadata_dir=metadata/Libri$n_src"Mix"
    $python_path scripts/create_librimix_from_metadata.py --librispeech_dir $librispeech_dir \
        --wham_dir $wham_dir \
        --metadata_dir $metadata_dir \
        --librimix_outdir $librimix_outdir \
        --n_src $n_src \
        --freqs 8k 16k \
        --modes min max \
        --types mix_clean mix_both mix_single
done
