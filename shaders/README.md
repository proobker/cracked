# First-person shaders

viewmodel.gdshader squeezes clip-space depth toward the camera under reverse-Z
so the weapon stays visible near walls. viewmodel_flash.gdshader gives the
muzzle-flash quad additive, unlit shading with matching depth treatment.

These are presentation effects. Hit tests, grenades, world projectiles and enemy
collision must use world geometry rather than viewmodel depth.

New gun models should preserve this material contract. Check flashes/scopes and
silhouettes beside walls on Android. World particles/fields should remain
occluded by cover.
