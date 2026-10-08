
-- ── NVIDIA (proprietary/open kernel module) ───────────────────────
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
