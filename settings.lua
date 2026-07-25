local no_space_age = not mods["space-age"]

data:extend({
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-biters",
    setting_type = "startup",
    default_value = true,
    order = "a",
    localised_name = {"mod-setting-name.bug-free-menu-hide-biters"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-biters"}
  },
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-demolishers",
    setting_type = "startup",
    default_value = true,
    order = "b",
    hidden = no_space_age,
    localised_name = {"mod-setting-name.bug-free-menu-hide-demolishers"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-demolishers"}
  },
  {
    type = "bool-setting",
    name = "bug-free-menu-hide-pentapods",
    setting_type = "startup",
    default_value = true,
    order = "c",
    hidden = no_space_age,
    localised_name = {"mod-setting-name.bug-free-menu-hide-pentapods"},
    localised_description = {"mod-setting-description.bug-free-menu-hide-pentapods"}
  }
})
