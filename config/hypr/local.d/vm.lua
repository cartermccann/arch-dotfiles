
-- ── UTM / virtual machine ─────────────────────────────────────────
-- The VM's virtio GPU either paints GL clients or it doesn't, depending on
-- the UTM version and display device. `ouranos-gpu --on|--off` flips the
-- marked block below; --off (software rendering) is the safe default.
-- Software rendering cannot afford the glass, so blur/shadow/glow go too.
-- >>> ouranos-gpu
hl.env("LIBGL_ALWAYS_SOFTWARE", "1")
hl.config({
  decoration = {
    blur = { enabled = false },
    shadow = { enabled = false },
    glow = { enabled = false },
    dim_inactive = false,
  },
})
-- <<< ouranos-gpu

hl.config({
  -- virtio-gpu has no hardware cursor plane worth trusting
  cursor = { no_hardware_cursors = 1 },
  input = { accel_profile = "adaptive" },
})
-- The VM sees one virtual output. Its resolution is fixed at boot; set it
-- in UTM (Display → resolution) rather than changing the mode live, which
-- whites out the screen under virtio-gpu.

-- Clipboard shared with the Mac: UTM → spice-vdagentd → ouranos-vdagent → wl-clipboard
hl.on("hyprland.start", function()
  hl.exec_cmd("bash -c 'sleep 2; systemctl --user import-environment WAYLAND_DISPLAY; systemctl --user start ouranos-vdagent'")
end)
