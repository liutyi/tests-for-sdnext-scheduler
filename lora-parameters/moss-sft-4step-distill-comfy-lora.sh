# ---- LoRA: Pruna p-qwen-image-2.1 8-step ----
# Added around every prompt
PROMPT_PREFIX=""
PROMPT_SUFFIX=" <lora:moss_sft_4step_rank_64_lora_comfyui-fp32:1.0>"

# ---- optional overrides of model parameters (uncomment / adjust as needed) ----
STEPS=4
CFG=1
AG=1
#SAMPLER="ER-SDE FlowMatch"
SAMPLER="Default"
GUIDANCENAME="Auto"
GUIDANCESCALE=1
