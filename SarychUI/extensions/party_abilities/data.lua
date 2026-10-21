-- Spell list: ATT first (cooldowns, glyphs and talent tabs), then IDs that only PAB has.
-- Entry: {spellID, cooldown, talentTab, talentIndex, faction, race, excludeRace, icon}
SarychUI.PartyAbilityPresets = {
	DRUID = {
		{29166, 180}, -- Innervate
		{22812, 60}, -- Barkskin
		{8983, 60}, -- Bash
		{53201, 60, 1, 28}, -- Starfall
		{50334, 180, 2, 30}, -- Berserk
		{61336, 180, 2, 7}, -- Survival Instincts
		{16979, 15, 2, 14}, -- Feral Charge - Bear
		{17116, 180, 3, 12}, -- Nature's Swiftness
		{18562, 13, 3, 18}, -- Swiftmend
	},
	HUNTER = {
		{14311, 28}, -- Freezing Trap
		{60192, 28}, -- Freezing Arrow
		{13809, 28}, -- Frost Trap
		{19263, 90}, -- Deterrence
		{67481, 60}, -- Roar of Sacrifice
		{53271, 60}, -- Master's Call
		{19574, 120, 1, 18}, -- Bestial Wrath
		{34490, 20, 2, 24}, -- Silencing Shot
		{23989, 180, 2, 14}, -- Readiness
		{19503, 30, 3, 9}, -- Scatter Shot
		{49012, 30, 3, 20}, -- Wyvern Sting
	},
	MAGE = {
		{1953, 15}, -- Blink
		{2139, 24}, -- Counterspell
		{12051, 240}, -- Evocation
		{45438, 300}, -- Ice Block
		{44572, 30, 3, 28}, -- Deep Freeze
		{11958, 384, 3, 14}, -- Cold Snap
		{11129, 120, 2, 20}, -- Combustion
		{42950, 20, 2, 25}, -- Dragon's Breath
		{12043, 60, 1, 16}, -- Presence of Mind
	},
	PALADIN = {
		{10308, 40}, -- Hammer of Justice
		{1044, 25}, -- Hand of Freedom
		{54428, 60}, -- Divine Plea
		{6940, 120}, -- Hand of Sacrifice
		{10278, 180}, -- Hand of Protection
		{642, 300}, -- Divine Shield
		{31821, 120, 1, 6}, -- Aura Mastery
		{48825, 5, 1, 18}, -- Holy Shock
		{64205, 120, 2, 6}, -- Divine Sacrifice
		{48827, 30, 2, 22}, -- Avenger's Shield
		{66008, 60, 3, 18}, -- Repentance
	},
	PRIEST = {
		{10890, 27}, -- Psychic Scream
		{48158, 12}, -- Shadow Word: Death
		{34433, 300}, -- Shadowfiend
		{6346, 180}, -- Fear Ward
		{33206, 144, 1, 25}, -- Pain Suppression
		{47585, 75, 3, 27}, -- Dispersion
		{15487, 45, 3, 13}, -- Silence
		{64044, 120, 3, 23}, -- Psychic Horror
	},
	ROGUE = {
		{1766, 10}, -- Kick
		{8643, 20}, -- Kidney Shot
		{31224, 60}, -- Cloak of Shadows
		{51722, 60}, -- Dismantle
		{2094, 120}, -- Blind
		{26889, 120}, -- Vanish
		{14177, 180, 1, 13}, -- Cold Blood
		{51690, 120, 2, 28}, -- Killing Spree
		{14185, 300, 3, 14}, -- Preparation
		{51713, 60, 3, 28}, -- Shadow Dance
		{36554, 20, 3, 25}, -- Shadowstep
	},
	SHAMAN = {
		{57994, 6}, -- Wind Shear
		{51514, 45}, -- Hex
		{8177, 15}, -- Grounding Totem
		{51490, 45, 1, 25}, -- Thunderstorm (45s, glyph -10s)
		{16166, 180, 1, 16}, -- Elemental Mastery
		{30823, 60, 2, 26}, -- Shamanistic Rage
		{16188, 120, 3, 13}, -- Nature's Swiftness
	},
	WARLOCK = {
		{19647, 24}, -- Spell Lock
		{17925, 120}, -- Death Coil
		{48011, 8}, -- Devour Magic
		{48020, 30}, -- Demonic Circle: Teleport
		{18708, 180, 2, 10}, -- Fel Domination
		{47847, 20, 3, 23}, -- Shadowfury
	},
	WARRIOR = {
		{6552, 10}, -- Pummel
		{72, 12}, -- Shield Bash
		{11578, 13}, -- Charge
		{47996, 15}, -- Intercept
		{871, 300}, -- Shield Wall
		{2565, 60}, -- Shield Block
		{676, 60}, -- Disarm
		{46924, 90, 1, 31}, -- Bladestorm
		{12809, 30, 3, 14}, -- Concussion Blow
		{46968, 17, 3, 27}, -- Shockwave
	},
	DEATHKNIGHT = {
		{47528, 10}, -- Mind Freeze
		{48743, 120}, -- Death Pact
		{49576, 35}, -- Death Grip
		{48707, 45}, -- Anti-Magic Shell
		{47476, 120}, -- Strangulate
		{48792, 120}, -- Icebound Fortitude
		{49039, 120, 2, 8}, -- Lichborne
		{49203, 60, 2, 20}, -- Hungering Cold
		{51271, 60, 2, 24}, -- Unbreakable Armor
		{47481, 20}, -- Gnaw (shown for every DK; not a talent check in ATT)
		{51052, 120, 3, 22}, -- Anti-Magic Zone
		{49206, 180, 3, 31}, -- Summon Gargoyle
	},
	OTHER = {
		{42292, 120, nil, nil, nil, nil, "Human", "Interface\\Icons\\Inv_jewelry_trinketpvp_02"},
		{59752, 120, nil, nil, nil, "Human"},
		{20572, 120, nil, nil, nil, "Orc"},
		{20594, 120, nil, nil, nil, "Dwarf"},
		{58984, 120, nil, nil, nil, "NightElf"},
		{7744, 120, nil, nil, nil, "Scourge"},
		{20549, 120, nil, nil, nil, "Tauren"},
		{20589, 60, nil, nil, nil, "Gnome"},
		{26297, 180, nil, nil, nil, "Troll"},
		{28730, 120, nil, nil, nil, "BloodElf"},
		{71607, 120, nil, nil, nil, nil, nil, "Interface\\Icons\\inv_jewelcrafting_gem_28"},
	},
}

-- Trinket spells. Shown only when that item (or a trinket with the same use spell) is equipped.
SarychUI.PartyAbilityItems = {
	[42292] = { trinket = true, name = "PvP Trinket", icon = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02" },
	[71607] = { item = 50354, trinket = true, name = "Bauble of True Blood", icon = "Interface\\Icons\\INV_Jewelcrafting_Gem_28" },
}
