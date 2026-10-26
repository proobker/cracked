"""Build original 64px SVG skill art and its Godot identity manifest.

Each effect gets intentional geometry, never a hash or numbered branch glyph.
Run from any directory. Generated files are committed; Godot needs no Python.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent

def p(d):
    return f'<path d="{d}"/>'

def c(x, y, r):
    return f'<circle cx="{x}" cy="{y}" r="{r}"/>'

def r(x, y, w, h):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2"/>'

# ID: (name, gameplay meaning, original vector geometry).
ART = {
 'swap_speed': ('Quickdraw', 'Bring your next weapon up faster.', p('M13 32V17H49V27H31L27 42H15Z M12 46L17 56H34L39 35 M44 48V34M38 40L44 34L50 40')),
 'recoil_recovery': ('Counterweight', 'Settle your aim after each shot.', p('M9 17H51V27H29L24 39H14L17 27 M43 28V41M34 42H52L56 55H30Z M9 9H25')),
 'throw_recovery': ('Sleight of Hand', 'Recover faster after a throw.', c(43,17,9)+p('M40 8V4H47 M9 49L18 35Q21 30 24 35L27 40L39 32Q45 29 47 34L38 45L29 55H14 M19 37V25Q22 21 25 25V35 M50 33L56 29')),
 'moving_accuracy': ('Gyrostride', 'Keep your shots tighter while moving.', c(32,32,23)+p('M32 3V12M32 52V61M3 32H12M52 32H61 M22 20H33L35 33L45 36V43H19V36L23 32Z')),
 'slide_distance': ('Low Rider', 'Carry your slide farther.', p('M30 15L42 20L37 34L52 39V46H21L21 38L28 31Z M5 53H53M5 43H14M10 33H19 M54 50L59 53L54 56')),
 'moving_reload': ('Roadside Reload', 'Reload faster on the move.', r(25,9,16,25)+p('M29 15H37M29 21H37 M28 35L18 46L6 43 M37 35L44 43L39 57 M6 18H17M9 26H18')),
 'sprint_recovery': ('Chase Breaker', 'Ready your weapon sooner after sprinting.', c(34,11,5)+p('M30 20L22 34L35 42L29 57 M22 34L14 46H5 M27 25L40 30L45 23 M40 22H58V29H48L45 36 M5 15H21M9 23H19')),
 'slide_guard': ('Asphalt Armor', 'Take less damage while sliding.', p('M14 16L44 10L53 29L30 48L11 34Z M19 23L39 18L44 28L30 40Z M7 53H46M14 59H55')),
 'slide_stagger': ('Knee Breaker', 'Sliding primes your next shot to stagger an enemy.', p('M8 21H23L25 34L38 39L34 47H7V40L15 34Z M48 8V21L42 28L53 34L46 42V55 M34 22L40 26M55 21L59 17M53 46L58 49')),
 'dash_cooldown': ('Second Wind', 'Dash again sooner.', p('M12 24A22 22 0 1 1 13 45 M5 23L13 24L17 16 M18 32H43M35 24L43 32L35 40')),
 'air_control': ('Skyhook', 'Steer harder while airborne.', p('M8 11Q36 13 35 37L22 46L29 30L14 34L23 23L9 22Z M40 13V38Q40 54 55 49V36 M48 41L55 34L61 41')),
 'dash_handling': ('Slipstream Sight', 'Steady your weapon just after a dash.', c(39,31,15)+p('M39 9V20M39 42V53M17 31H28M50 31H61 M4 16Q15 7 26 16M3 44Q14 35 23 44 M5 30H13')),
 'dash_reload': ('Ghost Loader', 'Reload faster just after a dash.', p('M13 48V26Q13 9 29 10Q43 10 43 25V32 M13 48L19 43L25 49L30 43 M32 28H50L55 53H37Z M38 35H47M40 42H49')+c(23,25,2)+c(33,25,2)),
 'dash_guard': ('Afterimage Aegis', 'Take less damage just after a dash.', p('M8 17L19 12V40L13 46 M17 15L28 10V43L22 50 M29 16L44 9L58 16V33Q57 46 44 55Q29 46 29 33Z M37 30L43 36L51 23')),
 'near_miss': ('Thread the Needle', 'Dash past a bolt to gain a burst of speed.', p('M37 6Q51 6 50 19L42 57L34 19Q32 10 37 6 M8 28H34L42 23L34 18H12 M4 36H23')+c(42,15,4)),
 'scoped_handling': ('Dead Calm', 'Keep scoped shots steady.', p('M6 26Q32 3 58 26Q32 49 6 26Z M12 50H52M21 57H43')+c(32,26,9)),
 'first_shot': ('Clean Slate', 'Let shot spread settle faster.', p('M7 8L24 25M32 4V19M57 8L40 25M5 31H19M59 31H45 M14 51L25 40M50 51L39 40')+c(32,32,5)),
 'weak_damage': ('Achilles', 'Hit exposed weak points harder.', p('M8 15L26 7L23 25L12 31L23 39L25 56L8 46Z M56 15L38 7L41 25L52 31L41 39L39 56L56 46Z')+c(32,32,6)),
 'scope_speed': ('Snap Focus', 'Enter and leave your scope faster.', p('M18 7H44L58 30L45 55H18L5 32Z M18 7L27 24M44 7L40 27M58 30L40 39M45 55L27 40M18 55L23 27M5 32L25 24')+r(25,25,14,14)),
 'weak_stagger': ('Nerve Strike', 'Interrupt enemies with weak-point hits.', p('M10 12L27 23L36 42L52 53 M7 18L20 29L27 48L45 59 M34 6L37 18L49 14L43 25L56 30L42 33L44 45L33 36L23 43L25 29L14 24L28 21Z')),
 'precision_feed': ('Death Dividend', 'Weak-point kills feed reserve rounds into your magazine.', p('M11 25V17Q11 5 25 5Q39 5 39 17V25L32 29V35H18V29Z M21 29V34M28 29V34 M9 42Q4 56 23 57H35 M29 51L35 57L29 62 M44 32H55V58H44Z M49 32V24L53 19L57 24V29')+c(19,19,3)+c(31,19,3)),
 'bloom_control': ('Chokehold', 'Keep sustained shots from spreading as quickly.', p('M7 9H17V55H7 M57 9H47V55H57 M24 10L30 30L24 54M40 10L34 30L40 54 M19 32H45')),
 'reserves': ('Deep Pockets', 'Carry more spare ammunition.', p('M12 24H52V55H12Z M8 24L14 35H50L56 24 M19 22V11L23 5L27 11V22 M32 22V11L36 5L40 11V22 M45 22V13L49 7L53 13V22')+r(26,39,12,8)),
 'sustained_handling': ('Walking Thunder', 'Keep moving fire tighter.', p('M16 17H46V25H30L26 34H17Z M49 14L58 8M50 22H60M49 28L58 34 M25 36L15 47L8 56M32 36L43 45L38 57 M15 46H6')),
 'reload_speed': ('Fresh Teeth', 'Reload your weapon faster.', p('M19 13H42L47 49H24Z M24 13V6M31 13V6M38 13V6 M27 23H39M28 31H40 M12 23Q2 45 18 55H39 M34 49L41 55L34 61')),
 'sustained_stagger': ('Hammer Rhythm', 'Stagger an enemy on every fourth hit.', p('M14 8L37 6L42 20L20 26Z M28 25L35 43L43 40L36 22 M7 55V49M19 55V46M31 55V43M47 58V45 M40 48L47 41L55 48')),
 'focus_fire': ('Tunnel Vision', 'Repeated hits on one enemy sharpen your aim.', c(32,32,10)+p('M32 4V17M26 11L32 17L38 11 M32 60V47M26 53L32 47L38 53 M4 32H17M11 26L17 32L11 38 M60 32H47M53 26L47 32L53 38')),
 'blast_radius': ('Event Horizon', 'Reach farther with explosions and EMPs.', c(32,32,26)+c(32,32,19)+p('M32 19L36 28L46 26L40 34L44 43L34 39L25 46L27 36L18 31L28 28Z')),
 'blast_guard': ('Blast Cocoon', 'Resist your own explosive damage.', p('M32 5L55 14V32Q53 49 32 59Q11 49 9 32V14Z M32 17L36 28L47 25L41 35L44 44L33 40L23 46L25 35L17 29L28 28Z')),
 'blast_stagger': ('Shock Front', 'Make explosions stagger enemies.', p('M4 42L12 25L19 46L27 18L33 39 M40 23L49 32L55 26 M47 32L43 44L56 53M43 44L33 54')+c(44,13,5)),
 'grenade_capacity': ('Spare Pin', 'Carry one extra grenade.', p('M13 22H28L33 49Q22 59 10 49Z M17 22V15H25V22 M38 22H52L57 49Q45 59 34 49Z M42 22V15H50V22 M24 15L32 8H41 M18 31H27M39 31H51')+c(46,7,5)),
 'plasma_reload': ('Hot Swap', 'Reload plasma faster.', r(23,17,18,31)+p('M27 13H37M32 23L27 33H36L31 43 M11 38Q1 11 26 8M18 4L27 8L20 15 M53 25Q63 52 39 56M46 49L38 56L46 60')),
 'blast_reload': ('Kill Switch', 'Grenade kills briefly accelerate reloading.', p('M18 5L22 17L34 12L28 24L38 31L24 33L20 45L14 33L3 31L11 22L6 12L17 17 M31 37H49L54 59H35Z M39 37V30H52V22M46 25L52 19L58 25')),
 'emp_duration': ('Blackout', 'Keep enemies disrupted by EMPs longer.', p('M33 4L19 24H31L25 39L46 16H34Z M9 37H25V45H9Z M13 37V30M21 37V30 M17 45V57H28 M35 57H48V45M42 45H54V37H42 M31 52L34 48')),
 'burn_duration': ('Eternal Ember', 'Keep incendiary ground burning longer.', p('M14 6H50M14 58H50 M19 7Q19 23 30 31Q19 40 19 57 M45 7Q45 23 34 31Q45 40 45 57 M32 35Q22 46 27 51Q34 57 39 50Q42 45 36 42L33 48Z')),
 'throw_accuracy': ('Deadeye Delivery', 'Land moving throws more precisely.', c(46,43,13)+c(46,43,5)+p('M7 42Q6 9 29 10Q47 11 47 27 M41 21L47 28L53 21 M8 44H18L21 56H5Z M10 44V39H16')),
 'shield_break': ('Glassbreaker', 'Keep EMP-hit shields disabled longer.', p('M7 13L29 5L24 23L32 30L20 36L24 55Q7 42 7 30Z M38 5L58 13V30Q58 44 38 56L43 36L35 29L43 22Z M29 12L35 18M27 45L33 50')),
 'burn_slow': ('Cinder Snare', 'Slow enemies standing in your fire.', p('M26 5H39V32L51 40V48H25L20 39Z M16 29Q4 42 13 54Q24 65 40 55Q52 47 48 32L39 38 M12 37L16 21L24 32 M9 47L17 42')),
 'disrupt_damage': ('Salt the Wound', 'Shoot grenade-affected enemies for extra damage.', p('M7 11H20V23H26 M57 11H44V23H38 M7 53H20V41H26 M57 53H44V41H38 M32 21L35 28L43 26L39 33L42 40L34 37L27 43L28 35L21 31L29 28Z')+c(7,11,3)+c(57,11,3)+c(7,53,3)+c(57,53,3)),
}

def main():
    folder = ROOT / 'assets' / 'skills'
    folder.mkdir(parents=True, exist_ok=True)
    identities = []
    textures = []
    assert len(ART) == 39 and len({row[0] for row in ART.values()}) == 39
    assert len({row[2] for row in ART.values()}) == 39
    for key, (name, meaning, geometry) in ART.items():
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">' + geometry + '</g></svg>\n'
        (folder / f'{key}.svg').write_text(svg, encoding='utf-8')
        identities.append(f'\t{json.dumps(key)}: [{json.dumps(name)}, {json.dumps(meaning)}],')
        textures.append(f'\t{json.dumps(key)}: preload("res://assets/skills/{key}.svg"),')
    source = 'class_name SkillIdentity\nextends RefCounted\n## Generated original artwork/identity registry. Edit tools/generate_skill_icons.py.\nconst DATA := {\n' + '\n'.join(identities) + '\n}\nconst ICONS := {\n' + '\n'.join(textures) + '\n}\n'
    (ROOT / 'scripts/game/skill_identity.gd').write_text(source, encoding='utf-8')
    print('Generated 39 distinct original SVG icons and skill identities.')

if __name__ == '__main__':
    main()
