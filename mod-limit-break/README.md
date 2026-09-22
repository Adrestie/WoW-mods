# mod-limit-break

A gauge shared by a party or a raid, for AzerothCore 3.3.5a, after Final Fantasy
XIV's Limit Break. Damage dealt, damage taken and healing from every member fill
one common bar; any of them can spend it, and what happens depends on how far the
bar has filled and on which archetype -- healing, physical damage, magic damage,
tank -- that player put in the reached tier's slot. The gauge lives wherever most
of the group actually is: the map, instance, zone and phase holding the largest
number of members, with a floor of four. Nobody outside it fills the bar or
spends it, and no distance is ever measured.

**Specification only. No code yet.** The design is settled and written down in
[docs/CAHIER_DES_CHARGES.md](docs/CAHIER_DES_CHARGES.md), in French. It also
records the core hooks the module leans on, why each custom piece could not go
through the core, and what is deliberately left undecided -- the fill rates, the
sixteen effects and the boss list among them. Nothing else is in this folder yet:
no sources, no SQL, no configuration.

Original module, GPL-2.0-or-later, the licence of AzerothCore it is compiled
into.
