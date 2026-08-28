#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/Qwen/Qwen-Image-2512 [25468b98e3]"' >&2
  exit 1
fi

# ---- HELPERS ---------------------------------------------------------------
urlencode() {
  local string="$1" encoded="" i char
  for (( i=0; i<${#string}; i++ )); do
    char="${string:i:1}"
    case "$char" in
      [a-zA-Z0-9._~-]) encoded+="$char" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'$char" ;;
    esac
  done
  printf '%s' "$encoded"
}

queue_job() {
  local index="$1"
  local prompt="$2"
  local task_name
  task_name="$(printf '%02d' "$index") ${prompt:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${prompt:0:120}"

  local json
  json=$(jq -n \
    --arg  prompt   "$prompt"   \
    --arg  sampler  "$SAMPLER"  \
    --arg  model    "$MODEL"    \
    --argjson steps  $STEPS     \
    --argjson cfg    $CFG       \
    --argjson ag     $AG        \
    --argjson w      $WIDTH     \
    --argjson h      $HEIGHT    \
    --argjson seed   $SEED      \
    '{
      sd_model_checkpoint: $model,
      prompt:       $prompt,
      steps:        $steps,
      cfg_scale:    $cfg,
      pag_scale:    $ag,
      width:        $w,
      height:       $h,
      sampler_name: $sampler,
      seed:         $seed,
      batch_size:   1,
      n_iter:       1,
      save_images:  true
    }')

  curl -s -X POST "$SCHED?name=$(urlencode "$task_name")" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null
}

# ---- PROMPTS ---------------------------------------------------------------
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+7+-+Five+tags+art
# Theme: CivitAI Five Tag Challenge — exactly 5 content tags + composition modifiers
# Format: artist/style, subject, environment, lighting/fx, detail, [modifiers]
# 8 models × 5 prompts = 40 total
# Prompts are intentionally tag-based (not prose) — preserved verbatim from wiki.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · Temple Swallowed by Time
prompts+=( "oil painting, ancient ruins, overgrown, golden hour, god rays, dynamic angle, no humans" )

# 02 · Fox Spirit Under the Petal Snow
prompts+=( "mika pikazo, fox girl, cherry blossoms, moonlight, fireflies, dynamic pose" )

# 03 · The Dragon Between Thunder and Dark
prompts+=( "ink (medium), dragon, stormy sky, silhouette, lightning, dynamic view, dynamic angle" )

# 04 · Island at the Edge of the Universe
prompts+=( "watercolor (medium), floating island, starry sky, bioluminescence, mist, dynamic view, no humans" )

# 05 · Blade in the Neon Rain
prompts+=( "quasarcake, samurai, neon lights, rain, chromatic aberration, dynamic pose, dynamic angle" )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · Cyberpunk Ronin
prompts+=( "guweiz, samurai, neon lights, rain, puddle, dynamic angle" )

# 07 · Prism Android
prompts+=( "mika pikazo, android, outer space, glowing, colorful, dynamic pose" )

# 08 · Silent Shinto Winter
prompts+=( "hasui kawase, shrine, snowing, moonlight, torii, dynamic view, no humans" )

# 09 · The Desert Monolith
prompts+=( "moebius, giant creature, desert, ruins, monolith, dynamic view, no humans" )

# 10 · The Gothic Archivist
prompts+=( "abigail larson, black cat, library, candlelight, old book, no humans" )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Neon Shrine Reverie
prompts+=( "mika pikazo, shrine, night, neon lights, glowing particles, dynamic view, dynamic angle" )

# 12 · Abyssal Leviathan Drift
prompts+=( "underwater, sea monster, deep sea, bioluminescence, dark, dynamic view" )

# 13 · Golden Hour Duelist
prompts+=( "samurai, sunset, silhouette, dramatic lighting, wind, dynamic pose, dynamic angle" )

# 14 · Floating Garden Dreamscape
prompts+=( "floating island, garden, sky, clouds, pastel colors, dynamic view" )

# 15 · Clockwork Cathedral Interior
prompts+=( "steampunk, cathedral, interior, intricate details, gears, dynamic view, dynamic angle" )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Serene Spirit Fox
prompts+=( "mika pikazo, fox girl, bamboo forest, ethereal glow, pastel palette, dynamic view, dynamic angle" )

# 17 · Abandoned Celestial Citadel
prompts+=( "quasarcake, ancient ruins, floating island, dramatic clouds, glowing runes, dynamic view, dynamic angle, no humans" )

# 18 · Deep Sea Guardian
prompts+=( "oil painting, sea turtle, underwater, bioluminescent, coral reef, dynamic view" )

# 19 · Melancholy Urban Ghost
prompts+=( "loish, cyberpunk city, rainy night, silhouette, neon lights, dynamic angle, dynamic pose" )

# 20 · Eternal Blossoming Tree
prompts+=( "studio ghibli, ancient tree, flower field, sunset, wind, dynamic view, no humans" )

# ── Qwen 3.6 Max ────────────────────────────────────────────────────────────

# 21 · Arcane Scholar's Sanctum
prompts+=( "wlop, elf, ancient library, volumetric lighting, stained glass, dynamic angle" )

# 22 · Last Train at Dusk
prompts+=( "makoto shinkai, train station, rainy day, twilight, reflection, dynamic view" )

# 23 · Moonlit Grove Guardian
prompts+=( "studio ghibli, white stag, misty forest, moonlight, fireflies, no humans" )

# 24 · Neon Circuit Drifter
prompts+=( "masamune shirow, android, neon city, chromatic aberration, hologram, dynamic pose, dynamic angle" )

# 25 · Afternoon Still Life
prompts+=( "impressionism, tea set, sunroom, dappled sunlight, dried flowers, no humans, dynamic view" )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · Celestial Enchantress
prompts+=( "mika pikazo, witch, floating island, starry sky, glowing particles, dynamic view, dynamic angle, dynamic pose" )

# 27 · Monolith of the Fog
prompts+=( "tsutomu nihei, giant robot, ruins, foggy, silhouette, dynamic view, dynamic angle, no humans" )

# 28 · Refracted Koi Pond
prompts+=( "watercolor (medium), koi fish, underwater, sunlight, chromatic aberration, dynamic view, dynamic pose, no humans" )

# 29 · Tempest Ascendant
prompts+=( "ukiyo-e, dragon, stormy sea, dramatic lighting, two-tone background, dynamic angle, dynamic pose, no humans" )

# 30 · Twilight Procession
prompts+=( "ke-ta, shrine maiden, cherry blossoms, golden hour, lens flare, dynamic view, dynamic pose" )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · Neon Genesis
prompts+=( "mecha, cyberpunk, neon lighting, two-tone background, chromatic aberration, dynamic angle, dynamic pose" )

# 32 · Ukiyo-e Dawn
prompts+=( "ukiyo-e, torii, cherry blossoms, golden hour, reflection, no humans, dynamic view" )

# 33 · Fairy Ring
prompts+=( "watercolor (medium), fairy, mushroom, dappled sunlight, floating, dynamic pose" )

# 34 · Sacred Light
prompts+=( "stained glass, ruins, volumetric lighting, silhouette, sunset, no humans, dynamic angle" )

# 35 · Shrine Guardian
prompts+=( "mika pikazo, fox girl, torii, cherry blossoms, glowing particles, dynamic view, dynamic angle, dynamic pose" )

# ── Deepseek ────────────────────────────────────────────────────────────────

# 36 · Ethereal Forest Awakening
prompts+=( "watercolor (medium), spirit, ancient ruins, ethereal glow, glowing particles, dynamic view, dynamic angle" )

# 37 · Neon Dystopian Patrol
prompts+=( "cyberpunk, android, night city, neon glow, wet ground, dynamic view, dynamic angle, dynamic pose" )

# 38 · Storm Dragon Silhouette
prompts+=( "ukiyo-e, dragon, stormy sky, cinematic lighting, silhouette, dynamic view, dynamic angle, dynamic pose" )

# 39 · Gothic Prism Refraction
prompts+=( "gothic, stained glass window, cathedral interior, moody lighting, colorful, dynamic view, dynamic angle" )

# 40 · Abyssal Drift
prompts+=( "oil painting, jellyfish, deep sea, bioluminescent, black background, dynamic view, dynamic angle" )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

