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

class MySinatraApp < Sinatra::Base

    configure :development do
        register Sinatra::Reloader
    end

    # Sessions (cookie) - première étape vers l'authentification par session
    configure do
        enable :sessions
        set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

        # Options du cookie de session. En production, mettez `secure: true`.
        use Rack::Session::Cookie, key: 'auth.session', path: '/',
            secret: settings.session_secret, httponly: true, secure: false, same_site: :lax
    end

    # def sha256(value)
    #     nil if value.nil? || value.empty?

    #     OpenSSL::HMAC.hexdigest("sha256", SHA_KEY, value)
    # end


    set :public_folder, File.expand_path("../docs", __dir__)

    # Utiliser un chemin absolu basé sur le répertoire où se trouve ce fichier
    USER_FILE = File.expand_path("users.json", __dir__)
    File.write(USER_FILE, "[]") unless File.exist?(USER_FILE)

    # Migration automatique: convertir les mots de passe en clair existants
    # en password_digest (BCrypt) afin de sécuriser les mots de passe.
    def migrate_passwords!
        data = get_users rescue []
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

    # Lancer la migration au démarrage
    migrate_passwords!

    def get_users()
        return JSON.parse(File.read(USER_FILE)) 
    end

    helpers do
        # Retourne l'utilisateur courant (objet depuis users.json) ou nil
        def current_user
            @current_user ||= begin
                name = session[:user_name]
                name ? get_users.find { |u| u["name"] == name } : nil
            end
        end

        def logged_in?
            !!current_user
        end
    end

    get "/" do
      send_file File.expand_path("../docs/index.html", __dir__)
    end  

    post "/user" do
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

        data = get_users rescue []

        user = data.find { |u| u["name"] == user_name }
        if user
            # vérifier le mot de passe via password_digest (BCrypt)
            if user.key?("password_digest")
                begin
                    if BCrypt::Password.new(user["password_digest"]) == pwd
                        session[:user_name] = user_name
                        status 200
                        return ""
                    else
                        status 401
                        return "Nom ou mot de passe incorrect!"
                    end
                rescue => e
                    # si le digest est corrompu, rejeter
                    warn "bcrypt verify error: ", e.message
                    status 500
                    return "Erreur serveur"
                end
            else
                # fallback: legacy plain-text password (dev only), mais on recommande migration
                if user["password"] == pwd
                    # générer digest immédiatement pour cet utilisateur
                    begin
                        digest = BCrypt::Password.create(pwd)
                        user.delete("password")
                        user["password_digest"] = digest
                        File.write(USER_FILE, JSON.pretty_generate(data))
                    rescue => e
                        warn "bcrypt create error: ", e.message
                    end
                    session[:user_name] = user_name
                    status 200
                    return ""
                else
                    status 401
                    return "Nom ou mot de passe incorrect!"
                end
            end
        else
            status 401
            return "Nom ou mot de passe incorrect!"
        end
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
            entry = { "name" => user_name, "password_digest" => digest }
            data << entry
            File.write(USER_FILE, JSON.pretty_generate(data))
            status 201
            return ""
        rescue => e
            warn "bcrypt create error (new-user): ", e.message
            status 500
            return "Erreur serveur"
        end

    end

    run! if app_file == $0
end 