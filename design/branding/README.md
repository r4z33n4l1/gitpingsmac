# GitPings app icon

The production icon uses the **Pull Pulse** direction: a minimal pull-request
branch whose active node emits a compact status signal. The mark is intentionally
simple enough to survive macOS's 16 px icon size and avoids GitHub/Octocat
trademark imagery.

The 1024 px transparent master is `gitpings-app-icon-master.png`. The PNGs in
`GitPings/Resources/Assets.xcassets/AppIcon.appiconset/` are generated from that
master at the complete set of macOS 1x and 2x sizes.

## Generation prompt

Generated with the built-in image generation tool on 2026-08-09.

```text
Use case: logo-brand
Asset type: macOS application icon and menu-bar brand reference
Primary request: Create an original icon for a native macOS utility that monitors pull-request status and sends pings. Concept B, “Pull Pulse”: one continuous heavy line forms a minimal pull-request branch—two circular nodes connected by a clean right-angle branch—while a compact three-line pulse/radar signal emerges from the upper node. It should communicate pull request plus ambient status notification instantly, without copying any GitHub or Octocat imagery.
Scene/backdrop: one centered macOS-style rounded-square icon on a plain neutral presentation background
Style/medium: crisp flat vector-like symbol, compact Swiss graphic design, restrained premium macOS utility aesthetic
Composition/framing: strong asymmetric but balanced silhouette; very thick consistent strokes; generous padding; optimized for recognition at 16–32 pixels; only 3–5 major shapes
Color palette: warm pale stone rounded-square tile, near-black branch symbol, single vivid vermilion status node; no additional colors
Materials/textures: perfectly matte flat fills, no gloss, no depth effects
Constraints: one icon only; no words, letters, numbers, code, octopus, cat, GitHub logo, trademarks, watermark, outer border, or cast shadow; icon-ready squircle; no tiny details
Avoid: generic AI gradients, glossy gel icons, 3D, excessive curves, notification bell cliché, literal arrows, decorative noise
```

The generated full-bleed art was composited through a deterministic rounded
rectangle alpha mask before producing the asset-catalog sizes.
