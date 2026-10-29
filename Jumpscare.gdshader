shader_type canvas_item;

uniform float strength = 2.0; // Seberapa jauh getarnya (pixel)
uniform float speed = 20.0;   // Seberapa cepat getarnya

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Bikin offset acak berdasarkan waktu
    // floor(TIME * speed) bikin getarannya "patah-patah" khas horror
    vec2 shake = vec2(
        random(vec2(floor(TIME * speed), 0.0)) - 0.5,
        random(vec2(0.0, floor(TIME * speed))) - 0.5
    ) * strength * TEXTURE_PIXEL_SIZE;

    // Masukkan offset ke UV gambar
    vec4 color = texture(TEXTURE, UV + shake);
    COLOR = color;
}