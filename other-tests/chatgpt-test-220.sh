#!/usr/bin/env bash


# ---- PROMPT LIST ----
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

# ---- OPTIONAL: SWITCH MODEL ----
if [ -n "$MODEL" ]; then
  echo "🔄 Switching model to: $MODEL"
  curl -s -X POST http://10.9.8.207:7860/sdapi/v1/options \
    -H "Content-Type: application/json" \
    -d "{\"sd_model_checkpoint\": \"$MODEL\"}" > /dev/null
  sleep 2
fi

# ---- GENERATION LOOP ----
i=1
for prompt in "${prompts[@]}"; do
  printf "\n[%02d/20] Generating...\n" "$i"

  json=$(jq -n \
    --arg prompt "$prompt" \
    --arg sampler "$SAMPLER" \
    --argjson steps $STEPS \
    --argjson cfg $CFG \
    --argjson w $WIDTH \
    --argjson h $HEIGHT \
    --argjson seed $SEED \
    '{
      prompt: $prompt,
      steps: $steps,
      cfg_scale: $cfg,
      width: $w,
      height: $h,
      sampler_name: $sampler,
      seed: $seed,
      batch_size: 1,
      n_iter: 1
    }')

  response=$(curl -s "$API" \
    -H "Content-Type: application/json" \
    -d "$json")

  # Extract base64 image and save
  echo "$response" | jq -r '.images[0]' | base64 -d > \
          "$OUTDIR/$(date --iso)_$(printf "%02d" $i)_ERMIEbase_seed${SEED}.png"

  ((i++))
done

echo "✅ Done. Images saved to $OUTDIR/"

