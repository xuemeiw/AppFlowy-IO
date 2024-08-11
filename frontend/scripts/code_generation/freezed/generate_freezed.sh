#!/usr/bin/env bash

# check the cost time
start_time=$(date +%s)

# read the arguments to skip the pub get and package get
skip_pub_get=false
skip_pub_packages_get=false
verbose=false
include_packages=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --skip-pub-get)
    skip_pub_get=true
    shift
    ;;
  --skip-pub-packages-get)
    skip_pub_packages_get=true
    shift
    ;;
  --verbose)
    verbose=true
    shift
    ;;
  --include-packages)
    include_packages=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

# Store the current working directory
original_dir=$(pwd)

cd "$(dirname "$0")"

# Navigate to the project root
cd ../../../appflowy_flutter

if [ "$include_packages" = true ]; then
  # Navigate to the packages directory
  cd packages
  for d in */; do
    # Navigate into the subdirectory
    cd "$d"

    # Check if the pubspec.yaml file exists and contains the freezed dependency
    if [ -f "pubspec.yaml" ] && grep -q "build_runner" pubspec.yaml; then
      echo "🧊 Start generating freezed files ($d)."
      if [ "$skip_pub_packages_get" = false ]; then
        if [ "$verbose" = true ]; then
          flutter packages pub get
        else
          flutter packages pub get >/dev/null 2>&1
        fi
      fi
      if [ "$verbose" = true ]; then
        dart run build_runner build
      else
        dart run build_runner build >/dev/null 2>&1
      fi
      echo "🧊 Done generating freezed files ($d)."
    fi

    # Navigate back to the packages directory
    cd ..
  done
fi

cd ..

# Navigate to the appflowy_flutter directory and generate files
echo "🧊 Start generating freezed files (AppFlowy)."

if [ "$skip_pub_packages_get" = false ]; then
  if [ "$verbose" = true ]; then
    flutter packages pub get
  else
    flutter packages pub get >/dev/null 2>&1
  fi
fi

if [ "$verbose" = true ]; then
  dart run build_runner build -d
else
  dart run build_runner build >/dev/null 2>&1
fi

# Return to the original directory
cd "$original_dir"

echo "🧊 Done generating freezed files."

# echo the cost time
end_time=$(date +%s)
cost_time=$((end_time - start_time))
echo "🧊 Freezed files generation cost $cost_time seconds."
