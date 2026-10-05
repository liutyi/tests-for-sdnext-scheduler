# ---- LoRA: Pruna p-qwen-image-2.1 8-step ----
# Added around every prompt
PROMPT_PREFIX="<lora:p_qwen_image_2_1_8step_v0_1:1.0> "
PROMPT_SUFFIX=""

# ---- optional overrides of model parameters (uncomment / adjust as needed) ----
STEPS=8
CFG=1
AG=1
#SAMPLER="ER-SDE FlowMatch"
SAMPLER="DPM2++ 2S FlowMatch"
GUIDANCENAME="Auto"
GUIDANCESCALE=1
