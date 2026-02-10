require "bundler/inline"

gemfile do
    source "http://rubygems.org"

    gem "sinatra-contrib"
    # -contrib contient plusieurs extensions pratiques
    # https://sinatrarb.com/contrib/

    gem "rackup"
    gem "puma"
    gem "bcrypt"
end

require "sinatra/base"
require "sinatra/reloader"
require "json"
require "securerandom"
require "bcrypt"
require "digest"

class MySinatraApp < Sinatra::Base

    configure :development do
        register Sinatra::Reloader
    end

    # Sessions (cookie) - première étape vers l'authentification par session
    configure do
        enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
    # Fingerprint du secret pour aider au debug (ne loggez pas le secret en clair)
    warn "SESSION_SECRET fp: #{Digest::SHA256.hexdigest(settings.session_secret)[0,8]}"
        # Options du cookie de session. En production, mettez `secure: true`.
        session_secure = settings.environment == :production
        use Rack::Session::Cookie, key: 'auth.session', path: '/',
            secret: settings.session_secret, httponly: true, secure: session_secure, same_site: :lax, expire_after: 3600

        # Protection basique contre CSRF / attaques courantes (pour les forms HTML)
        # Pour APIs JSON, considérez un token CSRF explicite si nécessaire.
        use Rack::Protection
    end


    set :public_folder, File.expand_path("../docs", __dir__)

    # Utiliser un chemin absolu basé sur le répertoire où se trouve ce fichier
    USER_FILE = File.expand_path("users.json", __dir__)
    File.write(USER_FILE, "[]") unless File.exist?(USER_FILE)

    # Migration automatique: convertir les mots de passe en clair existants
    # en password_digest (BCrypt) afin de sécuriser les mots de passe.
    def self.migrate_passwords!
        data = JSON.parse(File.read(USER_FILE)) rescue []
        changed = false

        data.map! do |u|
            # si l'utilisateur a encore la clé "password" (legacy), créer digest
            if u.key?("password") && !u.key?("password_digest")
                begin
                    digest = BCrypt::Password.create(u["password"])
                    u.delete("password")
                    u["password_digest"] = digest
                    changed = true
                rescue => e
                    # si pour une raison quelconque le hachage échoue, on laisse tel quel
                    warn "migrate_passwords! warning: ", e.message
                end
            end
            u
        end

        if changed
            File.write(USER_FILE, JSON.pretty_generate(data))
        end
    end

    # (Migrations will be lancées après la définition de get_users)

    def get_users()
        return JSON.parse(File.read(USER_FILE)) 
    end

    # Migration automatique: ajouter un id (UUID) aux utilisateurs existants
    # si ils n'en ont pas encore, puis persister le fichier.
    def self.migrate_user_ids!
        data = JSON.parse(File.read(USER_FILE)) rescue []
        changed = false

        data.map! do |u|
            unless u.key?("id")
                u["id"] = SecureRandom.uuid
                changed = true
            end
            # ensure older records have a created_at timestamp
            unless u.key?("created_at")
                u["created_at"] = Time.now.utc.iso8601
                changed = true
            end
            u
        end

        if changed
            File.write(USER_FILE, JSON.pretty_generate(data))
        end
    end

    # Lancer les migrations au démarrage (passwords -> digests, puis ids)
    migrate_passwords!
    migrate_user_ids!

    helpers do
        # Retourne l'utilisateur courant (objet depuis users.json) ou nil
        def current_user
                @current_user ||= begin
                    uid = session[:user_id]
                    uid ? get_users.find { |u| u["id"] == uid } : nil
                end
        end

        def logged_in?
            !!current_user
        end
    end

    # Authenticate credentials and, on success, set session[:user_id].
    # Returns [status, message] where status is 200 on success or HTTP code on failure.
    def authenticate_and_login(user_name, pwd)
        data = get_users rescue []
        user = data.find { |u| u["name"] == user_name }
        unless user
            return [401, "Nom ou mot de passe incorrect!"]
        end

        if user.key?("password_digest")
            begin
                if BCrypt::Password.new(user["password_digest"]) == pwd
                    # demander au middleware Rack de renouveler l'ID de session (rotation)
                    env['rack.session.options'][:renew] = true rescue nil
                    session.clear rescue nil
                    session[:user_id] = user["id"]
                    return [200, ""]
                else
                    return [401, "Nom ou mot de passe incorrect!"]
                end
            rescue => e
                warn "bcrypt verify error: ", e.message
                return [500, "Erreur serveur"]
            end
        else
            # fallback legacy plain-text
            if user["password"] == pwd
                begin
                    digest = BCrypt::Password.create(pwd)
                    user.delete("password")
                    user["password_digest"] = digest
                    File.write(USER_FILE, JSON.pretty_generate(data))
                rescue => e
                    warn "bcrypt create error: ", e.message
                end
                env['rack.session.options'][:renew] = true rescue nil
                session.clear rescue nil
                session[:user_id] = user["id"]
                return [200, ""]
            else
                return [401, "Nom ou mot de passe incorrect!"]
            end
        end
    end

    get "/" do
      send_file File.expand_path("../docs/index.html", __dir__)
    end  

    get "/dashboard" do
      send_file File.expand_path("../docs/dashboard.html", __dir__)
    end  

    post "/new-user" do 
        # Attendu: body JSON { name: "...", password: "..." }
        payload = begin
            JSON.parse(request.body.read)
        rescue
            {}
        end

        user_name = payload["name"]
        pwd = payload["password"]

        erreurs = []

        if user_name.nil? || user_name.to_s.strip.empty?
            erreurs << "Fournir un nom valide!"
        end
        
        if pwd.nil? || pwd.to_s.empty? || pwd.length < 4
            erreurs << "Fournir un mot de passe contenant minimum de 4 caractères!"
        end

        unless erreurs.empty?
            status 400
            return erreurs.join("\n")
        end

        # Lire la base locale
        data = get_users rescue []

        # Vérifier l'existence (comparaison simple sur le champ name)
        if data.any? { |u| u["name"] == user_name }
            status 409
            return "Cet utilisateur existe déjà"
        end

        # Ajouter et sauvegarder (stocker password_digest via BCrypt)
            begin
                digest = BCrypt::Password.create(pwd)
                entry = { "id" => SecureRandom.uuid, "name" => user_name, "password_digest" => digest, "created_at" => Time.now.utc.iso8601 }
                data << entry
                File.write(USER_FILE, JSON.pretty_generate(data))

                env['rack.session.options'][:renew] = true rescue nil
                session.clear rescue nil
                session[:user_id] = entry["id"]

                # If client is an API (JSON), respond with JSON + created status so fetch clients
                # can consume the Set-Cookie and act accordingly. For HTML form submissions
                # we still redirect to the dashboard.
                if request.media_type == 'application/json'
                    content_type :json
                    status 201
                    return({ ok: true, redirect: '/dashboard' }.to_json)
                else
                    redirect "/dashboard", 303
                end
                
            rescue => e
                warn "bcrypt create error (new-user): ", e.message
                status 500
                return "Erreur serveur"
            end

    end

    # Route /login (alias plus explicite pour /user)
    post "/login" do
        payload = begin
            JSON.parse(request.body.read)
        rescue
            {}
        end

        user_name = payload["name"]
        pwd = payload["password"]

        erreurs = []
        if user_name.nil? || user_name.to_s.strip.empty?
            erreurs << "Fournir un nom valide!"
        end
        if pwd.nil? || pwd.to_s.empty?
            erreurs << "Fournir un mot de passe!"
        end

        unless erreurs.empty?
            status 400
            return erreurs.join("\n")
        end

        status_code, message = authenticate_and_login(user_name, pwd)

        if status_code == 200
            # If this is an API (JSON) request, respond with JSON instead of redirecting
            if request.media_type == 'application/json'
                content_type :json
                status 200
                return({ ok: true, redirect: '/dashboard' }.to_json)
            else
                redirect "/dashboard", 303
            end
        else
            status status_code
            return message
        end
    end

    # Retourne les infos de l'utilisateur courant (sans champs sensibles)
    get "/me" do
        if logged_in?
            content_type :json
            { id: current_user["id"], name: current_user["name"], created_at: current_user["created_at"] }.to_json
        else
            status 401
            ""
        end
    end

    get "/users" do
        if logged_in? && current_user["name"] == "admin"
            content_type :json
            get_users.to_json
        else
            status 403
            "Autorisation refusée: accès réservé à l'administrateur"
        end
    end
     

    post "/logout" do
        # Clear server-side session then respond appropriately depending on client
        session.clear

        # If the client is an API (JSON), return a small JSON payload so fetch clients
        # can consume the Set-Cookie and perform a client-side navigation.
        if request.media_type == 'application/json'
            content_type :json
            status 200
            return({ ok: true, redirect: '/' }.to_json)
        else
            # For normal browser form flow, perform an HTTP redirect back to index
            redirect '/', 303
        end
    end

    run! if app_file == $0
end