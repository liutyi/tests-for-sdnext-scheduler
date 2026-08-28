#!/usr/bin/env bash
set -e


# ---- PROMPTS ----
prompts=(
"a red apple on a wooden table, soft natural lighting"
"a small cabin in the mountains, watercolor painting, pastel tones"
"portrait photo of a 35 year old man, neutral expression, studio lighting, 85mm lens"
"a cat sitting in the center of a window frame, symmetrical composition, morning light"
"a street scene at night illuminated only by neon blue and pink lights"

"three glass bottles, one filled with red liquid, one blue, one green, arranged in a row on a reflective surface"
"a chrome sphere and a matte black cube on a white surface, strong directional sunlight casting sharp shadows"
"cinematic photo of a woman walking in rain, wet asphalt reflections, shot on 50mm lens, shallow depth of field"
"a futuristic city skyline in the style of cyberpunk and art deco, highly detailed, dramatic lighting"
"extreme low angle view of a towering skyscraper disappearing into fog, wide angle lens distortion"

"a wooden chair placed on top of a table inside a small room, viewed from the doorway"
"a chef flipping a pancake in mid air in a busy kitchen, motion blur, dynamic composition"
"five birds sitting on a wire, each bird a different color and size"
"a storefront sign that clearly reads \"OPEN 24 HOURS\", realistic street photography"
"a candle lighting a dark room, objects gradually fading into shadow, realistic light falloff"

"two identical twins, one wearing black suit and one wearing white suit, standing side by side, neutral background"
"a cluttered desk with a laptop, a coffee mug, scattered papers, a glowing desk lamp, and a small plant near the edge"
"a glass of water on a mirror surface reflecting a sunset sky, realistic reflections and refractions"
"a hyper realistic photograph of a dragon sitting in a modern living room, natural lighting"
"a perfectly centered circle inside a square frame, minimalistic design, high contrast black and white"
)

# ---- QUEUE JOBS ----
i=1
for prompt in "${prompts[@]}"; do
  printf "[QUEUE %02d] %s\n" "$i" "$prompt"
  json=$(jq -n \
    --arg prompt "$prompt" \
    --arg sampler "$SAMPLER" \
    --argjson steps $STEPS \
    --arg checkpoint "$MODEL" \
    --argjson cfg $CFG \
    --argjson ag $AG \
    --argjson w $WIDTH \
    --argjson h $HEIGHT \
    --argjson seed $SEED \
    '{
        sd_model_checkpoint: $checkpoint,
        prompt: $prompt,
        steps: $steps,
        cfg_scale: $cfg,
        pag_scale: $ag,
        width: $w,
        height: $h,
        sampler_name: $sampler,
        seed: $seed,
        batch_size: 1,
        n_iter: 1,
        save_images: true
    }')


  TASK_NAME="$(printf '%02d' $i) ${prompt:0:16}"
  ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TASK_NAME")

  curl -s -X POST "$SCHED?name=$ENCODED" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null


  ((i++))
done

echo "✅ All jobs queued in scheduler"
