#!/usr/bin/env bash


# ---- PROMPT LIST ----
prompts=(
"Portrait of an elderly woman, extreme close-up, wrinkled skin, sunlight, highly detailed skin texture."
"Street photography, a man in a red raincoat walking through neon-lit Tokyo rain, reflections on pavement, 35mm lens, cinematic lighting."
"A cinematic wide shot of a multi-generational family eating dinner in a rustic kitchen; steam rising from food, warm candlelight, shallow depth of field, authentic atmosphere."
"High-fashion editorial, model wearing a dress made entirely of liquid mercury, floating in a zero-gravity white marble room, sharp focus, futuristic aesthetic."
"Minimalist flat vector illustration of a mountain peak, blue and orange palette, clean lines, geometric shapes."
"1990s Japanese anime style, a girl looking out a train window at a futuristic cityscape, soft lo-fi aesthetic, hand-drawn look."
"An intricate oil painting in the style of Rembrandt: a robotic knight kneeling in a dark cathedral, a single beam of light hitting the rusted metal armor, dramatic chiaroscuro."
"A chaotic Risograph print of a jazz band, overlapping neon colors, grainy texture, abstract shapes, misaligned ink layers, retro print aesthetic."
"A glowing neon sign on a brick wall that says the word 'FUTURE', night time, realistic textures, vibrant light spill."
"A transparent glass cube sitting on a wooden table, inside the cube is a tiny thunderstorm with lightning and dark clouds, hyper-realistic."
"A double exposure photograph: the silhouette of a thinker's head merged with a sprawling, intricate clockwork mechanism and gears, conceptual art."
"A realistic cardboard box with 'TOP SECRET' written in bold marker, with a tiny galaxy spilling out of the opening, stars and nebulae, cinematic."
"Macro shot of a honeybee on a lavender flower, bokeh background, sharp focus on the bee's wings and eyes."
"An isometric 3D diorama of a lush tropical island with a tiny waterfall and a hidden cave, tilt-shift effect, stylized miniature world."
"A vast, surreal landscape where the clouds are made of colorful cotton candy and the ocean is a mirror reflecting a giant moon, dreamlike atmosphere."
"Extreme macro of a human eye, but the iris is a detailed map of the world, hyper-realistic, 8k resolution, intricate detail."
"Brutalist concrete building, overgrown with green vines, cloudy sky, architectural photography, moody lighting."
"Interior of a futuristic library with floating bookshelves and a giant holographic globe in the center, wide angle, soft ambient glow."
"A low-angle shot of a cyberpunk skyscraper shaped like a DNA helix, glowing blue lights, flying vehicles, rainy atmosphere, epic scale."
"Cross-section view of a subterranean city inside a giant asteroid, multiple levels of gardens, factories, and living quarters, detailed technical illustration."
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
          "$OUTDIR/$(date --iso)_$(printf "%02d" $i)_ERNIE-base_seed${SEED}.png"

  ((i++))
done

echo "✅ Done. Images saved to $OUTDIR/"

