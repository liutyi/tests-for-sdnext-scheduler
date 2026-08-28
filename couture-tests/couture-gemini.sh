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
# Source: https://wiki.liutyi.info/display/AI/Contemporary+Couture+from+Gemini
# 40 prompts — structured labeled fields assembled into single prompt strings.
# Quoted terms preserved verbatim (\"...\") as they appear in the source.
# ---------------------------------------------------------------------------
prompts=()

# 01 · Kyiv Neo-Ethno
prompts+=( "TITLE: Kyiv Neo-Ethno. SUBJECT: Ukrainian woman, Slavic features. BODY: Tall, athletic. CLOTHING: Oversized white linen blazer with deep-red cross-stitch embroidery on sleeves, tech-fabric trousers. POSE: Standing, looking at distance. CAMERA VIEW: Eye-level, medium shot. LIGHTING: Golden hour, soft. SCENE: Modern Kyiv street, brutalist concrete background. STYLE: Cinematic Realism. COLOR-TONE: Crisp whites, deep madder red." )

# 02 · Lagos Street Luxe
prompts+=( "TITLE: Lagos Street Luxe. SUBJECT: Nigerian man, deep mahogany skin. BODY: Lean, muscular. CLOTHING: Silk bomber jacket featuring vibrant Yoruba adire patterns, tailored black joggers. POSE: Leaning against a sleek car. CAMERA VIEW: Low angle, full body. LIGHTING: High-contrast sunlight. SCENE: Victoria Island skyline, modern glass buildings. STYLE: Editorial Fashion. COLOR-TONE: Indigo, charcoal, obsidian." )

# 03 · Andean Urbanist
prompts+=( "TITLE: Andean Urbanist. SUBJECT: Quechua woman, sun-kissed skin. BODY: Petite, strong. CLOTHING: Cropped wool jacket with neon-tinted geometric Intarsia knit, high-waist denim. POSE: Mid-stride walking. CAMERA VIEW: Side profile, wide shot. LIGHTING: Cool morning mist. SCENE: Cobbled street in Cusco with modern cafes. STYLE: Street Photography. COLOR-TONE: Earthy ochre, neon fuchsia." )

# 04 · Tokyo Kimono-Core
prompts+=( "TITLE: Tokyo Kimono-Core. SUBJECT: Japanese man, sharp features. BODY: Slender, graceful. CLOTHING: Technical rain-trench with a kimono-style wrap collar, minimalist obi-belt detail. POSE: Adjusting a smartwatch. CAMERA VIEW: Close-up, chest up. LIGHTING: Neon-diffused night light. SCENE: Shinjuku alleyway, wet pavement. STYLE: Cyber-Minimalism. COLOR-TONE: Slate gray, electric violet." )

# 05 · Sahara Nomad
prompts+=( "TITLE: Sahara Nomad. SUBJECT: Tuareg man, piercing eyes. BODY: Wiry, tall. CLOTHING: Indigo-dyed denim duster coat, silver Berber-engraved buttons, slim cargo pants. POSE: Hand on headwrap. CAMERA VIEW: Low angle, heroic. LIGHTING: Harsh desert noon shadows. SCENE: Modern solar farm in Morocco. STYLE: National Geographic Chic. COLOR-TONE: Cobalt blue, sand beige." )

# 06 · Mumbai Monsoon
prompts+=( "TITLE: Mumbai Monsoon. SUBJECT: Indian woman, almond eyes. BODY: Curvy, elegant. CLOTHING: Structured Nehru-collar vest in raw silk, gold zardosi piping, wide-leg linen pants. POSE: Holding a transparent umbrella. CAMERA VIEW: High angle, looking up. LIGHTING: Soft, overcast rain light. SCENE: Marine Drive, Mumbai sea-wall. STYLE: Moody Cinematic. COLOR-TONE: Teal, antique gold, gray." )

# 07 · Seoul Hanbok-Tech
prompts+=( "TITLE: Seoul Hanbok-Tech. SUBJECT: Korean man, monolid eyes. BODY: Lean, youthful. CLOTHING: Cropped jacket with jeogori-style ribbons, tech-mesh inserts, baggy tactical pants. POSE: Sitting on a neon bench. CAMERA VIEW: Three-quarter view. LIGHTING: Cyberpunk pink and blue. SCENE: Gangnam district at night. STYLE: K-Fashion Wave. COLOR-TONE: Pastel lavender, matte black." )

# 08 · Mexico City Mural
prompts+=( "TITLE: Mexico City Mural. SUBJECT: Mexican woman, mestizo features. BODY: Toned, expressive. CLOTHING: Leather biker jacket with intricate Huichol beadwork on lapels, pleated midi skirt. POSE: Confident power pose. CAMERA VIEW: Eye-level, wide shot. LIGHTING: Warm afternoon sun. SCENE: Contemporary art gallery courtyard. STYLE: Vibrant Realism. COLOR-TONE: Terracotta, turquoise, black." )

# 09 · Nordic Runes
prompts+=( "TITLE: Nordic Runes. SUBJECT: Swedish man, fair skin, blonde. BODY: Broad-shouldered. CLOTHING: Heavy knit sweater with subtle Viking knot-work textures, charcoal wool overcoat. POSE: Looking down at a phone. CAMERA VIEW: Medium shot, candid. LIGHTING: Flat, soft Nordic winter light. SCENE: Stockholm subway station. STYLE: Scandinavian Minimalist. COLOR-TONE: Cream, navy, steel." )

# 10 · Masai Modern
prompts+=( "TITLE: Masai Modern. SUBJECT: Kenyan woman, shaved head. BODY: Elegant, statuesque. CLOTHING: Red structural capelet, beaded choker integrated into collar, slim-fit black bodysuit. POSE: Standing tall, chin up. CAMERA VIEW: Low angle. LIGHTING: Sunset backlighting. SCENE: Modern Nairobi office balcony. STYLE: High-End Editorial. COLOR-TONE: Scarlet red, ebony, gold." )

# 11 · Amazonian Pulse
prompts+=( "TITLE: Amazonian Pulse. SUBJECT: Brazilian man, indigenous features. BODY: Athletic, tanned. CLOTHING: Utility vest with feather-patterned silk lining, recycled plastic sneakers. POSE: Crouched, looking at camera. CAMERA VIEW: Ground level, wide angle. LIGHTING: Dappled forest light. SCENE: Modern eco-resort in the jungle. STYLE: Sustainable Luxury. COLOR-TONE: Forest green, macaw orange." )

# 12 · Persian Pattern
prompts+=( "TITLE: Persian Pattern. SUBJECT: Iranian woman, dark wavy hair. BODY: Slender. CLOTHING: Long silk cardigan with paisley (Boteh) motifs, tailored white shirt, slim slacks. POSE: Tucking hair behind ear. CAMERA VIEW: Close-up portrait. LIGHTING: Soft window light. SCENE: Modern Tehran library. STYLE: Sophisticated Chic. COLOR-TONE: Rosewater pink, cream, gold." )

# 13 · Maori Edge
prompts+=( "TITLE: Maori Edge. SUBJECT: Maori man, facial moko details. BODY: Burly, powerful. CLOTHING: Black wool peacoat with tonal charcoal Ta moko embroidery on shoulders. POSE: Arms crossed. CAMERA VIEW: Eye-level, medium shot. LIGHTING: Dramatic chiaroscuro. SCENE: Auckland waterfront, metal docks. STYLE: Gritty Cinematic. COLOR-TONE: Monochrome, ink black." )

# 14 · Thai Silk Street
prompts+=( "TITLE: Thai Silk Street. SUBJECT: Thai woman, petite. BODY: Graceful. CLOTHING: One-shoulder modern top made of iridescent Thai silk, oversized trousers. POSE: Graceful turn. CAMERA VIEW: Dynamic movement shot. LIGHTING: Warm studio-style sun. SCENE: Bangkok \"Cloud 47\" rooftop. STYLE: Glamour Streetwear. COLOR-TONE: Magenta, copper, bronze." )

# 15 · Mongolian Steppe
prompts+=( "TITLE: Mongolian Steppe. SUBJECT: Mongolian man, high cheekbones. BODY: Robust. CLOTHING: Modern deelt-cut leather trench, fur-lined collar, heavy combat boots. POSE: Leaning on a metal railing. CAMERA VIEW: Profile shot. LIGHTING: Golden hour, side-lit. SCENE: Ulaanbaatar modern district. STYLE: Rugged Luxury. COLOR-TONE: Burnt sienna, dark chocolate." )

# 16 · Parisian Maghreb
prompts+=( "TITLE: Parisian Maghreb. SUBJECT: Algerian woman, curly hair. BODY: Slim, stylish. CLOTHING: Modern burnous-inspired hooded wool coat, gold filigree jewelry, denim. POSE: Walking through a crowd. CAMERA VIEW: Shallow depth of field. LIGHTING: Soft city twilight. SCENE: Parisian cafe terrace. STYLE: European Chic. COLOR-TONE: Emerald green, cream." )

# 17 · Tibetan High
prompts+=( "TITLE: Tibetan High. SUBJECT: Tibetan man, weathered skin. BODY: Lean. CLOTHING: Padded down jacket with traditional brocade panels, modern mountain boots. POSE: Looking at the sky. CAMERA VIEW: Wide shot, low angle. LIGHTING: Bright, thin mountain light. SCENE: Modern Lhasa architecture. STYLE: Adventure Fashion. COLOR-TONE: Saffron yellow, deep crimson." )

# 18 · Vietnamese Flow
prompts+=( "TITLE: Vietnamese Flow. SUBJECT: Vietnamese woman, straight hair. BODY: Delicate. CLOTHING: Modernized Ao Dai slit-top worn over flared jeans, silk embroidery. POSE: Biking on a scooter. CAMERA VIEW: Side profile, motion blur. LIGHTING: Mid-day bright light. SCENE: Ho Chi Minh city traffic. STYLE: Urban Vitality. COLOR-TONE: Lotus pink, denim blue." )

# 19 · Ethiopian Grace
prompts+=( "TITLE: Ethiopian Grace. SUBJECT: Ethiopian woman, habesha features. BODY: Tall, slim. CLOTHING: White cotton dress with Netela-style woven borders, modern leather sandals. POSE: Sitting gracefully. CAMERA VIEW: Eye-level, medium shot. LIGHTING: Warm, diffused interior light. SCENE: Addis Ababa modern lounge. STYLE: Ethnic Minimalist. COLOR-TONE: Off-white, vibrant borders." )

# 20 · Kazakh Nomad
prompts+=( "TITLE: Kazakh Nomad. SUBJECT: Kazakh man, central asian features. BODY: Athletic. CLOTHING: Suede bomber jacket with silver felted \"Koshkar-muiz\" patterns, dark jeans. POSE: Standing by a horse-statue. CAMERA VIEW: Three-quarter view. LIGHTING: Cold sunset. SCENE: Astana glass architecture. STYLE: Neo-Nomad. COLOR-TONE: Slate, silver, tan." )

# 21 · Scottish Highland
prompts+=( "TITLE: Scottish Highland. SUBJECT: Scottish man, red beard. BODY: Stocky. CLOTHING: Tailored blazer in modern grey tartan, utility kilt-shorts, heavy boots. POSE: Walking toward camera. CAMERA VIEW: Eye-level, full body. LIGHTING: Moody, overcast sky. SCENE: Edinburgh's Royal Mile. STYLE: Heritage Punk. COLOR-TONE: Heather purple, forest green." )

# 22 · Balinese Breeze
prompts+=( "TITLE: Balinese Breeze. SUBJECT: Balinese woman, tan skin. BODY: Lithe. CLOTHING: Batik-patterned silk wrap-around skirt, structured white corset top. POSE: Dancing pose. CAMERA VIEW: Low angle, dynamic. LIGHTING: Dappled sun through leaves. SCENE: Modern Bali villa garden. STYLE: Tropical Elegance. COLOR-TONE: Indigo, canary yellow." )

# 23 · Navajo Weaver
prompts+=( "TITLE: Navajo Weaver. SUBJECT: Native American man, long hair. BODY: Strong. CLOTHING: Modern denim jacket with woven southwestern geometric back panel, turquoise ring. POSE: Fixing a cufflink. CAMERA VIEW: Close-up on hands/torso. LIGHTING: Warm sunset. SCENE: Desert highway, modern truck. STYLE: Americana Neo-Trad. COLOR-TONE: Sand, turquoise, denim." )

# 24 · Abaya Evolution
prompts+=( "TITLE: Abaya Evolution. SUBJECT: Saudi woman, expressive eyes. BODY: Slender. CLOTHING: Open-style silk abaya with metallic embroidery, high-waist trousers, sneakers. POSE: Walking confidently. CAMERA VIEW: Wide shot, low angle. LIGHTING: Bright, harsh desert sun. SCENE: King Abdullah Financial District. STYLE: Futuristic Modest. COLOR-TONE: Sand gold, pearl white." )

# 25 · Greek Odyssey
prompts+=( "TITLE: Greek Odyssey. SUBJECT: Greek man, olive skin. BODY: Athletic. CLOTHING: Linen tunic-shirt with Greek key (meander) embroidery on hem, white chinos. POSE: Looking out to sea. CAMERA VIEW: Wide shot from behind. LIGHTING: Harsh midday sun. SCENE: Santorini blue-dome village. STYLE: Mediterranean Chic. COLOR-TONE: Aegean blue, crisp white." )

# 26 · Zulu Modernity
prompts+=( "TITLE: Zulu Modernity. SUBJECT: South African man, dark skin. BODY: Muscular. CLOTHING: Modern knit polo with geometric Zulu beadwork patterns, tailored shorts. POSE: Sitting on a concrete wall. CAMERA VIEW: Medium shot. LIGHTING: Vibrant afternoon sun. SCENE: Johannesburg Maboneng district. STYLE: Afro-Futurism. COLOR-TONE: Orange, black, yellow." )

# 27 · Inuit Tech
prompts+=( "TITLE: Inuit Tech. SUBJECT: Inuit woman, round face. BODY: Petite. CLOTHING: High-tech parka with traditional sealskin-inspired patterns, thermal leggings. POSE: Looking into the wind. CAMERA VIEW: Close-up, snowy lashes. LIGHTING: Cold blue hour light. SCENE: Modern arctic research station. STYLE: Technical Survival. COLOR-TONE: Ice blue, ivory, grey." )

# 28 · Egyptian Gold
prompts+=( "TITLE: Egyptian Gold. SUBJECT: Egyptian man, sharp jawline. BODY: Lean. CLOTHING: Black linen suit with gold ankh-inspired minimalist hardware, sunglasses. POSE: Walking down stairs. CAMERA VIEW: High angle. LIGHTING: Golden hour. SCENE: Cairo Grand Museum exterior. STYLE: Luxury Noir. COLOR-TONE: Obsidian, metallic gold." )

# 29 · Samoan Power
prompts+=( "TITLE: Samoan Power. SUBJECT: Samoan man, tattooed arms. BODY: Large, powerful. CLOTHING: Short-sleeve shirt with tribal \"tatau\" prints, cargo trousers, sandals. POSE: Standing, hands in pockets. CAMERA VIEW: Eye-level, full body. LIGHTING: Soft tropical twilight. SCENE: Modern Pacific resort. STYLE: Island Urban. COLOR-TONE: Brown, black, cream." )

# 30 · Philippine Piña
prompts+=( "TITLE: Philippine Piña. SUBJECT: Filipina woman, glowing skin. BODY: Slender. CLOTHING: Barong-inspired sheer organza jacket with floral embroidery, black bralette. POSE: Adjusting earrings. CAMERA VIEW: Close-up portrait. LIGHTING: Soft studio light. SCENE: Manila creative studio. STYLE: Ethereal Modern. COLOR-TONE: Translucent cream, black." )

# 31 · Romanian Folk
prompts+=( "TITLE: Romanian Folk. SUBJECT: Romanian woman, pale skin. BODY: Athletic. CLOTHING: Cropped leather vest over a blouse with traditional sleeve puff and black embroidery. POSE: Standing in a field. CAMERA VIEW: Wide shot. LIGHTING: Soft sunrise. SCENE: Modern wooden cabin. STYLE: Folk-Fusion. COLOR-TONE: Black, white, poppy red." )

# 32 · Caribbean Rhythm
prompts+=( "TITLE: Caribbean Rhythm. SUBJECT: Jamaican man, dreadlocks. BODY: Lean. CLOTHING: Vibrant linen shirt with \"madras\" check, tailored white trousers. POSE: Leaning against a wall. CAMERA VIEW: Medium shot, low angle. LIGHTING: Warm golden sunlight. SCENE: Kingston street art wall. STYLE: Reggae Sophisticate. COLOR-TONE: Red, gold, green." )

# 33 · Chinese Silk-Road
prompts+=( "TITLE: Chinese Silk-Road. SUBJECT: Chinese man, refined features. BODY: Slender. CLOTHING: Modern qipao-collar suit jacket, silk jacquard fabric, slim-fit trousers. POSE: Holding a tablet. CAMERA VIEW: Three-quarter view. LIGHTING: Cool office lighting. SCENE: Shanghai skyscraper office. STYLE: Corporate Orientalism. COLOR-TONE: Jade green, charcoal." )

# 34 · Finnish Frost
prompts+=( "TITLE: Finnish Frost. SUBJECT: Finnish woman, icy blue eyes. BODY: Tall, slender. CLOTHING: Heavy wool coat with Marimekko-style bold graphic prints, chunky scarf. POSE: Wrapped in a scarf. CAMERA VIEW: Close-up. LIGHTING: Overcast, snowy light. SCENE: Helsinki Design District. STYLE: Graphic Minimalism. COLOR-TONE: Black, white, bold red." )

# 35 · Turkish Velvet
prompts+=( "TITLE: Turkish Velvet. SUBJECT: Turkish woman, hazel eyes. BODY: Curvy. CLOTHING: Velvet blazer with Ottoman-style gold bullion embroidery, wide-leg silk pants. POSE: Sipping coffee. CAMERA VIEW: Eye-level, medium shot. LIGHTING: Warm cafe lighting. SCENE: Istanbul Galata rooftop. STYLE: Opulent Urban. COLOR-TONE: Deep burgundy, gold." )

# 36 · Australian Outback
prompts+=( "TITLE: Australian Outback. SUBJECT: Aboriginal man, dark skin. BODY: Wiry, strong. CLOTHING: Modern duster coat with subtle dot-art lining, wide-brim hat, denim. POSE: Looking at the horizon. CAMERA VIEW: Wide shot, profile. LIGHTING: Red sunset light. SCENE: Modern desert observatory. STYLE: Rugged Heritage. COLOR-TONE: Ochre, burnt orange." )

# 37 · Portuguese Azulejo
prompts+=( "TITLE: Portuguese Azulejo. SUBJECT: Portuguese woman, olive skin. BODY: Slim. CLOTHING: White denim jacket with blue tile-print (Azulejo) on the back, blue jeans. POSE: Looking over shoulder. CAMERA VIEW: Back-view, medium shot. LIGHTING: Soft coastal light. SCENE: Lisbon's Alfama district. STYLE: Mediterranean Pop. COLOR-TONE: Cobalt blue, white." )

# 38 · Jordanian Desert
prompts+=( "TITLE: Jordanian Desert. SUBJECT: Jordanian man, bearded. BODY: Tall. CLOTHING: Modernized Shemagh scarf worn as a cowl, technical windbreaker, black pants. POSE: Standing on a sand dune. CAMERA VIEW: Long shot. LIGHTING: Sunset silhouettes. SCENE: Wadi Rum modern camp. STYLE: Tech-Nomad. COLOR-TONE: Khaki, black, red." )

# 39 · Bolivian Bowler
prompts+=( "TITLE: Bolivian Bowler. SUBJECT: Aymara woman, braids. BODY: Short, strong. CLOTHING: Modern structural bolero jacket, tiered silk skirt, contemporary jewelry. POSE: Standing with hands on hips. CAMERA VIEW: Low angle. LIGHTING: Mid-day sun. SCENE: La Paz cable car station. STYLE: High-Altitude Chic. COLOR-TONE: Violet, emerald, gold." )

# 40 · Icelandic Lava
prompts+=( "TITLE: Icelandic Lava. SUBJECT: Icelandic man, rugged. BODY: Broad. CLOTHING: Lopapeysa-inspired modern fleece jacket, waterproof trousers, hiking boots. POSE: Standing on black sand. CAMERA VIEW: Wide shot. LIGHTING: Moody, dramatic grey sky. SCENE: Reynisfjara black sand beach. STYLE: Volcanic Technical. COLOR-TONE: Charcoal, ash grey, white." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

