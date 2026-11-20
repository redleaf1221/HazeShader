# Heavy Haze — an Iris shader pack

A shader pack that reproduces the visual character of heavy haze / smog in
Minecraft: a reddened, vanilla-style square sun; drastically reduced
visibility; and distant objects fading to nothing but silhouettes against a
bright, warm-grey airlight.

The pack is built from a **physical single-scattering model** rather than
hand-tuned "looks-like-haze" numbers. Every visible effect is an emergent
consequence of the same few optical laws.

## Installation

1. Copy the `haze-shaderpack` folder into `.minecraft/shaderpacks/`.
2. Launch Minecraft with [Iris](https://irisshaders.dev/) (or OptiFine/Oculus).
3. Select the pack in the shader selection screen.

## The physics (why it looks the way it does)

The whole atmosphere is described by two optical ingredients plus one geometry
fact:

- **Beer–Lambert extinction** — light is attenuated exponentially with
  distance: `T(d) = exp(-σ d)`. This lowers visibility and drives the fog.
- **Wavelength-dependent extinction** — the extinction coefficient σ is larger
  for blue/green light than for red (Rayleigh scattering + blue-absorbing
  aerosol). The direct solar beam therefore loses blue first and **reddens**
  as its path length through the atmosphere grows.
- **Rayleigh + Mie single scattering** — the sky and the "airlight" (the light
  scattered into your line of sight) share the same *diffuse* haze term, so
  the fog colour equals the sky colour away from the sun. The forward-scattered
  sun aureole and the sun disk are added **only on the sky**, so terrain keeps
  correctly occluding the sun.

The headline effects follow directly:

| Effect you see | Physical cause in the pack |
| --- | --- |
| Square, reddening sun | The sun is a sky-space square (`squareBody()` in `composite.fsh`), measured in elevation × azimuth around its world direction, so it stays fixed in the sky. Its colour is `directLight()` — wavelength-dependent extinction over the air mass — so a low or haze-veiled sun dims and reddens. |
| Visibility drops | `hazeTransmittance()` attenuates every surface by `exp(-σ · distance)`. |
| Distant objects become silhouettes | A surface is rendered as `albedo·T(d) + airlight·(1−T(d))` with the *diffuse* airlight. It accumulates *less* airlight than the sky behind it, so it ends up darker than the background — a silhouette, and near the sun a dark silhouette against the glow. No special-case code. |
| Warm-grey sky, soft shadows | Haze raises the warm aerosol (Mie) scattering term and the ambient irradiance while dimming the direct beam, washing out contrast and desaturating the scene. |

## Options

- **HAZE_DENSITY** (slider, default 1.0) — dimensionless aerosol density.
  1.0 is heavy smog; 2.0 is nearly opaque. Set it low to see a mild haze.
- **HAZE_WEATHER** (on by default) — rain and thunderstorms add to the haze
  density, so bad weather gets visibly hazier.

## Tuning

The physically meaningful knobs live in `shaders/lib/atmosphere.glsl`:

- `AEROSOL_EXTINCTION` — how fast haze attenuates light (visibility).
- `RAYLEIGH_EXTINCTION` — the blue bias that reddens the low sun.
- `betaR` / `betaM` inside `hazeRadiance()` — sky/airlight brightness.
- `SUN_SQUARE_HALF` (in `composite.fsh`) and the disk intensity `2.5` — square
  sun size and brightness (sky-space, world-aligned).

The red sun is most dramatic with a low sun plus dense haze (try
`/time set 11000` or morning/evening, and raise HAZE_DENSITY or summon rain).

## Notes / limitations

- The End and Nether are not specially handled; the pack targets the Overworld.
- Vanilla clouds, stars, sun and moon textures are disabled (`shaders.properties`)
  and redrawn by the composite pass.
- The model is single-scattering, so twilight is a smooth day/night blend
  rather than a physically exact multi-scattering sunset.
- Distant Horizons is supported: DH LODs render through `dh_terrain`/`dh_water`
  and are fogged through `dhDepthTex0`; the DH shadow pass is disabled
  (`dhShadow.enabled=false`) since distant shadows are invisible in haze.
