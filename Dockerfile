# comfyforge-refmod — the pod quality recipe as a scale-to-zero worker.
#
# Extends huchukato/runpod-minimax-h3 (ComfyUI + the MiniMax node stack + a
# handler that already accepts a raw API graph on input.prompt_graph) with the
# one thing that image lacks: entert-ai/ComfyUI-H3-RefMods-Lab, so a job can be
# the same graph the 4090 pods run (H3RefModLabLoad -> H3RefModLabTextEncode ->
# 10Eros int8 UNET + ref2v turbo LoRA, euler/simple/10 steps, 960x544x121).
#
# Weights are NOT baked. They live on network volume vbwewsfizl, which a
# serverless worker mounts at /runpod-volume (a pod mounts the same bytes at
# /workspace). extra_model_paths.yaml.template maps both layouts.

# Public Docker Hub base. The registry.runpod.net tag is a Hub build image and
# rejects pulls from anywhere but Runpod's own workers, so it cannot be a base
# here. huchukato/runpod-minimax-h3's own Dockerfile starts FROM this same image
# and bakes the handler, entrypoint and workflow templates that this worker
# expects at /opt/serverless and /opt/comfyui-baked.
FROM huchukato/comfyui-base:cu130

ENV GIT_TERMINAL_PROMPT=0
RUN git clone --depth 1 --branch main \
      https://github.com/entert-ai/ComfyUI-H3-RefMods-Lab.git \
      /opt/comfyui-baked/custom_nodes/ComfyUI-H3-RefMods-Lab \
    && if [ -f /opt/comfyui-baked/custom_nodes/ComfyUI-H3-RefMods-Lab/requirements.txt ]; then \
         pip install --no-cache-dir -r /opt/comfyui-baked/custom_nodes/ComfyUI-H3-RefMods-Lab/requirements.txt \
         || echo "H3-RefMods-Lab requirements failed — node may not register"; \
       fi \
    && pip cache purge

# The base entrypoint only materializes /opt/comfyui-baked into the workspace
# when main.py is absent, so a rebuilt image would keep stale nodes on a warm
# host. Always refresh the custom_nodes tree from the bake.
COPY entrypoint.sh /opt/serverless/entrypoint-refmod.sh
COPY extra_model_paths.yaml /opt/serverless/extra_model_paths.yaml
# The base image is only the ComfyUI stack. The handler that accepts a raw graph
# on input.prompt_graph comes from huchukato/runpod-minimax-h3 and is vendored
# here so the image does not depend on registry.runpod.net for it.
COPY handler.py /opt/serverless/handler.py
RUN chmod +x /opt/serverless/entrypoint-refmod.sh

ENTRYPOINT ["/opt/serverless/entrypoint-refmod.sh"]
