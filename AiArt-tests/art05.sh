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
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+5+-+Minimalist+botanical+background
# Theme: minimalist botanical digital backgrounds
# 8 models × 5 prompts = 40 total
# Stripped: --ar, --v, --style raw, --no flags, inline resolution tags.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · Pale Stem Study
prompts+=( "A single delicate eucalyptus branch with soft sage-green leaves arranged asymmetrically on a warm off-white background. Flat lay composition, minimal shadows, muted earth tones, generous negative space, ultra-clean botanical illustration style." )

# 02 · Monstera Fragment
prompts+=( "Close-up of a single monstera leaf with precise fenestration cutouts, rendered in a duotone palette of deep forest green and pale cream. Centered composition, hard edges, no texture, modern minimalist aesthetic, digital art." )

# 03 · Dried Botanicals on Linen
prompts+=( "Three dried pampas grass stems and two pressed wildflowers scattered loosely on a soft linen-textured background in ivory and warm sand tones. Overhead perspective, natural daylight feel, subtle grain, Scandinavian minimalism." )

# 04 · Ink Grass Silhouettes
prompts+=( "Minimalist silhouettes of tall ornamental grasses and seed pods in deep charcoal ink on a pale fog-grey background. Sparse arrangement, lower-third composition, zen garden aesthetic, flat graphic style, clean linework." )

# 05 · Single Botanical Arc
prompts+=( "One long, arching olive branch with small oval leaves curving from the bottom-left corner toward the center, on a pure matte white background. Hyper-minimal, precision botanical style, soft natural shadows, print-quality detail." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Monochromatic Trace
prompts+=( "A high-resolution photograph of a single, delicate dried fern frond resting flat upon a subtly textured, warm-white watercolor paper. Soft, natural, diffused daylight, casting a very gentle, faint shadow beneath the frond. Sharp focus on the fine, intricate texture of the fern's pinnae. Strictly monochromatic palette — cream, soft beige, natural green-browns. Background remains 90% uncluttered negative space. Minimalist, clean, and elegant." )

# 07 · Deep Emerald Negative Space
prompts+=( "A macro close-up of the tip of a Monstera leaf, displaying deep emerald green tones and strong, defined linear veins. The leaf enters the frame from the bottom-left corner against a completely dark, matte, charcoal-black background. Low-key directional soft light highlighting the glossy waxy texture while leaving the majority of the frame in deep shadow. Highly detailed, moody, and sophisticated." )

# 08 · The Shadow Play
prompts+=( "A minimalist digital background featuring only the soft-focus, blurred silhouettes and shadows of various eucalyptus branches and round leaves projected onto a smooth, warm concrete wall. Gentle, dappled afternoon sunlight filtering through an unseen window. Palette of warm grey, soft charcoal, and pale sage green shadows. Calm, meditative, fluid quality with plenty of open space." )

# 09 · Sculptural White on White
prompts+=( "A minimalist sculptural composition. Three stylized, abstract ceramic botanical forms — simplified calla lilies or buds — in matte, off-white bisque, standing against a seamless, light-grey plaster wall. Clean-lined and smooth forms. Hard side light casting defined, clean geometric shadows across the wall. Very clean, sophisticated, and contemporary. Minimal texture, high detail." )

# 10 · Floating Botanical Geometry
prompts+=( "A modern minimalist flat lay composition of three perfectly formed, symmetrical botanical elements floating against a seamless, soft dusty rose background: one perfect Ginkgo leaf in pale green, one simple dried lavender sprig in natural purple-grey, and one small, perfectly round eucalyptus leaf. Arranged in a clean, understated triangle with significant empty space between them. Soft and shadowless studio lighting. Graphic, calm, and balanced." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Soft Neutral Leaves Composition
prompts+=( "Minimalist botanical background, delicate eucalyptus branches with thin stems and rounded leaves, arranged asymmetrically on a warm off-white canvas, soft diffused lighting, muted sage and beige palette, lots of negative space, subtle paper texture, ultra-clean composition, Scandinavian aesthetic, no text." )

# 12 · Monochrome Line Art Botanicals
prompts+=( "Minimalist botanical illustration, fine black line art of wildflowers and grasses, sparse composition with elegant spacing, pure white background, ultra-thin strokes, airy and refined look, high contrast, vector-style precision, modern editorial design, no shadows." )

# 13 · Abstract Terracotta Botanicals
prompts+=( "Minimalist botanical background, abstract plant shapes in terracotta, clay, and dusty rose tones, soft organic curves, flat design with slight grain texture, balanced composition with large negative space, mid-century modern influence, warm neutral palette." )

# 14 · Floating Botanical Shadows
prompts+=( "Minimalist botanical scene, soft shadows of leaves cast onto a pale cream wall, natural sunlight from the side, blurred edges, subtle gradient lighting, photorealistic yet minimal, calming atmosphere, neutral tones, high detail, no objects visible except shadows." )

# 15 · Pastel Botanical Silhouettes
prompts+=( "Minimalist botanical background, soft pastel silhouettes of tropical leaves — monstera, palm — in desaturated mint, blush, and lavender tones, clean flat shapes, gentle overlapping layers, smooth gradients, modern UI wallpaper style, lots of breathing space." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Serene Monstera Lines
prompts+=( "Minimalist botanical digital background, delicate line art of oversized monstera leaves and subtle split-leaf philodendron foliage, soft sage green and warm beige tones on a clean off-white background, generous negative space, elegant and airy composition, extremely minimal, sophisticated simplicity, flat design with very subtle texture, calm and modern aesthetic." )

# 17 · Floating Eucalyptus
prompts+=( "Minimalist botanical wallpaper, graceful floating eucalyptus branches and silver dollar leaves in muted dusty green and soft gray tones, scattered asymmetrically with plenty of empty space, very light watercolor texture, gentle shadows, premium minimalist style, soft neutral palette, luxurious simplicity, high detail, elegant and calming atmosphere." )

# 18 · Delicate Wildflower Field
prompts+=( "Minimalist botanical background, sparse delicate wildflowers and feathery grasses in soft pastel tones of blush pink, lavender, and sage on a warm cream background, extremely minimal arrangement, lots of negative space, fine line details with gentle watercolor washes, serene and airy composition, modern minimalist aesthetic, elegant and peaceful." )

# 19 · Golden Pampas & Arches
prompts+=( "Minimalist botanical digital art background, elegant pampas grass plumes and arching palm fronds in soft beige, cream, and muted olive green, combined with subtle geometric arches, very sophisticated minimalist composition, warm neutral color palette, luxurious negative space, modern organic design, premium aesthetic, soft lighting." )

# 20 · Japandi Olive Branches
prompts+=( "Minimalist Japandi botanical background, graceful olive branches with silvery leaves and small berries, soft sage green, warm taupe, and ivory color palette, asymmetrical zen composition with abundant negative space, extremely refined and elegant, clean lines, subtle texture, peaceful and sophisticated, premium minimalist style." )

# ── Qwen 3.6 Max ────────────────────────────────────────────────────────────

# 21 · Eucalyptus Sweep
prompts+=( "A minimalist botanical digital background featuring a single, gracefully curved eucalyptus branch with sparse teardrop leaves drifting across the upper right corner. Generous negative space dominates the lower left. Soft sage green and warm off-white palette. Flat vector-style illustration with a subtle paper grain texture. Clean lines, no shading clutter, UI-friendly layout. Serene modern aesthetic." )

# 22 · Geometric Monstera Base
prompts+=( "Minimalist botanical wallpaper with three simplified monstera leaves arranged along the bottom edge, rendered in clean geometric shapes. Muted olive, charcoal, and cream color blocks with gentle gradient transitions. Ample empty space above for icons or text. Flat design, crisp edges, subtle drop shadows for depth. Contemporary and calming." )

# 23 · Asymmetrical Fern Stem
prompts+=( "Abstract minimalist botanical background featuring a single vertical stem with two asymmetrical fern fronds extending outward. Limited palette of dusty rose, pale gray, and soft white. Ultra-clean composition with 70% negative space. Subtle matte grain overlay, flat illustration style, precise linework. Scandinavian modern vibe." )

# 24 · Open Olive Wreath
prompts+=( "Minimalist botanical digital backdrop showcasing a loose, open wreath of simplified olive branches forming a circular frame. Center completely empty. Muted terracotta, warm beige, and soft forest green tones. Flat vector aesthetic, crisp silhouettes, gentle layered opacity for depth. Breathable layout, elegant and uncluttered." )

# 25 · Diagonal Magnolia Buds
prompts+=( "Clean minimalist botanical background with a single diagonal branch holding five stylized magnolia buds. Monochromatic cool gray and ivory palette. Geometric precision, soft atmospheric gradient behind the botanical element, vast negative space. Vector-inspired flat design, tranquil and sophisticated, no extra elements." )

# ── GLM5 ────────────────────────────────────────────────────────────────────

# 26 · The Continuous Line Art
prompts+=( "Minimalist continuous line art of a delicate monstera leaf, off-center to the right, vast negative space on the left, warm cream background, subtle paper texture, elegant thin black ink strokes, serene and modern, highly detailed, clean aesthetic." )

# 27 · The Soft Watercolor Wash
prompts+=( "Minimalist botanical watercolor, a single sweeping branch of eucalyptus leaves fading into the top left corner, soft sage green and muted silver washes, blending seamlessly into a pure crisp white background, ethereal and calm, delicate paint bleeds, plenty of empty space, elegant." )

# 28 · The Architectural Shadow
prompts+=( "Macro photography of a single dried pampas grass stem, minimalist composition, placed on the far left third, casting a soft architectural shadow across a textured matte off-white wall, diffused gentle morning sunlight, muted earth tones, warm beige and taupe, highly detailed, shallow depth of field, tranquil workspace background." )

# 29 · The Geometric Botanical
prompts+=( "Modern minimalist botanical, a perfect thin brass ring encompassing an abstract fern frond, placed in the bottom right corner, stark charcoal dark grey background, flat vector style, clean crisp edges, ample negative space, sophisticated and sleek, subtle luxury aesthetic, dark mode desktop background." )

# 30 · The Vintage Etching
prompts+=( "Minimalist vintage botanical illustration, a small delicate seedling with fine roots exposed, placed precisely at the bottom center, faded warm parchment background, subtle sepia and muted olive green tones, traditional etching style but extremely clean and uncluttered, vast empty space above, quiet and grounded." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · Sage Eucalyptus Study
prompts+=( "A minimalist botanical digital background featuring delicate eucalyptus branches with rounded silver-green leaves, arranged in an asymmetrical composition across a warm off-white canvas. Soft natural light casts subtle shadows. Muted sage and cream color palette with generous negative space. Clean vector-like edges with gentle watercolor texture. Scandinavian aesthetic, calming and airy." )

# 32 · Monstera Shadow Play
prompts+=( "Single monstera deliciosa leaf rendered in deep emerald green against a pale blush pink background. Minimalist composition with the leaf positioned in the lower third, creating expansive negative space above. Soft diffused lighting creates gentle shadow gradients. Matte finish with subtle paper texture. Modern, sophisticated, and serene. High-end editorial style." )

# 33 · Dried Botanical Line Art
prompts+=( "Minimalist illustration of dried pampas grass and oat grass stems in warm terracotta and sand tones on a soft clay-colored background. Delicate linear quality with fine stem details and wispy plumes. Asymmetrical arrangement flowing from bottom-left to center. Japanese wabi-sabi influence with organic imperfections. Muted earth-tone palette, generous breathing room, contemplative mood." )

# 34 · Fern Frond Negative Space
prompts+=( "A single unfurling fern frond in muted forest green, positioned vertically along the right edge of a clean ivory background. Extreme minimalism with 70% negative space. Soft focus on the fiddlehead curl, sharp detail on the leaflet edges. Morning dew droplets suggested but not overt. Zen-like simplicity, matte ceramic texture overlay. Restful and balanced composition." )

# 35 · Wild Grass Horizon
prompts+=( "Panoramic minimalist botanical scene featuring tall, slender wild grasses and seed heads in soft wheat and sage colors, silhouetted against a gradient background transitioning from warm pearl at the bottom to pale sky blue at the top. Delicate line work, ethereal and weightless quality. Scandinavian-Japanese fusion aesthetic. Subtle grain texture, dreamlike atmosphere, peaceful and expansive." )

# ── Deepseek ────────────────────────────────────────────────────────────────

# 36 · Ethereal Monstera Silhouettes
prompts+=( "A minimalist digital background featuring large monstera leaves in gentle sage and eucalyptus green, softly overlapping against an off-white, nearly cream canvas. The leaves are reduced to smooth, flowing silhouettes with subtle internal veining. Generous negative space on the top right and bottom left creates an airy, calm composition. Soft, diffused lighting casts faint, blurred shadows behind the leaves, suggesting early morning light through a sheer curtain. Serene, modern, and refreshingly simple." )

# 37 · Floating Botanical Line Art
prompts+=( "A sophisticated digital background composed of delicate, continuous-line drawings of olive branches, dried pampas grass, and eucalyptus sprigs. Rendered in a warm terracotta clay tone on a neutral stone-beige background that mimics the texture of fine mulberry paper. The botanical elements appear to float gently across the canvas, clustered subtly in the lower left corner while leaving 70% of the space open and breathable. Thin, organic lines vary in weight slightly, giving a hand-drawn, artisanal feel. Minimal, refined, and earthy." )

# 38 · Single Stem Zen Composition
prompts+=( "A highly minimalist background centered on a single, elegant stem of Japanese flowering quince placed in a simple cylindrical glass vase barely visible at the bottom edge. A few buds and one open blossom in muted blush pink stand out against a deep charcoal background that softly gradients upwards into a gentle sage-green mist. Directional lighting from the left casting a single soft shadow. Perfectly centered but sparse, embodying wabi-sabi stillness and calm. Plenty of dark space for icons or a clock widget." )

# 39 · Watercolor Ferns and Morning Dew
prompts+=( "A dreamy digital background with watercolor-washed fern fronds painted in translucent layers of celadon, soft moss, and pale aquamarine. The ferns are clustered lightly in the bottom-right corner, their tips dissolving into an almost white, misty background. Tiny, carefully placed dewdrops with soft highlights and subtle refraction rest on the fronds. Light pours in from an unseen window on the left, creating a luminous, glass-like finish. Crisp, pure, and spa-like, with a tremendous sense of air and light." )

# 40 · Architectural Tropical Minimalism
prompts+=( "A bold, graphic background featuring a single, flattened fan of a traveler's palm leaf in matte charcoal and soft black. The leaf is digitally reduced to a clean, almost geometric silhouette with a subtle, velvety texture, placed perfectly off-center to the left, partially bleeding out of the frame. Background of pale concrete blush — warm rose-gray with a very fine grain. A faint, whisper-thin horizontal line of pale gold runs across the upper third, adding architectural structure. Sharp yet warm, bridging nature and contemporary design." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

