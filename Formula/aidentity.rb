# Homebrew formula for the PiniShv/homebrew-tap tap.
#
#   brew tap PiniShv/tap
#   brew install aidentity
#
# See docs/homebrew-tap.md for how to publish and how to fill in the sha256.

class Aidentity < Formula
  desc "Run several accounts of the same Mac app at the same time"
  homepage "https://github.com/PiniShv/aidentity"
  url "https://github.com/PiniShv/aidentity/archive/refs/tags/v1.2.0.tar.gz"
  # Get the real value with:
  #   curl -sL https://github.com/PiniShv/aidentity/archive/refs/tags/v1.2.0.tar.gz | shasum -a 256
  sha256 "d74297120e2983344c8cc774755ac9ea8c9fa261f37cb6f2a8e740a7c33d820b"
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

      Start with the guided walkthrough:
        aidentity setup
    EOS
  end

  test do
    # A pattern, not "aidentity #{version}": a --HEAD build's version is
    # HEAD-<sha>, while the script prints its own release number.
    assert_match(/^aidentity \d+\.\d+\.\d+$/, shell_output("#{bin}/aidentity version"))
  end
end
