require "openssl"
require "json"

SHA_KEY = "DFkkjhjkfghdrtuJhjfgkhj7676tYEtyut67587buig67O0jObuy7i6"

def sha256(value)
  nil if value.nil? || value.empty?

  OpenSSL::HMAC.hexdigest("sha256", SHA_KEY, value)
end

file_name = "users.json"

unless File.exist?(file_name)

  h_user = [
    { id: 1, username: "alice", password: sha256("pwda") },
    { id: 2, username: "bob", password: sha256("pwdb") },
    { id: 3, username: "charlie", password: sha256("pwdc") },
    { id: 4, username: "dave", password: sha256("pwdd") }
  ]

  File.write(file_name, h_user.to_json)

end

USERS = JSON.parse File.read(file_name), symbolize_names: true
 
# Returns corresponding user if username and password are correct
def authenticate(username, password)
  USERS.select do |user|
    user.slice(:username, :password) == { username: username, password: sha256(password) }
  end.first&.slice(:id, :username)
end
