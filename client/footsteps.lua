-- mzb_arena - client: quieter footsteps.
-- While you are in the building your footsteps are the game's quiet ones (they rang round the bowl); outside they are
-- the game's own again. Config.QuietFootsteps = false leaves them alone.

if Config.QuietFootsteps == false then return end

CreateThread(function()
    local quiet = false
    while true do
        local want = (MzbListener and MzbListener.zone or 'outside') ~= 'outside'
        if want or quiet then
            SetPedAudioFootstepQuiet(PlayerPedId(), want)
            quiet = want
        end
        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetPedAudioFootstepQuiet(PlayerPedId(), false)
end)
