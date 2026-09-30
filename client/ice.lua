-- mzb_arena - client: the hockey rink's ice is slippery on foot (Config.Ice). The rink's surface is GTA's ICE material,
-- so vehicles slide on it by themselves; a ped's walk barely reads the surface, so on foot this keeps your momentum -
-- your velocity eases towards what your legs are asking for over Config.Ice.slide seconds (you glide on when you let
-- go, overshoot a stop, drift through a turn) - and a hard turn at a sprint can put you on the ice.

local cfg = Config.Ice or {}

-- on the ice: inside the rink's rounded rectangle (Config.Rink, arena frame) with your feet on it
local function onIce(p)
    local R, f = Config.Rink, Config.ArenaFrame
    if not R or not f then return false end
    local dx, dy = p.x - f.x, p.y - f.y
    local c, s = math.cos(f.ang), math.sin(f.ang)
    local u, v = math.abs(dx * c + dy * s), math.abs(-dx * s + dy * c)
    if u > R.halfL or v > R.halfW then return false end
    local cu, cv = R.halfL - R.r, R.halfW - R.r
    if u > cu and v > cv and (u - cu) ^ 2 + (v - cv) ^ 2 > R.r * R.r then return false end
    local h = p.z - R.z                                         -- the ped's origin stands about 1 m over its feet
    return h > 0.4 and h < 1.5
end

local function iceShow()
    local shows = cfg.shows or { hockey = true }
    return shows[GlobalState.mzbShow or Config.DefaultShow] == true
end

CreateThread(function()
    local vel = nil
    local lastFall, wasTurning = 0, false
    while true do
        local wait = 500
        local ped = PlayerPedId()
        if cfg.enabled ~= false and iceShow() and not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped)
            and not IsPedFalling(ped) and not IsPedSwimming(ped) and not IsEntityDead(ped) then
            local p = GetEntityCoords(ped)
            if onIce(p) then
                wait = 0
                local dt = math.max(GetFrameTime(), 0.001)
                local cur = GetEntityVelocity(ped)
                if not vel then vel = cur end
                local k = math.exp(-dt / math.max(cfg.slide or 0.65, 0.05))
                local nx = cur.x + (vel.x - cur.x) * k
                local ny = cur.y + (vel.y - cur.y) * k
                local sp = math.sqrt(nx * nx + ny * ny)
                local mx = cfg.maxSpeed or 9.0
                if sp > mx then nx, ny, sp = nx / sp * mx, ny / sp * mx, mx end
                if not IsPedJumping(ped) then SetEntityVelocity(ped, nx, ny, cur.z) end
                vel = vector3(nx, ny, cur.z)
                -- a slip: sprinting while your body points well away from where you are sliding (checked once per turn)
                local turning = false
                if cfg.falls ~= false and sp > 4.0 and IsPedSprinting(ped) then
                    local hd = math.rad(GetEntityHeading(ped))
                    local fx, fy = -math.sin(hd), math.cos(hd)
                    turning = (nx * fx + ny * fy) / sp < 0.35
                end
                if turning and not wasTurning and GetGameTimer() - lastFall > (cfg.fallCooldown or 4.0) * 1000 then
                    if math.random() < (cfg.fallChance or 0.35) then
                        lastFall = GetGameTimer()
                        SetPedToRagdoll(ped, 1400, 1900, 0, false, false, false)
                        vel = nil
                    end
                end
                wasTurning = turning
            else
                vel, wasTurning = nil, false
            end
        else
            vel, wasTurning = nil, false
        end
        Wait(wait)
    end
end)
