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
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+4+Angle+and+foreshortening
# Theme: dutch angle + extreme foreshortening
# 7 models × 5 prompts = 35 total
# Inline resolution tags, --stylize flags, and aspect ratio hints stripped.
# Grok prompt 17 header corrected ("Floating Temple" — duplicate label in source).
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · Neon samurai — low-angle urban
prompts+=( "A lone samurai warrior photographed from ground level looking upward, extreme foreshortening makes the figure tower impossibly tall, katana blade filling the entire lower foreground in sharp macro detail while the warrior's face recedes into rain-drenched neon-lit sky, severe dutch angle 25°, wet asphalt reflections of crimson and violet neon signs, cinematic anamorphic lens flare, dark cyberpunk cityscape bokeh, ultra-high contrast, editorial fashion photography aesthetic." )

# 02 · Porcelain hand — still life tension
prompts+=( "A woman's hand reaching toward the camera in extreme close-up foreshortening, fingertips razor-sharp and enormous in the foreground while the wrist and arm taper into soft creamy distance, crushed black background, dutch angle 18°, skin texture lit by a single cold silver sidelight, delicate rings catching specular highlights, fine art photography mood, shot on large format film, grain texture, high key tonal range, Mapplethorpe-inspired composition." )

# 03 · Crumbling cathedral — architectural drama
prompts+=( "Worm's eye view of a gothic cathedral interior, extreme foreshortening collapses the vaulted ceiling into a dizzying funnel of stone ribs converging at a single vanishing point, ancient carved columns loom and distort in the foreground, camera tilted 30° dutch angle, shafts of dusty amber light pierce from stained glass above, crumbling plaster texture, dense atmospheric haze, hyper-detailed stone carving in the lower third, apocalyptic storm clouds visible through a broken rose window, muted ochre and slate blue palette." )

# 04 · Sprinting wolf — nature and motion
prompts+=( "A wolf sprinting directly at the lens, nose and paws massively foreshortened and filling the foreground while its haunches blur into motion lines behind, ultra-low camera angle flush with the ground, frozen mid-stride with motion blur on the legs, dutch angle 20°, backlit by a blazing amber sunset casting long wolf-shadow toward the viewer, golden dust particles caught in the light, shallow depth of field, fur strands razor-sharp on the face, National Geographic dramatic nature photography." )

# 05 · Dancer's leap — body as geometry
prompts+=( "A ballerina caught mid-leap photographed from directly above, extreme overhead foreshortening compresses the full body into an abstract geometric shape — arms wide, tutu a white halo, pointed feet impossibly small below, camera tilted 22° dutch angle, polished black marley floor as a mirror beneath, high-key studio lighting bleaches the tutu to pure white against deep charcoal, long shadow cutting diagonally across the composition, architectural minimalism, Helmut Newton severity, absolute stillness in motion." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Noir Investigator
prompts+=( "A dramatic low-angle shot of a mysterious figure in a trench coat standing in a rain-slicked alley. Extreme Dutch angle creating a sense of vertigo. The character's hand reaches directly toward the lens, appearing massive due to extreme foreshortening. High-contrast black and white with deep shadows and sharp rim lighting. Sharp focus on the fingertips, with the background blurred into a bokeh of raindrops and flickering neon." )

# 07 · The Cyber-Renaissance
prompts+=( "A vibrant cyberpunk composition featuring a pilot in a cluttered mechanical cockpit. Dutch angle tilt of 30 degrees. The pilot's booted leg is thrust forward toward the viewer, utilizing extreme foreshortening to dominate the foreground. Glowing holographic interface lights reflect on a chrome helmet. Saturated purples and teals against deep blacks, high-key lighting, and intricate mechanical textures. Shot with a wide-angle lens to accentuate the distorted perspective." )

# 08 · The Ethereal Descent
prompts+=( "A surrealist interpretation of a figure falling through a gilded, cloud-filled sky. Extreme foreshortening as the figure's hand desperately reaches for the top corner of the frame. A sharp Dutch angle orientation creates a chaotic, tumbling sensation. Soft, painterly textures with chiaroscuro lighting. Golden hour highlights, billowing white fabric, and floating geometric debris. A blend of classical textures and modern dynamic composition." )

# 09 · Brutalist Kineticism
prompts+=( "A high-octane shot from a ground-level perspective. A parkour runner leaps over a narrow gap between brutalist concrete buildings. Dutch angle emphasizes the harsh architectural geometry. The runner's lead foot is caught mid-air, magnified by extreme foreshortening as it nears the camera lens. Harsh afternoon sun creating long, jagged shadows. Gritty concrete textures and a sense of immense kinetic energy." )

# 10 · The Botanical Colossus
prompts+=( "A minimalist, conceptual image of a single giant poppy flower growing in a vast, white desert. Dutch angle horizon line. The stem curves toward the camera with extreme foreshortening, making the flower head appear massive and looming over the viewer. Surreal lighting with a pale lavender sky and stark crimson floral contrast. Clean lines, smooth gradients, and a dreamlike, liminal space atmosphere." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Neon Alley Runner (Cyberpunk Motion Distortion)
prompts+=( "A dynamic cinematic scene of a lone runner sprinting through a rain-soaked cyberpunk alley at night, captured with an aggressive Dutch angle tilt of ~35 degrees. Extreme foreshortening: one leg and arm thrust toward the camera, exaggerated perspective distortion, elongated limbs. Camera placed inches above the wet pavement, ultra-wide lens. Neon signs stretch diagonally across the frame, reflections smeared in motion blur. Heavy atmosphere, volumetric fog, chromatic aberration, high contrast lighting, electric blues and magentas. Sharp subject, streaking background. Hyper-real, cinematic, dramatic composition, depth exaggeration, dynamic tension." )

# 12 · Baroque Angel Collapse (Painterly Surrealism)
prompts+=( "A surreal baroque-style angel falling from the sky, captured in a dramatic Dutch angle of ~45 degrees. Extreme foreshortening: one hand reaching directly toward the viewer, fingers massively enlarged in perspective, wings trailing far into the distance. Composition inspired by classical oil paintings but warped by modern lens distortion. Camera positioned below, looking up. Golden-hour light slicing diagonally across clouds. Textured brushstroke aesthetic mixed with hyperreal anatomy. Deep chiaroscuro, warm golds vs cold shadows. Ethereal, tragic, grand scale, divine motion frozen mid-fall." )

# 13 · Street Samurai Close Combat (Action Freeze)
prompts+=( "A cyberpunk street samurai mid-strike, katana swinging toward the viewer, captured with a strong Dutch angle of ~30 degrees. Extreme foreshortening: blade dominates foreground, oversized and sharp, while body recedes dramatically. Camera extremely close to the weapon tip, ultra-wide perspective. Sparks and rain droplets frozen mid-air. Background city tilting diagonally, glowing signage stretched across frame. High shutter freeze and motion trails hybrid. Harsh rim lighting, reflective surfaces, gritty realism, cinematic intensity, dynamic composition." )

# 14 · Giant Hand Emerging from Ocean (Surreal Scale Distortion)
prompts+=( "A colossal human hand emerging from a stormy ocean, shot at a severe Dutch angle of ~40 degrees. Extreme foreshortening: fingers closest to camera appear enormous and distorted, while the wrist fades into distant waves. Camera positioned at water level, ultra-wide lens exaggeration. Waves crash diagonally across frame, horizon tilted dramatically. Moody sky, lightning illuminating textures. Surreal realism, monumental scale, cinematic disaster aesthetic. Deep shadows, cold blue-gray palette, high detail water simulation." )

# 15 · Fashion Editorial Leap (Avant-garde Perspective)
prompts+=( "A high-fashion model leaping toward the camera in a minimalist studio, captured with a sharp Dutch angle of ~25 degrees. Extreme foreshortening: one leg extended forward dominating the frame, shoe oversized due to perspective, torso and head receding. Camera placed low and very close, ultra-wide lens distortion. Clean white background warped diagonally. Hard directional lighting casting geometric shadows. Outfit: sculptural avant-garde couture with sharp lines. Glossy editorial finish, ultra crisp, magazine-quality, bold composition, controlled chaos." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Cyber-Fantasy Warrior
prompts+=( "A breathtaking cyber-fantasy female warrior standing dramatically from an extreme low-angle Dutch tilt, extreme foreshortening making her legs and sword appear massively elongated and towering toward the viewer, wind-swept silver hair flowing, intricate glowing armor with neon accents, dramatic rim lighting, misty volumetric god rays, dark teal and magenta color palette, cinematic masterpiece, ultra-detailed, hyper-stylized, 8k aesthetic." )

# 17 · Floating Temple (Surreal Architecture)
prompts+=( "Surreal floating ancient Japanese temple complex dramatically tilted at a sharp Dutch angle, extreme foreshortening from a very low viewpoint making the pagoda roofs and stone lanterns rush powerfully toward the camera, cherry blossoms swirling in the air, glowing lanterns, mystical fog, impossible floating islands in the background, ethereal teal and gold lighting, breathtaking cinematic composition, intricate details, otherworldly beauty, masterpiece." )

# 18 · Dynamic Male Portrait
prompts+=( "Intense male model with sharp facial features in a black trench coat, shot from extreme low Dutch angle with radical foreshortening, his outstretched hand and face dominating the frame while his body dramatically recedes, intense eye contact, moody cinematic lighting with strong rim light and deep shadows, wet reflective streets at night, neon reflections, high fashion editorial style, ultra realistic yet artistic, dramatic atmosphere, masterpiece." )

# 19 · Cosmic Ballet Dancer
prompts+=( "Graceful ballerina in a flowing white and gold dress performing mid-air leap, captured with extreme Dutch angle and radical foreshortening from below, her pointed foot and legs exploding toward the viewer, surrounded by swirling cosmic nebulae and glowing particles, weightless in space, ethereal lighting, soft volumetric glow, delicate fabric details, dreamlike and majestic, artistic masterpiece, delicate yet powerful, ultra aesthetic." )

# 20 · Dark Fantasy Cityscape
prompts+=( "Dark fantasy towering gothic cathedral spires shot from an extreme worm's-eye Dutch angle with aggressive foreshortening, the architecture dramatically converging and rushing toward the viewer, flying gargoyles and dramatic clouds, blood-red and deep indigo sky, lightning accents, intricate stone carvings, ominous yet breathtaking beauty, dark romanticism, ultra detailed, cinematic masterpiece, epic scale, moody atmosphere." )

# ── Qwen 3.6 Max ────────────────────────────────────────────────────────────

# 21 · Ethereal Reach
prompts+=( "A lone figure in a flowing charcoal coat reaches upward, their hand and forearm rendered in extreme foreshortening, looming large in the foreground while the torso recedes dramatically. Composed at a sharp Dutch angle, the tilted horizon amplifies quiet tension. Floating crystalline geometries hover in a misty pearl-gray void. Cinematic chiaroscuro lighting, soft volumetric rays, contemporary fine art aesthetic, muted sage and oxidized copper palette, painterly texture with refined digital finish, hauntingly elegant mood, masterfully layered depth, gallery-quality detail." )

# 22 · Crimson Leap
prompts+=( "A ballet dancer captured mid-leap, their leading foot and shin thrust toward the viewer in extreme foreshortening, dominating the frame while the upper body compresses into atmospheric depth. Framed with a pronounced Dutch angle, the canted perspective heightens kinetic grace. Swathes of crimson and gold silk ripple through moody stage lighting, casting long dramatic shadows. Baroque-inspired cinematic aesthetic, rich jewel-tone palette, high-contrast chiaroscuro, fine art photography style, elegant yet visceral, museum-grade composition." )

# 23 · Neon Descent
prompts+=( "A cybernetic warrior kneels on a rain-slicked obsidian platform, their katana extended directly toward the viewer in extreme foreshortening, the blade's tip massive and razor-sharp in the foreground while the hilt and arm recede sharply. Composed at a dynamic Dutch angle, the tilted frame amplifies tension. Neon cyan and magenta reflections bleed through atmospheric fog, illuminating intricate armor plating. High-end concept art aesthetic, neon-noir color grading, cinematic rim lighting, stylized realism with painterly edge work, intense and meticulously detailed." )

# 24 · Bloom of the Void
prompts+=( "A colossal night-blooming cereus flower arches toward the viewer, its foremost petals rendered in extreme foreshortening, velvety and expansive in the foreground while the floral core and a tiny silhouetted figure recede into luminous depth. Captured at a deliberate Dutch angle, the canted composition creates weightless wonder. Bioluminescent pollen drifts through a twilight indigo atmosphere. Botanical surrealism aesthetic, watercolor-meets-digital painting style, soft diffused backlighting, iridescent teal and amethyst palette, poetic and meticulously layered, gallery-quality finish." )

# 25 · Gilded Fall
prompts+=( "A reimagined Icarus plummets through a bruised twilight sky, his leading arm and shattered wing fragments thrust toward the viewer in extreme foreshortening, dominating the frame while his torso and trailing feathers compress into atmospheric perspective. Framed with a bold Dutch angle, the tilted horizon evokes graceful descent and tension. Sunlight fractures through gilded cloud layers, casting warm rim light on marble-like skin and iridescent plumage. Neoclassical contemporary illustration, tragic beauty aesthetic, golden-hour chiaroscuro, refined brushwork with digital precision, emotionally resonant and masterfully composed." )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · The Cyberpunk Lunge (Neon & Chrome)
prompts+=( "Extreme dutch angle, extreme foreshortening. A cyberpunk street-samurai lunging forward, her chrome cybernetic arm and glowing katana reaching directly into the camera lens, filling the immediate foreground and appearing massive. Her face and body recede dramatically into the background, compressed by the extreme perspective. The background is a tilted, neon-drenched rain-slicked alleyway in Kowloon. Anamorphic lens flare, rim lighting, high contrast cinematic lighting, dystopian aesthetic, photorealistic masterpiece." )

# 27 · The Fallen Valkyrie (Dark Fantasy & Chiaroscuro)
prompts+=( "Severe dutch angle, extreme foreshortening. A dark fantasy valkyrie plummeting downward through a stormy sky. Her armored boots and crossed legs are thrust directly toward the camera, dominating the lower foreground and appearing gigantic, while her face and upper body shrink into the distant background. Tattered raven wings spread out against a tilted backdrop of violent storm clouds. Volumetric lightning, chiaroscuro lighting, renaissance oil painting style mixed with epic cinematic fantasy, moody, atmospheric, highly aesthetic." )

# 28 · The Ethereal Dancer (Contemporary Art & Fabric)
prompts+=( "Tilted dutch angle, extreme foreshortening. An ethereal contemporary dancer suspended in mid-air within a minimalist, brutalist concrete room. One leg extends sharply toward the viewer, making the foot and calf monumental in the foreground, while her torso and trailing silk garments stretch away into the deep background. Soft diffused natural light from a high skylight, muted pastel color palette, poetic, ethereal, contemporary art photography, sharp focus on the foreground foot, beautiful depth of field." )

# 29 · The Avant-Garde Muse (High Fashion Editorial)
prompts+=( "Dramatic dutch angle, extreme foreshortening. An avant-garde fashion model in a sculptural, geometric haute couture dress. She is leaning drastically over the camera, her face hovering inches from the lens — her lips and eyes magnified and taking up the entire foreground. Her body and the sweeping architectural fabric of the dress extend backward and upward into sharp focus. Glossy studio lighting, Vogue editorial aesthetic, bold primary colors, striking composition, ultra-detailed textures." )

# 30 · The Clockwork Diver (Steampunk & Kinetic Action)
prompts+=( "Dynamic dutch angle, extreme foreshortening. A steampunk diver suspended in mid-air, reaching desperately toward the camera with a glowing brass mechanical hand. The mechanical hand and forearm are massive in the foreground, showcasing intricate gears, cogs, and scratches, forcing the rest of the diver's body to rapidly shrink into the background. Behind her, a tilted giant clock face and steam vents. Cinematic golden hour lighting, sepia and copper tones, epic action shot, ray-traced lighting, masterpiece." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · The Fallen Angel
prompts+=( "A fallen angel captured from an extreme low-angle Dutch tilt, foreshortened arm reaching directly toward the viewer with fingers splayed in dramatic perspective, tattered wings spiraling into the frame from above, baroque chiaroscuro lighting, oil painting texture with visible impasto brushstrokes, dark academia aesthetic, crimson and gold color palette, hyper-detailed feathers dissolving into golden dust, melancholic divine expression, Caravaggio meets contemporary digital art." )

# 32 · Neon Samurai
prompts+=( "Cyberpunk samurai in extreme foreshortening, katana blade thrust directly at the camera with distorted perspective from aggressive Dutch angle, rain-slicked Tokyo alleyway reflected in the steel, neon kanji signs bleeding purple and cyan light across wet surfaces, volumetric fog catching laser-like light rays, motion blur on the background suggesting kinetic energy, hyper-realistic skin texture with subtle subsurface scattering, blade edge showing micro-scratches and blood residue, film grain overlay, cinematic anamorphic lens distortion." )

# 33 · The Drowning Muse
prompts+=( "Underwater portrait with extreme foreshortening, woman's face tilted at a severe Dutch angle just breaking the water surface, one arm extended toward viewer in distorted perspective creating impossible depth, hair floating in zero-gravity spirals, light refracting through water creating caustic patterns on porcelain skin, Pre-Raphaelite beauty with contemporary surrealism, bubbles catching prismatic light, fabric draping in liquid silk folds, ethereal blue-green palette with sudden warm highlights, dreamlike soft focus transitioning to razor-sharp detail at focal point, fine art photography aesthetic." )

# 34 · Clockwork Ballerina
prompts+=( "Steampunk ballerina en pointe from extreme worm's-eye Dutch angle, one leg extended vertically into the frame with impossible foreshortening, brass clockwork mechanisms visible through translucent tulle skirt, gears and cogs catching warm Edison bulb light, motion blur on spinning pirouette, dust motes dancing in dramatic side-lighting, Art Nouveau decorative elements merging with industrial machinery, sepia and copper tones with sudden teal accents, hyper-detailed metal textures with patina and oil stains, ballet slipper ribbons wrapping dynamically through the composition, theatrical stage spotlight creating hard shadows." )

# 35 · The Last Astronaut
prompts+=( "Astronaut floating in deep space with extreme foreshortening, gloved hand reaching toward camera appearing enormous while body recedes into cosmic distance, helmet visor reflecting an entire dying galaxy, severe Dutch angle suggesting disorientation in zero gravity, Earth a fragile blue marble in the corner of the visor reflection, nebula clouds in iridescent purples and magentas, floating debris and ice crystals catching harsh rim lighting, spacesuit fabric showing every stitch and weathering detail, cinematic lens flare from an unseen sun, melancholic isolation, hyper-realistic NASA photography aesthetic merged with cosmic surrealism." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
