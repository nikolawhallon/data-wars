shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// replacement palette
uniform vec3 pal0 : source_color = vec3(0.1725, 0.1294, 0.2157); // #2c2137
uniform vec3 pal1 : source_color = vec3(0.4627, 0.2667, 0.3843); // #764462
uniform vec3 pal2 : source_color = vec3(0.6627, 0.4078, 0.4078); // #a96868
uniform vec3 pal3 : source_color = vec3(0.9294, 0.7059, 0.6314); // #edb4a1

// original palette
const vec3 src0 = vec3(0.1725, 0.1294, 0.2157); // #2c2137
const vec3 src1 = vec3(0.4627, 0.2667, 0.3843); // #764462
const vec3 src2 = vec3(0.6627, 0.4078, 0.4078); // #a96868
const vec3 src3 = vec3(0.9294, 0.7059, 0.6314); // #edb4a1

bool same(vec3 a, vec3 b){
    return distance(a, b) < 0.01;
}

void fragment(){
    vec4 c = texture(screen_texture, SCREEN_UV);

    if (same(c.rgb, src0)) {
        c.rgb = pal0;
    } else if (same(c.rgb, src1)) {
        c.rgb = pal1;
    } else if (same(c.rgb, src2)) {
        c.rgb = pal2;
    } else if (same(c.rgb, src3)) {
        c.rgb = pal3;
    }

    COLOR = c;
}