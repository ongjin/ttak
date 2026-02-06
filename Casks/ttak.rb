cask "ttak" do
  version "2.1.0"
  sha256 "e2461ce6f10a12828cafabae8728390a4d2aa1d486f6f864dc7a3124fc991515"

  url "https://github.com/ongjin/ttak/releases/download/v#{version}/Ttak.app.zip"
  name "Ttak"
  desc "Zero-delay Korean/English input source switcher for macOS"
  homepage "https://github.com/ongjin/ttak"

  depends_on macos: ">= :ventura"

  app "Ttak.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-d", "com.apple.quarantine", "#{appdir}/Ttak.app"],
                   sudo: false
  end

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
