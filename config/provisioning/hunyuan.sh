#!/bin/bash

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    "hf_transfer"
    "huggingface_hub[hf_transfer]"
)

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    export HF_HUB_ENABLE_HF_TRANSFER=1
    if [[ -n $HF_TOKEN ]]; then
        $COMFYUI_VENV/bin/huggingface-cli login --token "$HF_TOKEN"
    fi

    $COMFYUI_VENV/bin/huggingface-cli download Comfy-Org/HunyuanVideo_repackaged \
        split_files/diffusion_models/hunyuan_video_t2v_720p_bf16.safetensors \
        --local-dir "${WORKSPACE}/storage/stable_diffusion/models/diffusion_models"

    $COMFYUI_VENV/bin/huggingface-cli download Comfy-Org/HunyuanVideo_repackaged \
        split_files/text_encoders/clip_l.safetensors \
        split_files/text_encoders/llava_llama3_fp8_scaled.safetensors \
        --local-dir "${WORKSPACE}/storage/stable_diffusion/models/text_encoders"

    $COMFYUI_VENV/bin/huggingface-cli download Comfy-Org/HunyuanVideo_repackaged \
        split_files/vae/hunyuan_video_vae_bf16.safetensors \
        --local-dir "${WORKSPACE}/storage/stable_diffusion/models/vae"

    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                (cd "$path" && git pull)
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

provisioning_start
