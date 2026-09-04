local categories = require("lib.menu-simulation-categories")

local setting_names = {
  biters = "bug-free-menu-hide-biters",
  demolishers = "bug-free-menu-hide-demolishers",
  pentapods = "bug-free-menu-hide-pentapods",
}

local simulations = data.raw["utility-constants"]["default"].main_menu_simulations

for category, setting_name in pairs(setting_names) do
  if settings.startup[setting_name].value then
    for _, simulation_name in pairs(categories[category]) do
      simulations[simulation_name] = nil
    end
  end
end
