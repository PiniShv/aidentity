# Homebrew formula for the PiniShv/homebrew-tap tap.
#
#   brew tap PiniShv/tap
#   brew install aidentity
#
# See docs/homebrew-tap.md for how to publish and how to fill in the sha256.

class Aidentity < Formula
  desc "Run several accounts of the same Mac app at the same time"
  homepage "https://github.com/PiniShv/aidentity"
  url "https://github.com/PiniShv/aidentity/archive/refs/tags/v1.4.0.tar.gz"
  # Get the real value with:
  #   curl -sL https://github.com/PiniShv/aidentity/archive/refs/tags/v1.4.0.tar.gz | shasum -a 256
  sha256 "a24fa8db64caba6101e16e52cc4f330922eb6260f842bf1118f459914fc9d0e3"
  license "MIT"
  head "https://github.com/PiniShv/aidentity.git", branch: "main"

  # aidentity builds macOS .app bundles and calls iconutil, PlistBuddy, codesign
  # and lsregister. None of that exists elsewhere.
  depends_on :macos

  def install
    bin.install "bin/aidentity"
    # Tab completion for the three shells aidentity writes a script for.
    generate_completions_from_executable(bin/"aidentity", "completion")
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
