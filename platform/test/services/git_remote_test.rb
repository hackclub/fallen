require "test_helper"

class GitRemoteTest < ActiveSupport::TestCase
  test "takes the repository's own address from what people paste" do
    assert_equal "https://github.com/you/thing", GitRemote.normalize("github.com/you/thing")
    assert_equal "https://github.com/you/thing", GitRemote.normalize("https://github.com/you/thing/tree/main/pcb")
    assert_equal "https://gitlab.com/group/sub/thing", GitRemote.normalize("https://gitlab.com/group/sub/thing/-/blob/main/README.md")
    assert_equal "https://codeberg.org/you/thing", GitRemote.normalize("https://Codeberg.org/you/thing/src/branch/main/")
    assert_equal "https://git.example.org/you/thing.git", GitRemote.normalize("https://git.example.org/you/thing.git")
  end

  test "refuses anything that could reach somewhere it shouldn't" do
    [
      "http://github.com/you/thing", "git@github.com:you/thing.git", "ssh://github.com/you/thing", "file:///etc/passwd",
      "https://user:pass@github.com/you/thing", "https://github.com:8443/you/thing", "https://127.0.0.1/you/thing",
      "https://[::1]/you/thing", "https://10.0.0.5/a/b", "https://localhost/you/thing", "https://box.local/you/thing",
      "https://metadata.internal/a/b", "https://github.com/you", "https://github.com/you/thing?x=1", "https://github.com/../etc/x",
      "", "x" * 400
    ].each do |url|
      assert_raises(GitRemote::Error, url) { GitRemote.normalize(url) }
    end
  end

  test "only public addresses count, IPv4 and IPv6" do
    %w[93.184.216.34 140.82.112.3 2606:50c0:8000::153].each { assert GitRemote.public_ip?(IPAddr.new(it)), it }
    %w[127.0.0.1 10.1.2.3 172.16.0.1 192.168.1.1 169.254.169.254 100.64.0.1 0.0.0.0 224.0.0.1 ::1 fc00::1 fe80::1 ::ffff:127.0.0.1 64:ff9b::a00:1]
      .each { refute GitRemote.public_ip?(IPAddr.new(it)), it }
  end

  test "a host with any private address is refused, even next to public ones" do
    stub_method(Resolv, :getaddresses, %w[140.82.112.3 10.0.0.1]) do
      assert_raises(GitRemote::Error) { GitRemote.public_address("sneaky.example") }
    end
    stub_method(Resolv, :getaddresses, %w[140.82.112.3]) do
      assert_equal "140.82.112.3", GitRemote.public_address("github.com").to_s
    end
  end

  test "reads the file list and finds the README and BOM nearest the root" do
    listing = [ "040000 tree aaa\tdocs", "100644 blob bbb\tdocs/README.md", "100644 blob ccc\tREADME.md", "100644 blob ddd\thw/Bill_of_Materials.csv",
                "100644 blob eee\tbom-notes.txt" ].join("\0")
    tree, truncated, oids = GitRemote.list_tree(listing)

    assert_equal 5, tree.size
    refute truncated
    assert_equal "ccc", oids["README.md"]
    assert_equal "README.md", GitRemote.pick(tree, GitRemote::README)
    assert_equal "hw/Bill_of_Materials.csv", GitRemote.pick(tree, GitRemote::BOM)
  end

  test "says what went wrong in words people can act on" do
    assert_match "public repository", GitRemote.clone_error("fatal: repository 'https://github.com/x/y/' not found")
    assert_match "redirects", GitRemote.clone_error("fatal: unable to access: The requested URL returned error: 301")
    assert GitRemote.redirected?("The requested URL returned error: 301")
  end

  test "links to files on the hosts it knows" do
    assert_equal "https://github.com/a/b/blob/abc/pcb/x.kicad_pcb", GitRemote.file_url("https://github.com/a/b", "abc", "pcb/x.kicad_pcb")
    assert_nil GitRemote.file_url("https://git.example.org/a/b", "abc", "x")
  end

  test "reading files refuses a bad commit, too many paths or an unsafe link before touching the network" do
    stub_method(Resolv, :getaddresses, []) do
      assert_raises(GitRemote::Error) { GitRemote.read_files("https://github.com/a/b", "main", [ "x" ]) }
      assert_raises(GitRemote::Error) { GitRemote.read_files("https://github.com/a/b", "a" * 40, Array.new(GitRemote::MAX_FILES_PER_READ + 1) { "f#{it}" }) }
      assert_raises(GitRemote::Error) { GitRemote.read_files("https://127.0.0.1/a/b", "a" * 40, [ "x" ]) }
      assert_equal({}, GitRemote.read_files("https://github.com/a/b", "a" * 40, []))
    end
  end

  test "reads only files in the commit's tree, and refuses one over the size cap before reading it" do
    Dir.mktmpdir do |dir|
      work = File.join(dir, "work")
      system("git", "init", "--quiet", work, exception: true)
      File.write(File.join(work, "small.txt"), "hello")
      File.write(File.join(work, "big.bin"), "x" * 2_000)
      git = ->(*args) { system("git", "-C", work, "-c", "user.name=t", "-c", "user.email=t@t", *args, out: File::NULL, exception: true) }
      git.("add", ".")
      git.("commit", "--quiet", "-m", "x")
      sha = `git -C #{work} rev-parse HEAD`.strip
      runner = ->(*args, repo: nil, &on_error) do
        out, _err, status = Open3.capture3("git", "--git-dir=#{repo}", *args.reject { it.start_with?("--no-lazy-fetch") })
        status.success? ? out : (on_error ? on_error.("") : raise(GitRemote::Error, "failed"))
      end

      files = GitRemote.files_at(runner, File.join(work, ".git"), sha, [ "small.txt", "big.bin", "../small.txt", "missing" ], limit: 1_000)

      assert_equal "hello", files["small.txt"]
      assert_equal Encoding::BINARY, files["small.txt"].encoding
      assert_match "too big", files["big.bin"].message
      assert_match "isn't in this commit", files["../small.txt"].message
      assert_match "isn't in this commit", files["missing"].message
    end
  end
end
