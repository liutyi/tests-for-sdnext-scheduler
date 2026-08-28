#!/usr/bin/env bash
set -e


# ---- PROMPTS ----
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
