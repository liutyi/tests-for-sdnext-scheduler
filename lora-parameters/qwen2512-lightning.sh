# ---- LoRA: Pruna p-qwen-image-2.1 8-step ----
# Added around every prompt
PROMPT_PREFIX="<lora:Qwen-Image-2512-Lightning-4steps-V1_0-bf16:1.0> "
PROMPT_SUFFIX=""

# ---- optional overrides of model parameters (uncomment / adjust as needed) ----
STEPS=4
CFG=1
AG=1
#SAMPLER="ER-SDE FlowMatch"
SAMPLER="DPM2++ 2S FlowMatch"
GUIDANCENAME="Auto"
GUIDANCESCALE=1
