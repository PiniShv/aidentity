# Homebrew formula for the PiniShv/homebrew-tap tap.
#
#   brew tap PiniShv/tap
#   brew install aidentity
#
# See docs/homebrew-tap.md for how to publish and how to fill in the sha256.

class Aidentity < Formula
  desc "Run several accounts of the same Mac app at the same time"
  homepage "https://github.com/PiniShv/aidentity"
  url "https://github.com/PiniShv/aidentity/archive/refs/tags/v1.0.0.tar.gz"
  # Get the real value with:
  #   curl -sL https://github.com/PiniShv/aidentity/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
  sha256 "a0a0ce5872ed1f2f103a5537cca564bb5596ccb32563e05a482d439e2a383d16"
  license "MIT"
  head "https://github.com/PiniShv/aidentity.git", branch: "main"

  # aidentity builds macOS .app bundles and calls iconutil, PlistBuddy, codesign
  # and lsregister. None of that exists elsewhere.
  depends_on :macos

  def install
    bin.install "bin/aidentity"
  end

  def caveats
    <<~EOS
      Launchers are written to ~/Applications and profile data to
        ~/Library/Application Support/aidentity/profiles

      Start with:
        aidentity doctor
        aidentity add
    EOS
  end

  test do
    assert_match "aidentity #{version}", shell_output("#{bin}/aidentity version")
  end
end
