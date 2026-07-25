return {
  biters = {
    "nauvis_mining_defense",
    "nauvis_artillery",
    "nauvis_biter_base_steamrolled",
    "nauvis_biter_base_spidertron",
    "nauvis_biter_base_artillery",
    "nauvis_biter_base_player_attack",
    "nauvis_biter_base_laser_defense",
    "nauvis_chase_player",
    "nauvis_big_defense",
    "nauvis_brutal_defeat",
  },
  pentapods = {
    "gleba_pentapod_ponds",
    "gleba_egg_escape",
    "gleba_farm_attack",
  },
  demolishers = {
    "vulcanus_crossing",
    -- Key name matches the base game's own typo; do not "fix" it or the deletion in
    -- data-final-fixes.lua silently no-ops (deleting a nonexistent table key raises no error).
    "vulcanus_punishmnent",
  },
}
