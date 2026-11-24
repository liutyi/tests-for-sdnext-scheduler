# ---- LoRA: Pruna p-qwen-image-2.1 8-step ----
# Added around every prompt
PROMPT_PREFIX="strangedaal. "
PROMPT_SUFFIX=" <lora:moss_sft_4step_rank_64_lora_comfyui-fp32:1.0><lora:Strange Reverie Moss_000002500-bf16:1.3>"

# ---- optional overrides of model parameters (uncomment / adjust as needed) ----
STEPS=4
CFG=1
AG=1
SAMPLER="UniPC FlowMatch"
GUIDANCENAME="Auto"
GUIDANCESCALE=1
WIDTH=1024
HEIGHT=1536
