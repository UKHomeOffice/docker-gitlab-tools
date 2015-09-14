#!/usr/bin/ruby

require 'optionscrapper'
require 'mysql2'
require 'erb'
require 'net/smtp'

EMAIL_TEMPLATE = <<END_OF_MESSAGE
From: Gitlab <<%= scope['from'] %>>
To: <% scope['name'] %> <<%= scope['to'] %>>
Subject: GitLab Two Factor Authentication Notification

Hi <%= scope['name'] %>

We've noticed two-factor authentication is not enabled for your Gitlab account. For reasons of security two factor authentication
should be enabled for all accounts. In order setup two-factor, you can consult the documentation at http://doc.gitlab.com/ce/profile/two_factor_authentication.html or
simply login to your gitlab account -> profile settings and enable the feature.

Gitlab

https://<%= ENV['GITLAB_WWW'] %>

Please do not reply to this automated email

END_OF_MESSAGE

module Gitlab
  class Render
    attr_reader :scope

    def initialize(scope = {})
      @scope = scope
    end

    def render(template)
      ::ERB.new(template, nil, '-').result(binding)
    end
  end

  class TwoFactorAlert
    def initialize
      begin
        # parse the command line options
        parser.parse!
        # check for those not using two facter
        two_factor
      rescue SystemExit => e
      rescue Exception  => e
        parser.usage e.message
      end
    end

    private
    # two_factor ... the main function, grab the users which do not have two factor enabled and send
    # them a polite email
    def two_factor
      # step: connect to the database and retrieve a list of users which do not have two factor switched on
      annonce "retrieving a list of users without two factor enabled from the database"
      users = mysql.query(
        "SELECT id, name, username, email FROM users where encrypted_otp_secret is null")

      annonce "found #{users.size} users which do not have two factor enabled"
      users.each do |user|
        # step: if include is NOT empty, filter out anyone NOT in the list
        next if !options[:include].empty? and !options[:include].include?(user['username'])
        # step: ignore those requested
        next if options[:ignore].include?(user['username'])

        # step: send the email to the user
        politely_inform(user)
      end
    end

    # politely_inform ... send an email to the user politely informing them they should switch on
    # two factor authentication
    def politely_inform(user)
      annonce "sending an email to user: #{user['username']}, email: #{user['email']}"
      # step: generate the content for the email
      content = ::Gitlab::Render::new({
        'username' => user['username'],
        'name'     => user['name'],
        'from'     => options[:from_address],
        'to'       => user['email'],
      }).render(EMAIL_TEMPLATE)
      # step: send the email to the user
      if options[:dryrun]
        puts "#{content}"
      else
        begin
          Net::SMTP.start(options[:email], 25) do |smtp|
            smtp.send_message content, options[:from_address], user['email']
          end
        rescue Exception => e
          annonce "failed to send an alert email to username: #{user['username']}, error: #{e.message}"
        end
      end
    end

    # annonce ... some rudimentary logging
    def annonce(message)
      puts "[v] #{message}" if message
    end

    # options ... the command line options
    def options
      @options ||= default_options
    end

    # mysql ... a wrapper to grab a connection to the database
    def mysql
      @mysql ||= nil
      unless @mysql
        db_options = {
          :host => options[:database_host],
          :port => options[:database_port],
        }
        db_options[:username] = options[:username] if options[:username]
        db_options[:password] = options[:password] if options[:password]
        db_options[:database] = options[:database_name] if options[:database_host]
        @mysql = Mysql2::Client.new(db_options)
      end
      @mysql
    end

    # default_options ... the default command line options
    def default_options
      {
        :database_host  => ENV['DATABASE_HOST'] || '127.0.0.1',
        :database_name  => ENV['DATABASE_NAME'] || 'gitlabhq',
        :database_port  => ENV['DATABASE_PORT'] || '3306',
        :username       => ENV['DATABASE_USER'] || 'root',
        :password       => ENV['DATABASE_PASSWD'],
        :dryrun         => false,
        :email          => ENV['SMTP_HOST'] || 'mail.default.cluster.local',
        :ignore         => [],
        :include        => [],
        :from_address   => ENV['GITLAB_EMAIL'],
      }
    end

    def parser
      @parser ||= OptionScrapper.new do |o|
        o.on('-h HOST', '--host HOST', "the hostname / ip address of the database (defaults #{options[:database_host]})") { |x| options[:database_host] = x }
        o.on('-d DATABASE', '--database DATABASE', "the database name which gitlab is using (defaults #{options[:database_name]})") { |x| options[:database_name] = x }
        o.on('-p PORT', '--port PORT', "the port the database is running on (defaults #{options[:database_port]})") { |x| options[:database_port] = x }
        o.on('-U USERNAME', '--username USERNAME', "the username to access the database with (defaults #{options[:username]})") { |x| options[:username] = x }
        o.on('-P PASSWORD', '--password PASSWORD', "the password to access the database with") { |x| options[:password] = x }
        o.on('-E EMAIL', '--email EMAIL', 'the email server used to send the messages') { |x| options[:email] = x }
        o.on('-f EMAIL', '--from EMAIL', 'the email address the alert should be come from') { |x| options[:from_address] = x }
        o.on('-i USERNAME', '--include USERNAME', 'perform the alert on the only those username included') { |x| options[:include] << x }
        o.on('-I USERNAME', '--ignore USERNAME', 'ignore the following email/user from check (can be used multiple times)') { |x| options[:ignore] << x }
        o.on('-D', '--dry-run', 'perform a dryrun on the alert and print to screen') { |x| options[:dryrun] = true }
      end
    end
  end
end

Gitlab::TwoFactorAlert::new
