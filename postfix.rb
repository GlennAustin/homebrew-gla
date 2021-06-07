# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Postfix < Formula
  desc "Postfix SMTP mail service"
  homepage "https://postfix.org"
  url "http://ftp.porcupine.org/mirrors/postfix-release/official/postfix-3.6.0.tar.gz"
  sha256 "77462894d7671d63cbe5fc2733f941088515a6d67108b9f1808b7dae37e83c2e"
  license all_of: ["EPL-2.0", "IPL-1.0"]

  depends_on "openssl@1.1"
  depends_on 'mariadb' => :optional
  revision 1

  uses_from_macos "sqlite"

  def install
    # ENV.deparallelize  # if your formula fails when building in parallel
    ccargs = "-DUSE_SASL_AUTH -DUSE_TLS -I/usr/local/opt/openssl/include"
    auxlibs = "-L/usr/local/opt/openssl/lib -lssl -lcrypto"
    extraAuxLibs = []
    
    if build.with? "mariadb"
      ccargs += " -DHAS_MYSQL -I/usr/local/include/mysql"
      extraAuxLibs += ["AUXLIBS_MYSQL=-L/usr/local/lib/mysql -lmysqlclient -lz -lm"]
    end
    
    system "make", "-f", "Makefile.init", "makefiles", "dynamicmaps=yes",
      "CCARGS=#{ccargs}",
      "AUXLIBS=#{auxlibs}",
      "command_directory=#{sbin}",
      "config_directory=#{etc}/postfix",
      "daemon_directory=#{libexec}/postfix",
      "data_directory=#{var}/lib/postfix",
      "html_directory=#{doc}/html",
      "mail_spool_directory=#{var}/mail",
      "mail_owner=_postfix",
      "mailq_path=#{bin}/mailq",
      "manpage_directory=#{man}",
      "meta_directory=#{etc}/postfix",
      "newaliases_path=#{bin}/newaliases",
      "queue_directory=#{var}/spool/postfix",
      "readme_directory=#{doc}/README",
      "sendmail_path=#{sbin}/sendmail",
      "setgid_group=_postdrop",
      "shlib_directory=#{prefix}/lib/postfix",
      *extraAuxLibs
    system "make"
    toReplace1 = <<~TOREPLACE1
    case $install_root in
    /) install_root=
    esac
    TOREPLACE1
    inreplace "postfix-install" do |s|
      s.gsub! toReplace1, ""
    end
    system "make",
      "install_root=/",
      "mail_owner=_postfix",
      "setgid_group=_postdrop",
      "upgrade"
    controlFile = <<~END
    #!/bin/sh
    
    IFS=$'\\n'
    
    clean_up() {
      #{HOMEBREW_PREFIX}/sbin/postfix stop
      exit $1
    }
    
    trap clean_up SIGHUP SIGINT SIGTERM
    
    /usr/local/sbin/postfix status >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      echo 'Postfix is already running' >&2
      exit 1
    fi
    
    lastPreparedVersion=$(defaults read "#{etc}/postfix/brew_install.plist" "prepared_version" >/dev/null 2>&1)
    lastInstalledVersion=$(defaults read "#{etc}/postfix/brew_install.plist" "installed_version" >/dev/null 2>&1)
    
    if [ "$lastPreparedVersion" != "$lastInstalledVersion" ] ; then
      chown root:admin #{lib}/postfix
      if [ -z "$lastPreparedVersion" ] ; then
        #{HOMEBREW_PREFIX}/sbin/postfix set-permissions
        #{HOMEBREW_PREFIX}/sbin/postfix post-install first-install
      else
        #{HOMEBREW_PREFIX}/sbin/postfix post-install upgrade-source
      fi
      defaults write "#{etc}/postfix/brew_install.plist" "prepared_version" "$lastInstalledVersion"
      chmod go+r "#{etc}/postfix/brew_install.plist"
    fi
    
    #{HOMEBREW_PREFIX}/sbin/postfix start
    while true; do
      sleep 86400
    done
    clean_up
    END
    postfixCtl = (sbin/"postfix.macosx.sh")
    postfixCtl.atomic_write(controlFile)
    postfixCtl.chmod(0666)
    system "defaults", "write", "#{etc}/postfix/brew_install.plist", "installed_version", "#{version}.#{revision}"
  end
  
  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>RunAtLoad</key>
          <true/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{HOMEBREW_PREFIX}/sbin/postfix.macosx.sh</string>
          </array>
        </dict>
      </plist>
    EOS
  end
  
  def caveats
    <<~EOS
      Make sure to run our postfix execution script at least once before setting
      up brew to load postfix at startup:
      
        /usr/bin/sudo #{HOMEBREW_PREFIX}/sbin/postfix.macosx.sh
    EOS
  end


  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test postfix`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
