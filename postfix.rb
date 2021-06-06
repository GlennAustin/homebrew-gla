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
    toReplace = <<~TOREPLACE
    # In case some systems special-case pathnames beginning with //.

    case $install_root in
    /) install_root=
    esac

    test -z "$need_install_root" || test -n "$install_root" || {
        echo $0: Error: invalid package root directory: \"install_root=/\" 1>&2
        exit 1
    }
    TOREPLACE
    inreplace "postfix-install", toReplace, "# Remove test for an invalid install_root"
    system "make", "install_root=/", "upgrade"
  end
  
  plist_options manual: "#{HOMEBREW_PREFIX}/sbin/postfix start-fg"
  
  def caveats
    <<~EOS
      Postfix needs to have specific permissions, but brew can't do that itself. Execute
      
        /usr/bin/sudo #{sbin}/postfix post-install {first-install|upgrade-source}
      
      to set the permissions correctly
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
