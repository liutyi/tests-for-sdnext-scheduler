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
# Source: https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v3
# Structure: 9 rows (themes) × 4 columns (A–D, escalating complexity) = 36 prompts
# Queued row-by-row: 1A 1B 1C 1D / 2A 2B … / 9A 9B 9C 9D
# Quotes inside prompts are preserved verbatim (\" for double, ' for single).
# Panel numbering in 7D (1,2,4,6) preserved as-is from source.
# ---------------------------------------------------------------------------
prompts=()

# ── Row 1 · Portraits ───────────────────────────────────────────────────────

# 1A
prompts+=( "A close-up photograph focuses on a nice young woman left ear, featuring a multi-layered gold drop earring. The earring has two chains of different lengths with three cubic zirconia-studded flower clusters connected by thin chains and small gold beads. The person has blonde hair, light skin, and is looking slightly downwards with their head tilted to the right. A hand with neatly manicured nails rests near the hair. The setting is an indoor studio with a soft, warm light and a neutral, textured background." )

# 1B
prompts+=( "A woman wearing a dress is laying in grass." )

# 1C
prompts+=( "Close-up portrait of a mysterious and elegant black woman wearing a large wide-brimmed black hat that obscures her eyes, casting a deep shadow over the upper half of her face. She has dark brown skin, dark glossy lips, and is wearing a black off-the-shoulder top that exposes her bare shoulder. Her hand, with dark nail polish, gently touches the rim of the hat. Dramatic low-key lighting with a spotlight from the side creates high contrast between light and shadow (chiaroscuro), highlighting her cheek, lips, and shoulder against a dark, moody background. Cinematic noir style, fashion photography aesthetic, 8k resolution, highly detailed." )

# 1D
prompts+=( "A dark-toned portrait photograph. The horizontal widescreen composition is highly dramatic and artistic, with at least 80% of the area being pure negative space from deep graphite to absolute black, pooling thickly on the left side and center of the frame. The far right edge reveals a close-up profile of a young Polish woman in her late twenties, facing left - only the clean line of her profile, the pale curve of her ear, and a loose strand of ash-blonde hair escaping from a bun are visible. Her expression is one of concentrated analysis, as though measuring something invisible. She holds a traditional drafting compass, its metal handle rising from her grip, the two legs closed together so that the fine brass pivot point rests lightly at the corner of her mouth where lip meets skin. Her fingers hold it the way a conductor holds a baton. Studio low-key lighting with refined edge illumination traces her brow, the sharp ridge of her nose, the compressed line of her lips, and the geometric cold glint of the brass instrument, while the unlit side of her face and hand dissolve entirely into the black. The mood is precise, architectural, and quietly formidable." )

# ── Row 2 · Body Part ───────────────────────────────────────────────────────

# 2A
prompts+=( "A woman's hand reaching toward the camera in extreme close-up foreshortening, neatly manicured nails, fingertips razor-sharp and enormous in the foreground while the wrist and arm taper into soft creamy distance, crushed white background, dutch angle 18°, skin texture lit by a single cold silver sidelight, delicate ring on ring finger catching specular highlights, fine art wedding photography, shot on large format film, grain texture, high key." )

# 2B
prompts+=( "Close-up profile view of a woman with dark skin holding a piece of dark chocolate in her mouth by her teeth. Her lips are coated in high-gloss taupe lipstick, appearing very shiny and moist. Her nail polish is matte taupe. Her white upper teeth are visible. The background is plain white. High-resolution commercial photography, studio lighting, macro shot focusing on texture and detail." )

# 2C
prompts+=( "A low-angle, close-up photograph capturing the lower half of a Black woman walking carefully and barefoot along a single, polished steel railway rail, centered in the frame. Her dark-skinned feet are poised on the narrow top of the rail. She is wearing a white pen dress. In hand (on the right side of the frame), she is holding a pair of vibrant, glossy red patent leather high-heeled stiletto pumps, dangling by their heels. The railway track is set among textured ballast (gravel), old wooden sleepers, and scattered dry autumn leaves. The background is a soft, natural bokeh of green foliage and trees in diffuse natural light. The focus is sharp on the feet, rail." )

# 2D
prompts+=( "A beautiful Japanese women seating on an bar bench, crossed legs in high heel sandals. Looking at the camera, expressionless. Camera angle low angle Point of view from the ground. Focus on toes. Foreshortening." )

# ── Row 3 · Nature ──────────────────────────────────────────────────────────

# 3A
prompts+=( "Sacura blossom branch on the right 25%, minimalism, blurred mountains and ocean with small fisher boats far away from a coast, on a still water surface, golden hour lighting." )

# 3B
prompts+=( "Beautiful nature scenery." )


# 3C
prompts+=( "Single Boat on Calm Sea. A small wooden fishing boat floating alone in the lower right corner of the frame on a perfectly still, mirror-like ocean that fills most of the image with subtle reflections and gentle gradients of deep blue to turquoise, vast open water creating powerful negative space, minimalist seascape, serene and contemplative mood, soft diffused daylight, highly detailed yet simple, photorealistic, square composition with incredible breathing room." )

# 3D
prompts+=( "A conceptual negative space image. A solid, pitch-black canvas. From the top, thin, elegant beams of ethereal white light pierce downward, forming the \"gaps\" between invisible trees. The shapes of the trunks are created purely by the absence of light. Atmospheric fog, mystical mood, sharp transitions between light and shadow." )

# ── Row 4 · City ────────────────────────────────────────────────────────────

# 4A
prompts+=( "Small town street with gas station, cafe with tables outside, couple of cars and next big city cityscape on the horizon." )

# 4B
prompts+=( "Authentic 1970s Kodachrome street photography: a young stylish Caucasian woman in wide bell-bottom jeans and a patterned blouse walks past a record store named \"Music\" (name written in a glass in the center) with \"The Rolling Stones - Sticky Fingers\", \"Bee Gees - Cucumber Castle\", \"The Beatles - Abbey Road\" and \"Led Zeppelin - Led Zeppelin II\", and other albums in the window. Film grain, slightly faded warm color shift, 1971, New York City, slice of life documentary. On the photo bent upper left corner handwritten text \"1971 N.Y.\"" )

# 4C
 prompts+=( "A photorealistic liminal space of a vintage gas station isolated in a thick, heavy midnight fog. The only light source is the glowing white canopy and a single buzzing neon sign. The surrounding environment is pitch black. Volumetric lighting catching the mist, hyper-realistic asphalt texture with puddles, cinematic bokeh, eerie loneliness." )

# 4D
prompts+=( "A sparse cityscape suggested by the absolute minimum of scratched lines in black paint revealing warm brass beneath, sgraffito on metal, only the essential strokes needed to imply a skyline - a few vertical towers, window grids, a horizon line, negative space doing most of the work, vast areas of unscratched matte black dominating the composition, the city reads from near-emptiness, economy of mark, each scratch deliberate and load-bearing, architectural shorthand, no fill no shading no texture beyond the bare structural lines, wide horizontal composition, the scratches feel like a draftsman's first skeleton pass never completed, warm antique gold lines on deep black, desktop wallpaper." )

# ── Row 5 · Art Styles ──────────────────────────────────────────────────────

# 5A
prompts+=( "Watercolor ink painting. Woman holding umbrella. Rain. City. Taxi. Neon lights." )

# 5B
prompts+=( "Pixel art. Beautiful young woman in a light dress sitting in the cafe of coastal city, drinking wine and watching sunset. Solo." )

# 5C
 prompts+=( "Triple exposure of a teenage girl's side profile silhouette as the containing form, second layer an elevated motorway overpass shot at blue hour - headlight and taillight trails of opposing traffic streams bisecting the face in warm red and cool white arcs, asphalt texture mapping onto the skin of her neck and jaw, third layer a suburban living room interior at evening - television glow, low bookshelf, and a half-open door projecting soft domestic amber into the skull cavity, the two light sources of layers two and three - road and room - engaged in a precise chromatic tension within the portrait, neither resolving, the profile silhouette holding both realities without choosing between them, hair dissolving into the dark periphery of a motorway shoulder at night, palette of television amber, headlight white, taillight red, and deep suburban shadow, the in-between rendered as portraiture, Fujifilm GFX 50SII, 110mm f/2, blue hour, Provia simulation, fine art coming-of-age photography, Huis Marseille exhibition quality." )

# 5D
prompts+=( "Abstract art in gold and black colors." )

# ── Row 6 · Illustration ────────────────────────────────────────────────────

# 6A
prompts+=( "A detailed illustration and watercolor painting of a red-crowned crane standing gracefully in shallow water, rendered in a style blending traditional Japanese ukiyo-e woodblock printing and gold-leaf lacquer techniques. The crane, depicted in crisp whites, deep blacks, and accents of vermilion and brushed gold along its wings, is shown in profile facing left. It is set against a tranquil marsh landscape with distant reeds and a fading horizon, composed of layered washes of muted indigo, soft ash gray, and pale ivory. The composition is framed by tall lotus stems and seed pods arching from the right, with scattered gold-leaf textures applied to ripples in the water and subtle cloud forms above. The palette is restrained to black, white, red, gold, and cool gray tones, with fine ink-line detailing and visible paper grain." )

# 6B
prompts+=( "256 colors 32px pixel-art diskette icon." )

# 6C
prompts+=( "Samurai, sunset, silhouette, dramatic lighting, wind, dynamic pose, dynamic angle." )

# 6D
prompts+=( "A surreal noir masterpiece. A woman sits on a skyscraper ledge overlooking a dark, stylized city. Her wings are made of liquid black ink that drips upward toward the moon like smoke. Her eyes are a piercing, supernatural glowing cyan. Extremely high contrast, dramatic chiaroscuro, graphic novel illustration style, moody and ethereal." )


# ── Row 7 · Anime / Comics / Poster ─────────────────────────────────────────

# 7A
prompts+=( "Doodle of a cat peeking out from behind a corner. Cat speech bubble reads \"Need food\"." )

# 7B

prompts+=( "Charming, aesthetically pleasing photo info-graphic poster for a small cafe. In the center is a clear glass mug split vertically down the middle by a thin, dotted line. Left Side (LATTE): The glass is filled mostly with creamy, light-brown steamed milk, topped with a thin layer of microfoam and simple, elegant latte art. Right Side (CAPPUCCINO): The glass has distinct layers: a dark-espresso base, a generous layer of steamed milk, and a thick, airy head of frothy milk foam, topped with a sprinkle of cocoa powder. The entire poster has a soft and warm texture. Printed on hand made paper. Above the glass, the title \"LATTE vs. CAPPUCCINO\" is written in modern script. On either side of the split glass, three numbered points are listed. Left (Latte): More Steamed Milk, Milder & Smoother, Small Layer of Foam. Right (Cappuccino): Balanced Milk/Foam, Richer Espresso, Thicker Frothy Cap. The background is a soft cream color, decorated with subtle coffee beans and floral motifs. The poster has a rustic, cozy feel, framed by a delicate line border. At the very bottom, \"Nerd Cafe\" is subtly written." )

# 7C
prompts+=( "A vertically arranged 4-panel comic page in a cinematic, semi-realistic comic book illustration style, clean line art with rich colors and dramatic lighting, Star Wars prequel aesthetic mixed with modern meme humor. Panel 1 (top left): Anakin sitting in a sunny green meadow full of wildflowers. Looking slightly concerned toward the right. A speech bubble says: \"We need to build more Data Centers. AI needs it.\" Panel 2 (top right): face only close-up of Padmé smiling brightly and happily in the meadow, looking excited. Her speech bubble says: \"To cure cancer, right?\" Panel 3 (bottom left): face only close-up of Anakin with a skeptical, slightly annoyed expression, one eyebrow raised, looking toward the right, meadow background. Panel 4 (bottom right): A slightly pulled-back medium shot of Padmé standing in the meadow, now with a much more voluptuous figure, looking at the viewer with a mix of confusion and pleading expression. The composition shows her from the waist up in the field. A speech bubble says: \"We are curing cancer, right?\" Layout: Clean 2x2 grid comic page layout with thin white borders between panels, subtle drop shadows on panels, overall warm golden hour lighting, high detail, vibrant colors, professional comic book style, sharp focus, quality illustration. Star Wars Episode II characters: Padmé Amidala is 24 years old. Her hair styled in the classic side buns covered with intricate gold hair nets (snoods) and wears a green headband adorned with small pink flower knitting her forehead above her eyebrows. She is wearing a revealing off-shoulder beige floral dress with deep cleavage. She has brown eyes. Anakin Skywalker is 19 years old. He has short, swept-back dirty blonde hair with a distinctive long, thin braided lock hanging down past his right shoulder. He is wearing brown Jedi tunic robes layered under a dark blue, sleeveless vest. He has piercing blue eyes." )

# 7D
prompts+=( "A charming isometric 45° top-down miniature 3D cartoon scene of Oslo during a bright spring day, presented as a clean, whimsical diorama under a clear blue sky with soft white clouds. Feature its most iconic landmarks: the unique, wave-like Oslo Opera House by the water, the fortress of Akershus Fortress overlooking the harbor, the Holmenkollen Ski Jump standing tall on the distant hills, and the intricate buildings of the Aker Brygge waterfront. Use soft, refined PBR textures with gentle realistic materials: natural wood cladding and glass on the Opera House, weathered stone and aged metal on the fortress, and polished metal and glass on modern buildings. Apply lifelike yet soft daytime lighting and shadows, golden spring sunlight from the south-east casting gentle highlights and long soft shadows. Integrate current weather: clear sunny skies, crisp spring air. Keep the composition clean and minimalistic with a soft solid pastel blue background. At the top-center, place the title 'Oslo' in large bold modern sans-serif font, a prominent sunny weather icon beneath it, then the date 'May 9, 2026' in small elegant text and temperature '15°C' in medium-sized text below. All text centered with balanced spacing, subtly overlapping the tops of the tallest buildings without obscuring landmarks. Square resolution, high detail, cute yet sophisticated miniature style, vibrant spring colors and harmonious daylight lighting." )

# ── Row 8 · Macro ───────────────────────────────────────────────────────────

# 8A
prompts+=( "Water drop hanging on a leaf tip reflecting the cityscape." )

# 8B
prompts+=( "Tilt shift photo of busy city street from the office window. Makes real world appear tiny." )

# 8C
prompts+=( "The Explorer of the Ink Ocean. A black ink spill spreads across a sketchbook page, becoming a vast ocean where a miniature explorer sails a tiny paper boat. Ink waves curl like storm clouds while reflections of desk light shimmer across the liquid surface. Surreal macro realism with dramatic lighting and fluid motion frozen in time." )

# 8D
prompts+=( "Depict a tiny fairy near the fire at the end of match in a macro, shallow-focus scene. The fairy is heating her hands on a fire. She appears fragile and doll-like, with a large head and soft translucent wings. Woman's fingers holding the match has black nail polish. Lighting is intimate and diffused. Snow on the background dissolving into blur. Still, tender, and quietly whimsical." )

# ── Row 9 · Complex Prompts ─────────────────────────────────────────────────

# 9A
prompts+=( "A digital art illustration with a strong visual impact. The image employs extreme foreshortening, with a very low and forward-extending perspective. The central element is a gigantic hand with dark red pearl nail polish reaching out to the viewer, occupying most of the central space. The fingers, due to perspective, appear unusually thick and converge towards the camera. This hand holds a large, backlit yellow plastic lightning bolt symbol '⚡'. This lightning bolt symbol is the most prominent object in the image; it has a translucent texture and emits a dazzling bright yellow light from within, creating a strong backlighting effect. Light penetrates the outline of the fingers, causing the details of the hand to be obscured by the translucent light and shadow. Behind the hand, the outline of a Caucasian woman's face (with short red hair) is vaguely visible, half-obscured by the lightning bolt symbol; only a slightly blurred profile and slightly parted lips are visible. She is gazing forward. The background is a deep, dark gray with subtle noise, which accentuates the brightness of the yellow lightning bolt symbol. The overall color scheme is dominated by bright yellow and deep, subdued colors, with extremely strong light and shadow contrasts, creating a surreal, urgent, and energetic atmosphere. The composition is compact and full of tension." )

# 9B
prompts+=( "A dynamic sculpture of a dancing figure made from wide golden-yellow ribbons, the ribbons wrap and swirl around forming a human silhouette in a graceful dance pose with arms outstretched. The ribbons have the text 'LIUTYI TEST V3' printed repeatedly along their length in bold black letters. The ribbons are approximately 2-3 inches wide, creating intentional gaps and holes in the silhouette, revealing empty space inside. The figure appears to be mid-twirl with ribbons flowing outward dramatically. Dark gradient background, professional studio lighting with dramatic side lighting highlighting the golden ribbons. Photorealistic style, high detail, elegant and ethereal atmosphere." )

# 9C
prompts+=( "A silhouette of a woman standing perfectly still as an entire collapsing city spirals around her in slow rotation. The city fractures into surreal districts: a marketplace suspended upside-down where merchants sell bottled shadows, a bathhouse carved into a glacier with steam freezing mid-air, a rooftop zoo where caged animals are made of smoke, a hospital ward where the beds are boats drifting down white hallways, a music conservatory where instruments play themselves in an empty auditorium, a cinema where the screen shows the audience watching themselves, a florist shop overgrown into a forest consuming its own walls, a clock tower where time spills out like water, and a grand ballroom with a floor made of reflective black water beneath a chandelier of frozen flame. The woman is the only still point in the chaos, her silhouette centered and grounded. The lighting is ghostly pale blue and deep crimson, baroque and melancholic." )

# 9D
prompts+=( "Dark ceramic mug of hot tea steaming on a rustic wooden table by a window. Rain streams down the window pane with thick water droplets and vertical rivulets. Cozy interior contrasted with rainy evening outside. An empty wooden chair sits to the left of the table. A lit candle in a brass holder rests on the right side of the table. Blurred orange and yellow evening city lights outside the window that create bokeh effects. NO actual face, NO actual silhouette. NO horizontal lines. Just a (pareidolia) effect of some seems to be random phenomena coincidentally align to form a subtle outline is looks closely it resemble distorted woman face profile. Subtle and partially and extremely low contrast woman face outlines without solid lines or steam shadowing on glass created only by: illusion of hair - subtle curved mostly vertical thin rivulets, illusion of nose - one side of steam curls from mug, that widens with a height. illusion of forehead - by branch of tree. illusion of lips - Red car taillights. illusion of eye - street blue neon signs. No force shadowing of subtle silhouette outline. All lightning or shadow are related to real items no silhouette illusion. Moody atmospheric lighting, filmic grain, cinematic composition, melancholic mood." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
 
