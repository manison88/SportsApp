#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Witness shader effects. Every effect has a static SwiftUI fallback in FX.swift,
// toggled by FX.shadersEnabled (launch with -noShaders to force fallbacks).
// SwiftUI passes premultiplied colors; every function keeps that contract.

static float witnessHash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// Film grain field. Ignores the incoming color and emits gray noise meant to be
// composited with an overlay blend mode. `frame` changes the grain pattern;
// pass a constant for stills, a frame counter for live grain.
[[ stitchable ]] half4 filmGrain(float2 position, half4 color, float frame, float intensity) {
    float2 cell = floor(position * 0.75);
    float n = witnessHash(cell + float2(frame * 17.0, frame * 31.0));
    float a = intensity;
    return half4(half(n * a), half(n * a), half(n * a), half(a));
}

// Holographic foil for passport stamps. `tilt` is device attitude in -1...1,
// `size` the view size in points, `strength` 0...1.
[[ stitchable ]] half4 holoFoil(float2 position, half4 color, float2 size, float2 tilt, float strength) {
    float alpha = float(color.a);
    if (alpha < 0.001) { return color; }
    float3 base = float3(color.rgb) / alpha;
    float2 uv = position / max(size, float2(1.0));
    float band = dot(uv, float2(0.8, 0.6)) * 2.6 + tilt.x * 1.4 + tilt.y * 0.9;
    float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (band + float3(0.0, 0.33, 0.67)));
    float lum = dot(base, float3(0.299, 0.587, 0.114));
    float sheenPos = fract(band * 0.5);
    float sheen = pow(max(0.0, 1.0 - abs(sheenPos - 0.5) * 3.2), 4.0);
    float3 foil = mix(base, rainbow * (0.55 + 0.45 * lum), strength * (0.35 + 0.65 * lum));
    foil += sheen * 0.45 * strength;
    foil = clamp(foil, 0.0, 1.0);
    return half4(half3(foil * alpha), color.a);
}

// A soft diagonal band of light sweeping across content (welcome screen,
// share cards). `progress` runs 0...1 across the view.
[[ stitchable ]] half4 lightSweep(float2 position, half4 color, float2 size, float progress, float strength) {
    float2 uv = position / max(size, float2(1.0));
    float x = uv.x - uv.y * 0.35;
    float d = x - (progress * 1.7 - 0.35);
    float glow = exp(-d * d * 90.0) * strength;
    float3 rgb = float3(color.rgb) + float3(glow) * float(color.a);
    return half4(half3(rgb), color.a);
}

// Atmospheric halo around a circular object (the life globe). Emits light only
// outside `radius`, falling off over `falloff` points. Use with a screen blend.
[[ stitchable ]] half4 atmosphere(float2 position, half4 color, float2 center, float radius, float falloff, half4 tint) {
    float d = distance(position, center);
    float t = clamp((d - radius) / falloff, 0.0, 1.0);
    float inner = smoothstep(radius - 6.0, radius + 2.0, d);
    float glow = pow(1.0 - t, 2.4) * inner;
    return tint * half(glow);
}
