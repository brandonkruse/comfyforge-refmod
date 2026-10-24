#!/bin/bash
# comfyforge-refmod entrypoint.
#
# Same job as huchukato's serverless-entrypoint.sh, plus two things that image
# cannot do: refresh custom_nodes from the baked image on every boot (so a
# rebuilt image is not masked by a stale workspace copy), and point ComfyUI at
# the refmods on the network volume.
set -e

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
BAKED="/opt/comfyui-baked"
VENV_DIR="$COMFYUI_DIR/.venv-${VENV_SUFFIX:-cu130}"

if [ ! -f "$COMFYUI_DIR/main.py" ]; then
    echo "Materializing baked ComfyUI into workspace..."
    mkdir -p "$COMFYUI_DIR"
    cp -a "$BAKED/." "$COMFYUI_DIR/"
fi

# The base image only copies custom_nodes when main.py is missing, so a warm
# host would keep running the previous image's nodes after a release. Always
# refresh them from the bake.
if [ -d "$BAKED/custom_nodes" ]; then
    echo "Refreshing custom_nodes from baked image..."
    rm -rf "$COMFYUI_DIR/custom_nodes"
    cp -a "$BAKED/custom_nodes" "$COMFYUI_DIR/custom_nodes"
fi

# Models and refmods live on the network volume. Serverless mounts it at
# /runpod-volume; the pod setup laid files out under ComfyUI/models, so that is
# /runpod-volume/ComfyUI/models here. ComfyUI reads this file from its cwd.
cp /opt/serverless/extra_model_paths.yaml "$COMFYUI_DIR/extra_model_paths.yaml"

export PATH="$VENV_DIR/bin:$PATH"
exec python3 /opt/serverless/handler.py
