class Ttak < Formula
  desc "Zero-delay Korean/English input source switcher for macOS"
  homepage "https://github.com/ongjin/ttak"
  url "https://github.com/ongjin/ttak/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "39048b1d1d59a97092c77c64b7044d061a4f30440886d56f4551e3d5db132060"
  license "MIT"

  depends_on :macos => :ventura

  def install
    system "swift", "build",
           "-c", "release",
           "--disable-sandbox",
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
