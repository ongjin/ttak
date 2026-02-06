class Ttak < Formula
  desc "Zero-delay Korean/English input source switcher for macOS"
  homepage "https://github.com/user/ttak"

  # Replace "user" with your GitHub username and update the sha256
  url "https://github.com/user/ttak/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256" # Run: shasum -a 256 v1.0.0.tar.gz
  license "MIT"

  depends_on :macos => :ventura
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build",
           "-c", "release",
           "-Xswiftc", "-suppress-warnings"
    bin.install ".build/release/ttak"
  end

  service do
    run [opt_bin/"ttak"]
    keep_alive true
    log_path var/"log/ttak.log"
    error_log_path var/"log/ttak.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      Accessibility permission is required.

      Grant access in:
        System Settings > Privacy & Security > Accessibility

      To start ttak and restart at login:
        brew services start ttak

      To stop ttak:
        brew services stop ttak
    EOS
  end

  test do
    assert_match "ttak v#{version}", shell_output("#{bin}/ttak --version")
  end
end
