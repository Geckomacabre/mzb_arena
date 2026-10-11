fx_version 'cerulean'
game 'gta5'

author 'gecko'
description 'mzb_arena_clothes - the Maze Bank Arena merch stands\' tees and tank tops as clothing for the two freemode characters. Optional, and not for every server: read README.md first'
version '1.4.0'

-- The shirts the merch stands of mzb_arena sell: 22 tops (jbib) for each freemode character - 11 tees and 11 tank
-- tops, a drawable a stand, a texture a tee - in the collections mp_m_mzbmerch and mp_f_mzbmerch (stream/). mzb_arena
-- puts them on (its client/shop.lua, Config.MerchShop); it works without this resource, the tees on its stands' walls
-- are then dressing and nothing more.
--
-- It is a resource of its own because a clothing collection takes one of the few places the game has for them on a
-- freemode character (about 6 on game build 3407, 4 on 3717, 3 on 3889). A server that is out of places crashes
-- every player when their character is made: "Error executing native 0x00a1cadd00108836" (SetPlayerModel), then a
-- null pointer. Count yours before you ensure this - README.md says how.
data_file 'SHOP_PED_APPAREL_META_FILE' 'data/mp_m_freemode_01_mp_m_mzbmerch.meta'
data_file 'SHOP_PED_APPAREL_META_FILE' 'data/mp_f_freemode_01_mp_f_mzbmerch.meta'
files { 'data/mp_m_freemode_01_mp_m_mzbmerch.meta', 'data/mp_f_freemode_01_mp_f_mzbmerch.meta' }
