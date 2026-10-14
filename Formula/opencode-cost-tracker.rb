class OpencodeCostTracker < Formula
  desc "Local dashboard for estimated OpenCode LLM costs"
  homepage "https://github.com/thiemonipro/opencode_cost_tracker"
  url "https://github.com/thiemonipro/opencode_cost_tracker/releases/download/v0.2.0/opencode-cost-tracker-0.2.0.tar.gz"
  sha256 "b8eca98754a8fad92261c0e56f529f56916cf0c9a76c6edbd618471309050da6"
  license "MIT"

  depends_on "node@24"

  def install
    ENV.prepend_path "PATH", formula_opt_bin("node@24")
    system "npm", "ci", "--no-audit", "--no-fund"
    system "npm", "run", "build"
    system "npm", "prune", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund"

    libexec.install "bin", "build", "dist", "node_modules", "package.json"
    (bin/"opencode-cost-tracker").write <<~SH
      #!/bin/sh
      exec "#{formula_opt_bin("node@24")}/node" "#{libexec}/bin/opencode-cost-tracker.js" "$@"
    SH
  end

  def caveats
    <<~EOS
      Run opencode-cost-tracker, then open http://localhost:4174.
      OpenCode session history is required. To select a database explicitly:
        OPENCODE_DB_PATH=/path/to/opencode.db opencode-cost-tracker
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/opencode-cost-tracker --version")
    assert_match "OPENCODE_DB_PATH", shell_output("#{bin}/opencode-cost-tracker --help")

    database = testpath/"opencode.db"
    system formula_opt_bin("node@24")/"node", "--input-type=module", "-e", <<~JS
      import { DatabaseSync } from 'node:sqlite';
      const db = new DatabaseSync(#{database.to_s.to_json});
      db.exec(`
        CREATE TABLE project (id TEXT PRIMARY KEY, name TEXT);
        CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT, title TEXT, directory TEXT);
        CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT);
        INSERT INTO project VALUES ('project', 'Homebrew test');
        INSERT INTO session VALUES ('session', 'project', 'Test session', '/tmp/project');
        INSERT INTO message VALUES ('message', 'session', 1767268800000,
          '{"role":"assistant","providerID":"test","modelID":"test-model","cost":1.25,"tokens":{"input":100,"output":20}}');
      `);
      db.close();
    JS

    port = free_port
    ENV["PORT"] = port.to_s
    ENV["OPENCODE_DB_PATH"] = database.to_s
    pid = spawn (bin/"opencode-cost-tracker").to_s,
                out: (testpath/"server.log").to_s, err: [:child, :out]
    begin
      output = shell_output("curl --silent --fail --retry 20 --retry-connrefused --retry-delay 1 " \
                            "http://127.0.0.1:#{port}/api/health")
      health = JSON.parse(output)
      assert_equal true, health.fetch("ok")
      assert_equal database.to_s, health.fetch("databasePath")

      dashboard = JSON.parse(shell_output("curl --silent --fail http://127.0.0.1:#{port}/api/dashboard"))
      assert_equal 1.25, dashboard.fetch("overview").fetch("cost")
      assert_equal 1, dashboard.fetch("overview").fetch("requests")
      html = shell_output("curl --silent --fail http://127.0.0.1:#{port}/")
      assert_match '<div id="root"></div>', html
      asset = html.match(%r{src="(/assets/[^" ]+\.js)"})[1]
      assert_match "javascript", shell_output("curl --silent --fail --head http://127.0.0.1:#{port}#{asset}").downcase
    ensure
      Process.kill "TERM", pid
      Process.wait pid
    end
  end
end
