shader_type canvas_item;

uniform sampler2D smoke_texture : repeat_enable;

// Kecepatan scroll ke atas
uniform float scroll_speed = 0.5;

// Lebar trapesium
uniform float bottom_width : hint_range(0.05, 0.6) = 0.25;
uniform float top_width    : hint_range(0.5, 2.0)  = 1.2;

// Kontrol keruncingan (semakin besar = semakin runcing ke bawah)
uniform float taper_power : hint_range(1.0, 4.0) = 2.5;

// Fade atas & bawah
uniform float fade_top    : hint_range(0.0, 0.5) = 0.2;
uniform float fade_bottom : hint_range(0.0, 0.5) = 0.25;

// Intensitas goyangan horizontal (api / asap hidup)
uniform float sway_strength : hint_range(0.0, 0.05) = 0.02;
uniform float sway_speed = 2.0;

void fragment() {

    /* ===============================
       1. BENTUK TRAPESIUM (MENGERUCUT)
       =============================== */
    float curve = pow(UV.y, taper_power);
    float current_width = mix(top_width, bottom_width, curve);

    vec2 distorted_uv = UV;
    distorted_uv.x = (distorted_uv.x - 0.5) / current_width + 0.5;

    /* ===============================
       2. GOYANGAN HORIZONTAL (API)
       =============================== */
    distorted_uv.x += sin(UV.y * 10.0 + TIME * sway_speed) * sway_strength;

    /* ===============================
       3. SCROLL TEKSTUR KE ATAS
       =============================== */
    vec2 scrolling_uv = distorted_uv;
    scrolling_uv.y += TIME * scroll_speed;

    /* ===============================
       4. AMBIL WARNA TEKSTUR
       =============================== */
    vec4 color = texture(smoke_texture, scrolling_uv);

    /* ===============================
       5. FADE ATAS & BAWAH
       =============================== */
    float fade_mask =
        smoothstep(0.0, fade_top, UV.y) *
        smoothstep(1.0, 1.0 - fade_bottom, UV.y);

    color.a *= fade_mask;

    /* ===============================
       6. MASK SAMPING (BUANG LUAR TRAPESIUM)
       =============================== */
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0) {
        color.a = 0.0;
    }

    COLOR = color;
}
