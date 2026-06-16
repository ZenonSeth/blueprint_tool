minetest.register_craft({
  output = "blueprint_tool:blueprint 3",
  recipe = {
    { blueprint_tool.itemstrings.fragment, "", blueprint_tool.itemstrings.fragment },
    { blueprint_tool.itemstrings.paper, blueprint_tool.itemstrings.paper, blueprint_tool.itemstrings.paper },
    { blueprint_tool.itemstrings.glass, "", blueprint_tool.itemstrings.steel },
  },
})

minetest.register_craft({
  output = "blueprint_tool:creation_tool",
  recipe = {
    { blueprint_tool.itemstrings.steel, blueprint_tool.itemstrings.steel, blueprint_tool.itemstrings.steel },
    { "blueprint_tool:blueprint", "blueprint_tool:blueprint", "blueprint_tool:blueprint" },
    { blueprint_tool.itemstrings.fragment, blueprint_tool.itemstrings.diamond, blueprint_tool.itemstrings.fragment },
  },
})
