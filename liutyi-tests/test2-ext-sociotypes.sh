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
      checkpoint:           $model,
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
# Source: https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v2+sociotypes+extension
# Structure: 4 quadras × 4 sociotypes × 2 genders (F/M) = 32 prompts
# Order: quadra → type → F → M
# Inner quotes on label text preserved verbatim (\" escaped).
# ---------------------------------------------------------------------------
prompts=()

# ── Alpha Quadra ─────────────────────────────────────────────────────────────

# 01 · Seeker (ILE / ENTP) — F
prompts+=( "Cartoon style illustration of Socionics type ILE (Intuitive-Logical Extrovert, \"Don Quixote\" archetype). Energetic full-body female character in excited creative pose. One finger raised with \"eureka\" expression. Holding a strange invention or futuristic gadget. Bright sparkling eyes, wide enthusiastic smile. Light blue, yellow and turquoise color palette. Floating abstract idea symbols, lightbulb, gears and formulas around. Subtle geometric grid lines organizing the background. Bright daylight lighting, airy optimistic mood. Clean thick outlines, vibrant expressive cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Seeker\" and \"(ENTP, ILE)\"" )

# 02 · Seeker (ILE / ENTP) — M
prompts+=( "Cartoon style illustration of Socionics type ILE (Intuitive-Logical Extrovert, \"Don Quixote\" archetype). Energetic full-body male character in excited creative pose. One finger raised with \"eureka\" expression. Holding a strange invention or futuristic gadget. Bright sparkling eyes, wide enthusiastic smile. Light blue, yellow and turquoise color palette. Floating abstract idea symbols, lightbulb, gears and formulas around. Subtle geometric grid lines organizing the background. Bright daylight lighting, airy optimistic mood. Clean thick outlines, vibrant expressive cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Seeker\" and \"(ENTP, ILE)\"" )

# 03 · Mediator (SEI / ISFP) — F
prompts+=( "Cartoon style illustration of Socionics type SEI (Sensory-Ethical Introvert, \"Dumas\" archetype). Cozy relaxed full-body female character sitting comfortably. Holding a cup of tea or small dessert. Warm friendly eyes with gentle smile. Soft pastel pink, mint and cream color palette. Detailed cozy interior with blankets, pillows and warm light. Subtle glowing warm particles around the character. Peaceful harmonious atmosphere. Clean thick outlines, soft shading, vibrant but gentle cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Mediator\" and \"(ISFP, SEI)\"" )

# 04 · Mediator (SEI / ISFP) — M
prompts+=( "Cartoon style illustration of Socionics type SEI (Sensory-Ethical Introvert, \"Dumas\" archetype). Cozy relaxed full-body male character sitting comfortably. Holding a cup of tea or small dessert. Warm friendly eyes with gentle smile. Soft pastel pink, mint and cream color palette. Detailed cozy interior with blankets, pillows and warm light. Subtle glowing warm particles around the character. Peaceful harmonious atmosphere. Clean thick outlines, soft shading, vibrant but gentle cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Mediator\" and \"(ISFP, SEI)\"" )

# 05 · Enthusiast (ESE / ESFJ) — F
prompts+=( "Cartoon style illustration of Socionics type ESE (Ethical-Sensory Extrovert, \"Hugo\" archetype). Energetic full-body female character with open welcoming pose. Bright joyful smile and expressive sparkling eyes. Warm yellow, orange and coral color palette. Festive cozy café or party background with string lights. Glowing emotional waves radiating from the character. Silhouettes of happy friends in background. Floating warm light particles. Bright cheerful lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Enthusiast\" and \"(ESFJ, ESE)\"" )

# 06 · Enthusiast (ESE / ESFJ) — M
prompts+=( "Cartoon style illustration of Socionics type ESE (Ethical-Sensory Extrovert, \"Hugo\" archetype). Energetic full-body male character with open welcoming pose. Bright joyful smile and expressive sparkling eyes. Warm yellow, orange and coral color palette. Festive cozy café or party background with string lights. Glowing emotional waves radiating from the character. Silhouettes of happy friends in background. Floating warm light particles. Bright cheerful lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Enthusiast\" and \"(ESFJ, ESE)\"" )

# 07 · Analyst (LII / INTJ) — F
prompts+=( "Cartoon style illustration of Socionics type LII (Logical-Intuitive Introvert, \"Robespierre\" archetype). Calm analytical full-body female character standing with straight posture. Holding a book or transparent tablet with formulas and geometric diagrams. Focused thoughtful expression. Light blue, white and soft gray color palette. Symmetrical composition with floating geometric shapes and logical schemes. Subtle branching idea lines in background. Bright clean lighting, minimalist airy atmosphere. Thick clean outlines, precise cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Analyst\" and \"(INTJ, LII)\"" )

# 08 · Analyst (LII / INTJ) — M
prompts+=( "Cartoon style illustration of Socionics type LII (Logical-Intuitive Introvert, \"Robespierre\" archetype). Calm analytical full-body male character standing with straight posture. Holding a book or transparent tablet with formulas and geometric diagrams. Focused thoughtful expression. Light blue, white and soft gray color palette. Symmetrical composition with floating geometric shapes and logical schemes. Subtle branching idea lines in background. Bright clean lighting, minimalist airy atmosphere. Thick clean outlines, precise cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Analyst\" and \"(INTJ, LII)\"" )

# ── Beta Quadra ──────────────────────────────────────────────────────────────

# 09 · Mentor (EIE / ENFJ) — F
prompts+=( "Cartoon style illustration of Socionics type EIE (Ethical-Intuitive Extrovert, \"Hamlet\" archetype). Dynamic theatrical scene with bold red and black color palette. Full-body female character standing on a stage under a dramatic spotlight. Flowing cape, exaggerated expressive pose with open arms. Large emotional eyes, intense passionate facial expression. Stylized glowing energy waves radiating from the character. Silhouetted audience in background. Subtle symbolic clock or spiral time motif behind. High contrast lighting, thick outline, vibrant colors, 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Mentor\" and \"(ENFJ, EIE)\"" )

# 10 · Mentor (EIE / ENFJ) — M
prompts+=( "Cartoon style illustration of Socionics type EIE (Ethical-Intuitive Extrovert, \"Hamlet\" archetype). Dynamic theatrical scene with bold red and black color palette. Full-body male character standing on a stage under a dramatic spotlight. Flowing cape, exaggerated expressive pose with open arms. Large emotional eyes, intense passionate facial expression. Stylized glowing energy waves radiating from the character. Silhouetted audience in background. Subtle symbolic clock or spiral time motif behind. High contrast lighting, thick outline, vibrant colors, 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Mentor\" and \"(ENFJ, EIE)\"" )

# 11 · Inspector (LSI / ISTJ) — F
prompts+=( "Cartoon style illustration of Socionics type LSI (Logical-Sensory Introvert, \"Maxim Gorky\" archetype). Structured and symmetrical composition. Full-body female character standing firmly with straight posture. Arms crossed or behind back, serious calm expression. Wearing a structured formal coat or uniform-style outfit. Cold blue, steel and dark gray color palette. Geometric grid lines and architectural fortress elements in the background. Sharp clean outlines, minimal exaggerated emotion. High contrast cool lighting, strong shadows. Symbolic order, discipline, and control atmosphere. 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Inspector\" and \"(ISTJ, LSI)\"" )

# 12 · Inspector (LSI / ISTJ) — M
prompts+=( "Cartoon style illustration of Socionics type LSI (Logical-Sensory Introvert, \"Maxim Gorky\" archetype). Structured and symmetrical composition. Full-body male character standing firmly with straight posture. Arms crossed or behind back, serious calm expression. Wearing a structured formal coat or uniform-style outfit. Cold blue, steel and dark gray color palette. Geometric grid lines and architectural fortress elements in the background. Sharp clean outlines, minimal exaggerated emotion. High contrast cool lighting, strong shadows. Symbolic order, discipline, and control atmosphere. 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Inspector\" and \"(ISTJ, LSI)\"" )

# 13 · Marshal (SLE / ESTP) — F
prompts+=( "Cartoon style illustration of Socionics type SLE (Sensory-Logical Extrovert, \"Zhukov\" archetype). Dynamic action pose, confident and dominant stance. Full-body female character stepping forward with strong body language. Intense direct gaze, bold facial expression. Strong shoulders, structured outfit with tactical or military-inspired design. Red, orange and dark dramatic color palette. Background with stylized fortress, tactical map grid or battlefield silhouette. Motion lines and dust effects to emphasize action and power. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Marshal\" and \"(ESTP, SLE)\"" )

# 14 · Marshal (SLE / ESTP) — M
prompts+=( "Cartoon style illustration of Socionics type SLE (Sensory-Logical Extrovert, \"Zhukov\" archetype). Dynamic action pose, confident and dominant stance. Full-body male character stepping forward with strong body language. Intense direct gaze, bold facial expression. Strong shoulders, structured outfit with tactical or military-inspired design. Red, orange and dark dramatic color palette. Background with stylized fortress, tactical map grid or battlefield silhouette. Motion lines and dust effects to emphasize action and power. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Marshal\" and \"(ESTP, SLE)\"" )

# 15 · Lyricist (IEI / INFP) — F
prompts+=( "Cartoon style illustration of Socionics type IEI (Intuitive-Ethical Introvert, \"Yesenin\" archetype). Soft dreamy atmosphere with twilight sky. Full-body female character standing on a balcony or open space with gentle posture. Large expressive thoughtful eyes, calm melancholic expression. Flowing hair and light fabric moving in soft wind. Blue, violet and soft pink color palette. Glowing spiral mist or symbolic timeline fading into distance. Subtle transparent clock motif in background. Warm emotional glow around the character. Soft lighting, smooth shading, clean cartoon outlines. Poetic romantic mood, high detail, 4k resolution. Text in a bottom right corner reads \"Lyricist\" and \"(INFP, IEI)\"" )

# 16 · Lyricist (IEI / INFP) — M
prompts+=( "Cartoon style illustration of Socionics type IEI (Intuitive-Ethical Introvert, \"Yesenin\" archetype). Soft dreamy atmosphere with twilight sky. Full-body male character standing on a balcony or open space with gentle posture. Large expressive thoughtful eyes, calm melancholic expression. Flowing hair and light fabric moving in soft wind. Blue, violet and soft pink color palette. Glowing spiral mist or symbolic timeline fading into distance. Subtle transparent clock motif in background. Warm emotional glow around the character. Soft lighting, smooth shading, clean cartoon outlines. Poetic romantic mood, high detail, 4k resolution. Text in a bottom right corner reads \"Lyricist\" and \"(INFP, IEI)\"" )

# ── Gamma Quadra ─────────────────────────────────────────────────────────────

# 17 · Politician (SEE / ESFP) — F
prompts+=( "Cartoon style illustration of Socionics type SEE (Sensory-Ethical Extrovert, \"Napoleon\" archetype). Confident charismatic full-body female character in dynamic leader pose. Strong body language, one hand on hip or pointing forward. Bold expressive eyes with charming confident smile. Modern stylish outfit, urban hero aesthetic. Vibrant gold, deep blue and neon accent color palette. City skyline or neon urban background. Energy sparks and motion lines around the character. Subtle glowing connection lines linking to silhouettes of allies. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Politician\" and \"(ESFP, SEE)\"" )

# 18 · Politician (SEE / ESFP) — M
prompts+=( "Cartoon style illustration of Socionics type SEE (Sensory-Ethical Extrovert, \"Napoleon\" archetype). Confident charismatic full-body male character in dynamic leader pose. Strong body language, one hand on hip or pointing forward. Bold expressive eyes with charming confident smile. Modern stylish outfit, urban hero aesthetic. Vibrant gold, deep blue and neon accent color palette. City skyline or neon urban background. Energy sparks and motion lines around the character. Subtle glowing connection lines linking to silhouettes of allies. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Politician\" and \"(ESFP, SEE)\"" )

# 19 · Critic (ILI / INTP) — F
prompts+=( "Cartoon style illustration of Socionics type ILI (Intuitive-Logical Introvert, \"Balzac\" archetype). Calm analytical full-body female character standing slightly aside. Hands in pockets or holding a tablet/book. Subtle skeptical thoughtful facial expression. Dark purple, graphite and deep blue color palette. Urban twilight background with distant city lights. Transparent timeline or spiral perspective fading into distance. Floating minimalistic charts, numbers and data interface elements. Soft cool lighting, clean sharp cartoon outlines. Intellectual calm atmosphere, high detail, 4k resolution. Text in a bottom right corner reads \"Critic\" and \"(INTP, ILI)\"" )

# 20 · Critic (ILI / INTP) — M
prompts+=( "Cartoon style illustration of Socionics type ILI (Intuitive-Logical Introvert, \"Balzac\" archetype). Calm analytical full-body male character standing slightly aside. Hands in pockets or holding a tablet/book. Subtle skeptical thoughtful facial expression. Dark purple, graphite and deep blue color palette. Urban twilight background with distant city lights. Transparent timeline or spiral perspective fading into distance. Floating minimalistic charts, numbers and data interface elements. Soft cool lighting, clean sharp cartoon outlines. Intellectual calm atmosphere, high detail, 4k resolution. Text in a bottom right corner reads \"Critic\" and \"(INTP, ILI)\"" )

# 21 · Entrepreneur (LIE / ENTJ) — F
prompts+=( "Cartoon style illustration of Socionics type LIE (Logical-Intuitive Extrovert, \"Jack London\" archetype). Dynamic full-body female character stepping forward confidently. Holding a glowing tablet with rising charts and growth arrows. Pointing forward with determined expression. Modern stylish business or tech-inspired outfit. Golden, deep blue and graphite color palette. Urban futuristic skyline background. Holographic graphs, trend lines and data elements floating around. Perspective light path leading into the future. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Entrepreneur\" and \"(ENTJ, LIE)\"" )

# 22 · Entrepreneur (LIE / ENTJ) — M
prompts+=( "Cartoon style illustration of Socionics type LIE (Logical-Intuitive Extrovert, \"Jack London\" archetype). Dynamic full-body male character stepping forward confidently. Holding a glowing tablet with rising charts and growth arrows. Pointing forward with determined expression. Modern stylish business or tech-inspired outfit. Golden, deep blue and graphite color palette. Urban futuristic skyline background. Holographic graphs, trend lines and data elements floating around. Perspective light path leading into the future. High contrast lighting, thick clean outlines, vibrant cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Entrepreneur\" and \"(ENTJ, LIE)\"" )

# 23 · Guardian (ESI / ISFJ) — F
prompts+=( "Cartoon style illustration of Socionics type ESI (Ethical-Sensory Introvert, \"Dreiser\" archetype). Calm strong full-body female character standing firmly. Hands gently crossed or one hand near the heart. Serious loyal expression with deep attentive eyes. Dark green, burgundy and graphite color palette. Subtle warm glow near the chest symbolizing personal values. Soft glowing protective shield outline around the character. Background with strong vertical architectural elements. High contrast but controlled lighting. Clean thick outlines, detailed cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Guardian\" and \"(ISFJ, ESI)\"" )

# 24 · Guardian (ESI / ISFJ) — M
prompts+=( "Cartoon style illustration of Socionics type ESI (Ethical-Sensory Introvert, \"Dreiser\" archetype). Calm strong full-body male character standing firmly. Hands gently crossed or one hand near the heart. Serious loyal expression with deep attentive eyes. Dark green, burgundy and graphite color palette. Subtle warm glow near the chest symbolizing personal values. Soft glowing protective shield outline around the character. Background with strong vertical architectural elements. High contrast but controlled lighting. Clean thick outlines, detailed cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Guardian\" and \"(ISFJ, ESI)\"" )

# ── Delta Quadra ─────────────────────────────────────────────────────────────

# 25 · Administrator (LSE / ESTJ) — F
prompts+=( "Cartoon style illustration of Socionics type LSE (Logical-Sensory Extrovert, \"Stierlitz\" archetype). Confident organized full-body female character in professional attire. Holding a clipboard or tablet with checklists and progress charts. Pointing forward with focused determined expression. Warm green, beige and natural color palette. Clean organized workspace or construction/project management background. Floating task icons, check marks and structured diagrams. Bright natural daylight lighting. Thick clean outlines, vibrant but balanced cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Administrator\" and \"(ESTJ, LSE)\"" )

# 26 · Administrator (LSE / ESTJ) — M
prompts+=( "Cartoon style illustration of Socionics type LSE (Logical-Sensory Extrovert, \"Stierlitz\" archetype). Confident organized full-body male character in professional attire. Holding a clipboard or tablet with checklists and progress charts. Pointing forward with focused determined expression. Warm green, beige and natural color palette. Clean organized workspace or construction/project management background. Floating task icons, check marks and structured diagrams. Bright natural daylight lighting. Thick clean outlines, vibrant but balanced cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Administrator\" and \"(ESTJ, LSE)\"" )

# 27 · Humanist (EII / INFJ) — F
prompts+=( "Cartoon style illustration of Socionics type EII (Ethical-Intuitive Introvert, \"Dostoevsky\" archetype). Gentle calm full-body female character standing in soft natural environment. Warm attentive eyes with subtle empathetic smile. Hands softly folded or one hand near the heart. Pastel green, beige and soft earth tone color palette. Soft glowing light around the chest symbolizing personal values. Delicate branching light lines or small glowing sprouts representing possibilities. Peaceful natural background with trees or soft meadow. Clean thick outlines, soft shading, warm daylight lighting. High detail cartoon rendering, 4k resolution. Text in a bottom right corner reads \"Humanist\" and \"(INFJ, EII)\"" )

# 28 · Humanist (EII / INFJ) — M
prompts+=( "Cartoon style illustration of Socionics type EII (Ethical-Intuitive Introvert, \"Dostoevsky\" archetype). Gentle calm full-body male character standing in soft natural environment. Warm attentive eyes with subtle empathetic smile. Hands softly folded or one hand near the heart. Pastel green, beige and soft earth tone color palette. Soft glowing light around the chest symbolizing personal values. Delicate branching light lines or small glowing sprouts representing possibilities. Peaceful natural background with trees or soft meadow. Clean thick outlines, soft shading, warm daylight lighting. High detail cartoon rendering, 4k resolution. Text in a bottom right corner reads \"Humanist\" and \"(INFJ, EII)\"" )

# 29 · Advisor (IEE / ENFP) — F
prompts+=( "Cartoon style illustration of Socionics type IEE (Intuitive-Ethical Extrovert, \"Huxley\" archetype). Energetic full-body female character in playful dynamic pose. Bright sparkling eyes with friendly enthusiastic smile. Colorful creative outfit with light accessories. Light green, turquoise and pastel yellow color palette. Glowing branching idea lines and floating light spheres around the character. Open doors or portal shapes in background symbolizing possibilities. Warm soft daylight lighting. Clean thick outlines, vibrant expressive cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Advisor\" and \"(ENFP, IEE)\"" )

# 30 · Advisor (IEE / ENFP) — M
prompts+=( "Cartoon style illustration of Socionics type IEE (Intuitive-Ethical Extrovert, \"Huxley\" archetype). Energetic full-body male character in playful dynamic pose. Bright sparkling eyes with friendly enthusiastic smile. Colorful creative outfit with light accessories. Light green, turquoise and pastel yellow color palette. Glowing branching idea lines and floating light spheres around the character. Open doors or portal shapes in background symbolizing possibilities. Warm soft daylight lighting. Clean thick outlines, vibrant expressive cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Advisor\" and \"(ENFP, IEE)\"" )

# 31 · Craftsman (SLI / ISTP) — F
prompts+=( "Cartoon style illustration of Socionics type SLI (Sensory-Logical Introvert, \"Gabin\" archetype). Relaxed full-body female character in calm natural or workshop environment. Hands in pockets or holding a simple tool. Neutral thoughtful expression with subtle confident smile. Warm green, brown and soft gray color palette. Cozy workshop or forest cabin background. Visible wood, metal and fabric textures. Simple technical sketch or blueprint in background. Soft natural daylight lighting. Clean thick outlines, balanced cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Craftsman\" and \"(ISTP, SLI)\"" )

# 32 · Craftsman (SLI / ISTP) — M
prompts+=( "Cartoon style illustration of Socionics type SLI (Sensory-Logical Introvert, \"Gabin\" archetype). Relaxed full-body male character in calm natural or workshop environment. Hands in pockets or holding a simple tool. Neutral thoughtful expression with subtle confident smile. Warm green, brown and soft gray color palette. Cozy workshop or forest cabin background. Visible wood, metal and fabric textures. Simple technical sketch or blueprint in background. Soft natural daylight lighting. Clean thick outlines, balanced cartoon rendering. 4k resolution, sharp details. Text in a bottom right corner reads \"Craftsman\" and \"(ISTP, SLI)\"" )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
