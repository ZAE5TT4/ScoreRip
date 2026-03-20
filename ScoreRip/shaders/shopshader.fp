void main()
{
    vec2 uv = TexCoord;
    vec2 center = vec2(0.5, 0.5);
    vec2 fromCenter = uv - center;
    float dist = length(fromCenter);

    vec3 base = texture(InputTexture, uv).rgb;
    vec3 color = base;

    // При открытии — сразу 1.0. При закрытии — плавно убывает.
    float intensity = 0.0;
    if (shopOpen > 0)
    {
        intensity = 1.0;
    }
    else if (shopCounter > 0)
    {
        intensity = clamp(float(shopCounter) / 18.0, 0.0, 1.0);
    }

    if (intensity > 0.0)
    {
        // Виньетка по краям
        float vignette = smoothstep(0.30, 0.90, dist);
        color *= mix(1.0, 0.50, vignette * intensity);

        // Тёмно-красное свечение по краям
        float rim = pow(smoothstep(0.45, 0.97, dist), 1.5);
        color += vec3(0.15, 0.01, 0.01) * rim * intensity;

        // Общее затемнение
        color *= mix(1.0, 0.75, intensity);

        // Обесцвечивание фона
        float gray = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(color, vec3(gray) * vec3(0.86, 0.86, 0.90), intensity * 0.38);
    }

    color = clamp(color, 0.0, 1.0);
    FragColor = vec4(color, 1.0);
}
