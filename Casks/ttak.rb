cask "ttak" do
  version "2.0.0"
  # ── How to update sha256 ────────────────────────────────────────
  # After creating a GitHub release with Ttak.app.zip attached:
  #
  #   1. Download the release asset:
  #      curl -L -o Ttak.app.zip \
  #        https://github.com/ongjin/ttak/releases/download/v2.0.0/Ttak.app.zip
  #
  #   2. Compute the checksum:
  #      shasum -a 256 Ttak.app.zip
  #
  #   3. Replace the placeholder below with the output hash.
  # ────────────────────────────────────────────────────────────────
  sha256 "d835b7ee7dd1244fb695e2bb5b5f74e3bffbc5ef788aec53931f39e1af7330dc"

  url "https://github.com/ongjin/ttak/releases/download/v#{version}/Ttak.app.zip"
  name "Ttak"
  desc "Zero-delay Korean/English input source switcher for macOS"
  homepage "https://github.com/ongjin/ttak"

  depends_on macos: ">= :ventura"

  app "Ttak.app"

  zap trash: [
    "~/.config/ttak",
  ]

  caveats <<~EOS
    Accessibility permission is required.

    Grant access in:
      System Settings > Privacy & Security > Accessibility

    Ttak runs as a menu bar app. Look for the keyboard icon in your menu bar.
  EOS
end
