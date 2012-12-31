#!/usr/bin/ruby
require 'rubygems'
require 'eventmachine'
class User
  @@default_domain = "example.com" # used to qualify names
  @@users = {
    "cyrus@example.com" => "cowboy", # the cyrus administrator account
    "sales@someotherdomain.com" => "password"
  }
  class << self
    def exists? user
      unless user.include?("@")
        user = "#{user}@#{@@default_domain}"
        puts "Qualified address to: #{user}"
      end
      @@users.keys.include? user
    end
    def auth user, psw, sysname, realm
      unless user.include?("@")
        if realm.nil? || realm == ""
          user = "#{user}@#{@@default_domain}"
          puts "Qualified address to: #{user}"
				else
          user = "#{user}@#{realm}"
				end
      end
      return false unless exists? user
      @@users[user] == psw
    end
  end
end
class Saslauth < EM::Connection
  include EM::Protocols::SASLauth
  def validate username, psw, sysname, realm
    response = User.auth(username,psw,sysname,realm)
    puts "saslauth: user=#{username}, psw=#{psw}, sysname=#{sysname}, realm=#{realm} = #{response}"
    response
  end
end
class Recipient < EM::Connection
  include EM::Protocols::LineText2
  def receive_line line
    null = "\0"
    response = User.exists?(line.chomp).to_s
    puts "recipient: #{line} = #{response}"
    send_data(response + null)
  end
end
EM::run {
  EventMachine::start_unix_domain_server '/usr/local/mail/sock/recipient', Recipient
  EventMachine::start_unix_domain_server '/usr/local/mail/sock/saslauth', Saslauth
  File.chmod( 0777, "/usr/local/mail/sock/recipient")
  File.chmod( 0777, "/usr/local/mail/sock/saslauth")
}
