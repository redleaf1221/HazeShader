// atmosphere.glsl — a physically-motivated single-scattering haze (smog) model.
//
// The atmosphere is decomposed into the physically distinct phenomena that
// actually produce the "heavy haze" look, rather than hand-tuned constants:
//
//   * Beer-Lambert extinction: light is attenuated exponentially over
//     distance, which lowers visibility (the fog/aerial perspective).
//   * Wavelength-dependent extinction: blue/green light is extinct faster
//     than red, so the direct solar beam reddens as its path length (air
//     mass) grows. This is why a low or haze-veiled sun looks red/dim.
//   * Diffuse Rayleigh + aerosol scattering: a warm, near-isotropic haze
//     colour used both for the sky base and the airlight that distant
//     objects fade into.
//   * A forward-scattered aureole (sun glow) that is drawn ONLY on the sky,
//     never in the fog, so terrain correctly occludes the sun.
//
// All directions are unit vectors in WORLD space (+Y up). `haze` is a
// dimensionless aerosol density (0 = clear air, 1 = heavy smog).

// Solar and lunar spectral radiance. The moon is roughly a tenth of the sun's
// radiance, so moonlight keeps the night dark instead of floodlighting it;
// the moon disk itself is brightened separately in composite.fsh.
const vec3 SOLAR_SPECTRUM = vec3(1.00, 0.94, 0.86);
const vec3 MOON_SPECTRUM  = vec3(0.07, 0.09, 0.12);

// Per-block extinction coefficients (1/block).
// Rayleigh (molecular) is strongly wavelength dependent (blue extinct first);
// aerosol (Mie) is nearly flat but slightly blue-absorbing, as in smog.
const vec3 RAYLEIGH_EXTINCTION = vec3(0.004, 0.012, 0.036);
const vec3 AEROSOL_EXTINCTION  = vec3(0.040, 0.055, 0.090);

// Total extinction coefficient at a given aerosol density.
vec3 hazeExtinction(float haze) {
    return RAYLEIGH_EXTINCTION + AEROSOL_EXTINCTION * max(haze, 0.0);
}

// Relative optical air mass for an elevation given as the cosine of the
// zenith angle. Monotonic, smooth and finite at the horizon.
float airMass(float cosZenith) {
    float mu = clamp(cosZenith, 0.0, 1.0);
    return 1.0 / (mu + 0.025 * exp(-11.0 * mu));
}

// Beer-Lambert transmittance over `distance` blocks (per channel).
vec3 hazeTransmittance(float haze, float distance) {
    return exp(-hazeExtinction(haze) * max(distance, 0.0));
}

// Direct beam colour after travelling through the atmosphere: it both dims
// and reddens as the air mass grows (the red low sun).
vec3 directLight(vec3 spectrum, float haze, float cosZenith) {
    return spectrum * exp(-hazeExtinction(haze) * airMass(cosZenith));
}

// Henyey-Greenstein phase function (aerosol forward scattering).
float henyeyGreenstein(float mu, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * mu, 1.5);
}

// Diffuse haze: a warm, ISOTROPIC aerosol term plus a weak Rayleigh term.
// This is BOTH the base sky colour and the airlight (fog) colour. It is
// deliberately independent of the sun direction: the sun's directional effect
// on the scene comes from direct light (shadowed per-surface) and the
// sky-only aureole, so the fog never glows toward the sun when the sun is
// occluded by terrain — the haze reads as a uniform smog veil, not a screen
// smeared glow. Warm aerosol (red > blue) keeps it looking like smog.
vec3 hazeRadiance(vec3 V, float haze, vec3 lightColor) {
    float muView  = clamp(V.y, 0.0, 1.0);
    float pathLen = 1.0 / (muView + 0.05);

    vec3 betaR = vec3(0.05, 0.06, 0.09);                        // subtle blue
    vec3 betaM = vec3(0.18, 0.16, 0.13) * (0.30 + 0.90 * haze); // warm grey

    vec3 rayleigh = betaR * (1.0 - exp(-pathLen * 0.35));
    vec3 mie      = betaM * (1.0 - exp(-pathLen * (0.10 + 0.80 * haze)));

    return (rayleigh + mie) * lightColor;
}

// Forward-scattered aureole around the sun/moon. Drawn only on the sky so
// that terrain occludes it (and the disk) correctly.
vec3 sunGlow(vec3 V, vec3 L, float haze, vec3 lightColor) {
    float mu = clamp(dot(V, L), -1.0, 1.0);
    float miePhase = henyeyGreenstein(mu, 0.55);
    vec3 betaM = vec3(0.09, 0.08, 0.07) * (0.20 + 0.80 * haze);
    return betaM * miePhase * lightColor;
}

// Sky = diffuse haze + forward aureole (the crisp disk is added separately).
vec3 skyColor(vec3 V, vec3 sunDir, vec3 moonDir, float haze, float dayFactor, float nightFactor) {
    vec3 sunLight  = directLight(SOLAR_SPECTRUM, haze, sunDir.y)  * dayFactor;
    vec3 moonLight = directLight(MOON_SPECTRUM,  haze, moonDir.y) * nightFactor;
    return hazeRadiance(V, haze, sunLight)
         + sunGlow(V, sunDir, haze, sunLight)
         + hazeRadiance(V, haze, moonLight)
         + sunGlow(V, moonDir, haze, moonLight);
}

// Airlight for aerial perspective/fog: the diffuse haze only (no sun glow, no
// disk). Because a surface accumulates less airlight than the sky behind it,
// it ends up as a darker silhouette — and near the sun that silhouette sits
// against the brighter glow, i.e. the sun stays correctly occluded.
vec3 airlightColor(vec3 V, vec3 sunDir, vec3 moonDir, float haze, float dayFactor, float nightFactor) {
    vec3 sunLight  = directLight(SOLAR_SPECTRUM, haze, sunDir.y)  * dayFactor;
    vec3 moonLight = directLight(MOON_SPECTRUM,  haze, moonDir.y) * nightFactor;
    return hazeRadiance(V, haze, sunLight)
         + hazeRadiance(V, haze, moonLight);
}

// Diffuse ambient irradiance from the haze-filled sky (no direct sun glow),
// used for scene lighting. Haze scatters light in from every direction,
// raising ambient levels and washing out shadows.
vec3 ambientLight(vec3 sunDir, vec3 moonDir, float haze, float dayFactor, float nightFactor) {
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 sunLight  = directLight(SOLAR_SPECTRUM, haze, sunDir.y)  * dayFactor;
    vec3 moonLight = directLight(MOON_SPECTRUM,  haze, moonDir.y) * nightFactor;
    vec3 sky = hazeRadiance(up, haze, sunLight)
             + hazeRadiance(up, haze, moonLight);
    return sky * (0.9 + 1.3 * haze);
}
