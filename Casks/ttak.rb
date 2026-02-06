cask "ttak" do
  version "2.2.0"
  sha256 "d40689d76ff5a89c191d2be8518002f7f1cc54a79dcc3b73678c7270534174ff"

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
